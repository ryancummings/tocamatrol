import Foundation

/// One step of a macro in the editor: playback turns the steps into key changes
/// (`MacroAction.steps(for:)`), so each step can be edited on its own instead of re-recording
/// the whole macro.
public enum MacroAction: Hashable, Sendable {
    /// Text typed on a US keyboard. A newline types Enter and a tab types Tab; characters a
    /// US keyboard cannot type are left out (`USKeyboard.untypable`).
    case text(String)
    /// One key, with any modifiers, tapped: Ctrl+S, F5, Enter.
    case shortcut(KeyChord)
    /// A wait, in milliseconds, before the next step.
    case pause(Int)
    /// Key changes as the virtual keyboard recorded them, kept when they cannot be put as
    /// text, shortcuts and pauses (such as two keys held together).
    case recorded([MacroStep])

    /// Key changes for `actions`. Typed keys and shortcuts go down and up with no wait: each
    /// change still takes its own send tick. Pauses become the next change's delay.
    public static func steps(for actions: [MacroAction]) -> [MacroStep] {
        var steps: [MacroStep] = []
        var wait = 0
        func tap(_ chord: KeyChord) {
            steps.append(MacroStep(.press, chord, after: steps.isEmpty ? 0 : wait))
            steps.append(MacroStep(.release, chord))
            wait = 0
        }
        for action in actions {
            switch action {
            case let .text(text):
                for character in text {
                    if let chord = USKeyboard.chord(for: character) { tap(chord) }
                }
            case let .shortcut(chord):
                tap(chord)
            case let .pause(ms):
                wait += max(0, ms)
            case let .recorded(recorded):
                for (index, step) in recorded.enumerated() {
                    var step = step
                    if index == 0 { step.delay = steps.isEmpty ? 0 : wait + step.delay }
                    steps.append(step)
                }
                wait = 0
            }
        }
        return steps
    }

    /// Recorded key changes as steps: taps that type characters become text, other taps
    /// shortcuts, and waits of 0.3 s or more pauses (1 s or more in the middle of text, where a
    /// shorter wait is just typing speed). Anything else, such as a key held while another is
    /// pressed, is kept as it was, as one recorded step.
    public static func actions(from steps: [MacroStep]) -> [MacroAction] {
        guard !steps.isEmpty else { return [] }
        var actions: [MacroAction] = []
        var modifiers = KeyModifiers()
        /// Modifiers held, each with whether a key has been tapped with it.
        var modifierUsed: [KeyModifiers: Bool] = [:]
        var down: KeyChord?
        var pendingPause = 0
        var lastWasText = false

        func add(_ chord: KeyChord) {
            let character = USKeyboard.character(for: chord)
            if character != nil, pendingPause > 0, lastWasText, pendingPause < 1000 { pendingPause = 0 }
            if pendingPause > 0 {
                actions.append(.pause(pendingPause))
                pendingPause = 0
            }
            if let character {
                if case let .text(text)? = actions.last, lastWasText {
                    actions[actions.count - 1] = .text(text + String(character))
                } else {
                    actions.append(.text(String(character)))
                }
                lastWasText = true
            } else {
                actions.append(.shortcut(chord))
                lastWasText = false
            }
        }

        for (index, step) in steps.enumerated() {
            if index > 0, step.delay >= 300 {
                // A long wait with a key down would let the PC repeat it.
                guard down == nil else { return [.recorded(steps)] }
                pendingPause += step.delay
            }
            let chord = step.key
            switch (step.action, chord.usage) {
            case (.press, 0):
                modifiers.formUnion(chord.modifiers)
                modifierUsed[chord.modifiers] = false
            case (.release, 0):
                // A modifier tapped alone, or let go with a key still down.
                guard modifierUsed[chord.modifiers] == true, down == nil else { return [.recorded(steps)] }
                modifiers.subtract(chord.modifiers)
                modifierUsed[chord.modifiers] = nil
            case (.press, _):
                guard down == nil else { return [.recorded(steps)] }
                down = KeyChord(chord.usage, modifiers.union(chord.modifiers))
                for key in modifierUsed.keys { modifierUsed[key] = true }
            case (.release, _):
                guard let pressed = down, pressed.usage == chord.usage else { return [.recorded(steps)] }
                add(pressed)
                down = nil
            }
        }
        guard down == nil, modifierUsed.isEmpty else { return [.recorded(steps)] }
        return actions
    }
}

/// What a US PC keyboard types: the key and Shift for each character it can type.
public enum USKeyboard {
    private static let unshifted: [Character: UInt8] = {
        var map: [Character: UInt8] = [" ": 0x2C, "\n": 0x28, "\t": 0x2B, "0": 0x27,
                                       "-": 0x2D, "=": 0x2E, "[": 0x2F, "]": 0x30, "\\": 0x31,
                                       ";": 0x33, "'": 0x34, "`": 0x35, ",": 0x36, ".": 0x37, "/": 0x38]
        for (i, c) in "abcdefghijklmnopqrstuvwxyz".enumerated() { map[c] = 0x04 + UInt8(i) }
        for (i, c) in "123456789".enumerated() { map[c] = 0x1E + UInt8(i) }
        return map
    }()

    private static let shifted: [Character: UInt8] = {
        var map: [Character: UInt8] = ["!": 0x1E, "@": 0x1F, "#": 0x20, "$": 0x21, "%": 0x22, "^": 0x23,
                                       "&": 0x24, "*": 0x25, "(": 0x26, ")": 0x27, "_": 0x2D, "+": 0x2E,
                                       "{": 0x2F, "}": 0x30, "|": 0x31, ":": 0x33, "\"": 0x34, "~": 0x35,
                                       "<": 0x36, ">": 0x37, "?": 0x38]
        for (i, c) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated() { map[c] = 0x04 + UInt8(i) }
        return map
    }()

    private static let byKey: [UInt8: (plain: Character, shift: Character?)] = {
        var map: [UInt8: (Character, Character?)] = [:]
        for (c, usage) in unshifted where c != "\n" && c != "\t" { map[usage] = (c, nil) }
        for (c, usage) in shifted { map[usage] = (map[usage]?.0 ?? c, c) }
        return map
    }()

    /// The key that types `character`, with Shift if it needs it; nil for one a US keyboard
    /// cannot type. Curly quotes and dashes type their plain forms.
    public static func chord(for character: Character) -> KeyChord? {
        let character = plain(character)
        if let usage = unshifted[character] { return KeyChord(usage) }
        if let usage = shifted[character] { return KeyChord(usage, .leftShift) }
        return nil
    }

    /// The character a tap of `chord` types, or nil when it types none (Enter, F5) or has
    /// modifiers other than Shift.
    public static func character(for chord: KeyChord) -> Character? {
        let shift: KeyModifiers = [.leftShift, .rightShift]
        guard chord.modifiers.subtracting(shift).isEmpty, let key = byKey[chord.usage] else { return nil }
        return chord.modifiers.isDisjoint(with: shift) ? key.plain : key.shift
    }

    /// The characters of `text` that will not be typed, each once.
    public static func untypable(in text: String) -> [Character] {
        var seen: [Character] = []
        for c in text where chord(for: c) == nil && !seen.contains(c) { seen.append(c) }
        return seen
    }

    /// iOS turns quotes curly and "--" into a dash as you type; the PC gets the plain ones.
    private static func plain(_ c: Character) -> Character {
        switch c {
        case "\u{2018}", "\u{2019}": "'"
        case "\u{201C}", "\u{201D}": "\""
        case "\u{2013}", "\u{2014}": "-"
        case "\r\n", "\r": "\n"
        default: c
        }
    }
}

/// How a page button looks on the pad: set in the page editor.
public struct ButtonAppearance: Hashable, Codable, Sendable {
    public enum Tint: String, CaseIterable, Codable, Sendable {
        case sand, amber, rust, rose, violet, blue, teal, green, graphite
    }

    public enum Typeface: String, CaseIterable, Codable, Sendable {
        case standard, rounded, serif, mono
    }

    public enum TextSize: String, CaseIterable, Codable, Sendable {
        case small, medium, large
    }

    public var tint: Tint
    public var typeface: Typeface
    public var textSize: TextSize
    /// A second line under the name, such as "Ctrl+S"; empty for none.
    public var caption: String

    public init(tint: Tint = .sand, typeface: Typeface = .standard, textSize: TextSize = .medium, caption: String = "") {
        self.tint = tint
        self.typeface = typeface
        self.textSize = textSize
        self.caption = caption
    }

    private enum CodingKeys: String, CodingKey { case tint, typeface, textSize, caption }

    /// Missing fields take their defaults, and so do values a newer version added.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            tint: (try? container.decodeIfPresent(Tint.self, forKey: .tint)) ?? .sand,
            typeface: (try? container.decodeIfPresent(Typeface.self, forKey: .typeface)) ?? .standard,
            textSize: (try? container.decodeIfPresent(TextSize.self, forKey: .textSize)) ?? .medium,
            caption: (try? container.decodeIfPresent(String.self, forKey: .caption)) ?? "")
    }
}

/// Saved as {"type": "text", "text"}, {"type": "shortcut", "usage", "modifiers"},
/// {"type": "pause", "ms"} or {"type": "recorded", "steps"}.
extension MacroAction: Codable {
    private enum CodingKeys: String, CodingKey { case type, text, usage, modifiers, ms, steps }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "shortcut":
            self = .shortcut(KeyChord(try container.decode(UInt8.self, forKey: .usage),
                                      KeyModifiers(rawValue: try container.decode(UInt8.self, forKey: .modifiers))))
        case "pause":
            self = .pause(try container.decode(Int.self, forKey: .ms))
        case "recorded":
            self = .recorded(try container.decode([MacroStep].self, forKey: .steps))
        case let type:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "unknown step \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case let .shortcut(chord):
            try container.encode("shortcut", forKey: .type)
            try container.encode(chord.usage, forKey: .usage)
            try container.encode(chord.modifiers.rawValue, forKey: .modifiers)
        case let .pause(ms):
            try container.encode("pause", forKey: .type)
            try container.encode(ms, forKey: .ms)
        case let .recorded(steps):
            try container.encode("recorded", forKey: .type)
            try container.encode(steps, forKey: .steps)
        }
    }
}
