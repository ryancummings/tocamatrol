import SwiftUI
import TocaCore

/// One key of the virtual keyboard: what it shows, the code it sends and its width in key units.
struct VirtualKey: Identifiable {
    let id: String
    let label: String
    /// The character with Shift, shown small above the label: "!" on the 1 key.
    let shifted: String?
    let chord: KeyChord
    let width: CGFloat

    /// Ctrl, Shift, Alt and Win: held by a finger, or latched by a tap until the next key.
    var isModifier: Bool { chord.usage == 0 }

    init(_ label: String, _ usage: UInt8, shifted: String? = nil, width: CGFloat = 1, id: String? = nil) {
        self.id = id ?? label
        self.label = label
        self.shifted = shifted
        chord = KeyChord(usage)
        self.width = width
    }

    init(modifier label: String, _ modifier: KeyModifiers, width: CGFloat, id: String) {
        self.id = id
        self.label = label
        shifted = nil
        chord = KeyChord(0, modifier)
        self.width = width
    }
}

/// A US PC keyboard, 15 key units wide. A nil entry is a gap of that width.
enum VirtualKeyboardLayout {
    typealias Row = [(key: VirtualKey?, width: CGFloat)]

    private static func keys(_ keys: VirtualKey...) -> Row { keys.map { ($0, $0.width) } }
    private static func gap(_ width: CGFloat) -> Row { [(nil, width)] }
    private static func letters(_ string: String) -> Row {
        string.map { c in
            let usage = UInt8(0x04) + UInt8(c.asciiValue! - Character("A").asciiValue!)
            return (VirtualKey(String(c), usage), 1)
        }
    }
    private static func functionKeys(_ range: ClosedRange<Int>) -> Row {
        range.map { (VirtualKey("F\($0)", UInt8(0x3A + $0 - 1)), 1) }
    }

    static let rows: [Row] = [
        keys(VirtualKey("Ins", 0x49, width: 2.5), VirtualKey("Home", 0x4A, width: 2.5), VirtualKey("PgUp", 0x4B, width: 2.5),
             VirtualKey("Del", 0x4C, width: 2.5), VirtualKey("End", 0x4D, width: 2.5), VirtualKey("PgDn", 0x4E, width: 2.5)),
        keys(VirtualKey("Esc", 0x29, width: 1.5)) + gap(0.5) + functionKeys(1...4) + gap(0.5) + functionKeys(5...8)
            + gap(0.5) + functionKeys(9...12),
        keys(VirtualKey("`", 0x35, shifted: "~"), VirtualKey("1", 0x1E, shifted: "!"), VirtualKey("2", 0x1F, shifted: "@"),
             VirtualKey("3", 0x20, shifted: "#"), VirtualKey("4", 0x21, shifted: "$"), VirtualKey("5", 0x22, shifted: "%"),
             VirtualKey("6", 0x23, shifted: "^"), VirtualKey("7", 0x24, shifted: "&"), VirtualKey("8", 0x25, shifted: "*"),
             VirtualKey("9", 0x26, shifted: "("), VirtualKey("0", 0x27, shifted: ")"), VirtualKey("-", 0x2D, shifted: "_"),
             VirtualKey("=", 0x2E, shifted: "+"), VirtualKey("⌫", 0x2A, width: 2, id: "Backspace")),
        keys(VirtualKey("Tab", 0x2B, width: 1.5)) + letters("QWERTYUIOP")
            + keys(VirtualKey("[", 0x2F, shifted: "{"), VirtualKey("]", 0x30, shifted: "}"),
                   VirtualKey("\\", 0x31, shifted: "|", width: 1.5)),
        // No Caps Lock: a latched state on the PC that a macro could leave behind.
        gap(1.75) + letters("ASDFGHJKL")
            + keys(VirtualKey(";", 0x33, shifted: ":"), VirtualKey("'", 0x34, shifted: "\""),
                   VirtualKey("Enter", 0x28, width: 2.25)),
        keys(VirtualKey(modifier: "Shift", .leftShift, width: 2.25, id: "LShift")) + letters("ZXCVBNM")
            + keys(VirtualKey(",", 0x36, shifted: "<"), VirtualKey(".", 0x37, shifted: ">"), VirtualKey("/", 0x38, shifted: "?"),
                   VirtualKey(modifier: "Shift", .rightShift, width: 2.75, id: "RShift")),
        keys(VirtualKey(modifier: "Ctrl", .leftControl, width: 1.5, id: "LCtrl"),
             VirtualKey(modifier: "Win", .leftGUI, width: 1.25, id: "LWin"),
             VirtualKey(modifier: "Alt", .leftAlt, width: 1.25, id: "LAlt"),
             VirtualKey("Space", 0x2C, width: 5.5),
             VirtualKey(modifier: "Alt", .rightAlt, width: 1.25, id: "RAlt"),
             VirtualKey(modifier: "Ctrl", .rightControl, width: 1.25, id: "RCtrl"),
             VirtualKey("←", 0x50, id: "Left"), VirtualKey("↑", 0x52, id: "Up"),
             VirtualKey("↓", 0x51, id: "Down"), VirtualKey("→", 0x4F, id: "Right")),
    ]

    static let byUsage: [UInt8: VirtualKey] = Dictionary(
        rows.flatMap { $0.compactMap(\.key) }.filter { !$0.isModifier }.map { ($0.chord.usage, $0) },
        uniquingKeysWith: { a, _ in a })
}

/// The virtual keyboard. Keys go down as the finger lands and up as it lifts, so several can be
/// held at once. A modifier tapped on its own latches, as Shift does on the iOS keyboard: it stays
/// down until the next key comes up, or until it is tapped again.
struct VirtualKeyboardView: View {
    let onPress: (KeyChord) -> Void
    let onRelease: (KeyChord) -> Void

    /// Keys a finger is on.
    @State private var touched: Set<String> = []
    /// Modifiers held after their finger lifted.
    @State private var latched: Set<String> = []
    /// Modifiers held by a finger that another key was pressed with: they do not latch.
    @State private var used: Set<String> = []

    private static let spacing: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            let rowHeight = (geometry.size.height - Self.spacing * CGFloat(VirtualKeyboardLayout.rows.count - 1))
                / CGFloat(VirtualKeyboardLayout.rows.count)
            VStack(spacing: Self.spacing) {
                ForEach(VirtualKeyboardLayout.rows.indices, id: \.self) { r in
                    row(VirtualKeyboardLayout.rows[r], width: geometry.size.width)
                        .frame(height: rowHeight)
                }
            }
        }
        .onDisappear {
            for id in latched { if let key = key(id) { onRelease(key.chord) } }
            latched.removeAll()
        }
    }

    private func row(_ row: VirtualKeyboardLayout.Row, width: CGFloat) -> some View {
        let units = row.reduce(0) { $0 + $1.width }
        let unit = (width - Self.spacing * CGFloat(row.count - 1)) / units
        return HStack(spacing: Self.spacing) {
            ForEach(row.indices, id: \.self) { i in
                let slotWidth = unit * row[i].width
                if let key = row[i].key {
                    VirtualKeyCap(key: key, down: touched.contains(key.id) || latched.contains(key.id),
                                  latched: latched.contains(key.id))
                        .frame(width: slotWidth)
                        .overlay { KeyTouchArea(onDown: { down(key) }, onUp: { up(key) }) }
                } else {
                    Color.clear.frame(width: slotWidth)
                }
            }
        }
    }

    private func key(_ id: String) -> VirtualKey? {
        VirtualKeyboardLayout.rows.lazy.flatMap { $0 }.compactMap(\.key).first { $0.id == id }
    }

    private func down(_ key: VirtualKey) {
        touched.insert(key.id)
        if key.isModifier {
            // Tapping a latched modifier again lets it go, on the lift.
            guard !latched.contains(key.id) else { return }
            used.remove(key.id)
        } else {
            used.formUnion(touched.filter { $0 != key.id })
        }
        onPress(key.chord)
    }

    private func up(_ key: VirtualKey) {
        touched.remove(key.id)
        if key.isModifier {
            if latched.remove(key.id) != nil || used.contains(key.id) {
                onRelease(key.chord)
            } else {
                latched.insert(key.id)
            }
        } else {
            onRelease(key.chord)
            // A latched modifier lasts for one key.
            for id in latched.sorted() { if let modifier = self.key(id) { onRelease(modifier.chord) } }
            latched.removeAll()
        }
    }
}

private struct VirtualKeyCap: View {
    let key: VirtualKey
    let down: Bool
    let latched: Bool

    var body: some View {
        Keycap(style: key.isModifier || key.label.count > 1 ? .graphite : Self.letter, pressed: down, ringed: latched, labelPadding: 1) {
            VStack(spacing: 0) {
                if let shifted = key.shifted { Text(shifted).font(.caption2).opacity(0.6) }
                Text(key.label).font(key.label.count > 1 ? .caption.weight(.medium) : .body.weight(.medium))
            }
            .minimumScaleFactor(0.5)
            .lineLimit(1)
        }
            .accessibilityElement()
            .accessibilityLabel(key.id)
            .accessibilityAddTraits(.isButton)
    }

    /// Letters and digits, a step lighter than the named keys.
    private static let letter = KeyStyle(skirt: Color(hex: 0x100E0A), top: Color(hex: 0x3A352C), bottom: Color(hex: 0x302B23),
                                         pressedTop: Color(hex: 0x5A5244), label: Theme.text)
}

/// A macro's steps in words: “Ctrl+C”, typed text in quotes, and pauses of a third of a second or more.
enum MacroDescription {
    private static let modifierNames: [(KeyModifiers, String)] = [
        (.leftControl, "Ctrl"), (.rightControl, "Ctrl"), (.leftAlt, "Alt"), (.rightAlt, "Alt"),
        (.leftShift, "Shift"), (.rightShift, "Shift"), (.leftGUI, "Win"), (.rightGUI, "Win"),
    ]

    static func text(_ steps: [MacroStep]) -> String {
        var parts: [String] = []
        var typed = ""
        var held = KeyModifiers()
        func endTyping() {
            if !typed.isEmpty { parts.append("“\(typed)”") }
            typed = ""
        }
        for (index, step) in steps.enumerated() {
            if index > 0, step.delay >= 300 {
                endTyping()
                parts.append(String(format: "%.1f s pause", Double(step.delay) / 1000))
            }
            guard step.action == .press else {
                if step.key.usage == 0 { held.subtract(step.key.modifiers) }
                continue
            }
            if step.key.usage == 0 {
                held.formUnion(step.key.modifiers)
                continue
            }
            let modifiers = held.union(step.key.modifiers)
            let shift = !modifiers.isDisjoint(with: [.leftShift, .rightShift])
            if let character = character(step.key.usage, shift: shift),
               modifiers.subtracting([.leftShift, .rightShift]).isEmpty {
                typed += character
            } else {
                endTyping()
                parts.append(chordName(step.key.usage, modifiers))
            }
        }
        endTyping()
        return parts.isEmpty ? "No keys" : parts.joined(separator: "  ")
    }

    /// The character a key types, or nil for keys such as Enter and F5.
    private static func character(_ usage: UInt8, shift: Bool) -> String? {
        if usage == 0x2C { return " " }
        guard let key = VirtualKeyboardLayout.byUsage[usage], key.label.count == 1, key.label != "⌫",
              !"←↑↓→".contains(key.label) else { return nil }
        if let shifted = key.shifted { return shift ? shifted : key.label }
        return shift ? key.label : key.label.lowercased()
    }

    static func chordName(_ usage: UInt8, _ modifiers: KeyModifiers) -> String {
        (modifierList(modifiers) + (usage == 0 ? [] : [keyName(usage)])).joined(separator: "+")
    }

    static func chordName(_ chord: KeyChord) -> String { chordName(chord.usage, chord.modifiers) }

    /// "Ctrl", "Shift": each modifier once, left and right alike.
    static func modifierList(_ modifiers: KeyModifiers) -> [String] {
        var names: [String] = []
        for (modifier, name) in modifierNames where modifiers.contains(modifier) && !names.contains(name) {
            names.append(name)
        }
        return names
    }

    /// A key's name as a shortcut shows it: "S", "F5", "Enter", "Backspace", "←".
    static func keyName(_ usage: UInt8) -> String {
        VirtualKeyboardLayout.byUsage[usage].map { $0.id == "Backspace" ? "Backspace" : $0.label }
            ?? String(format: "key %02X", usage)
    }

    /// A macro's steps in words: text in quotes (⏎ for Enter), shortcuts, and pauses.
    static func text(_ actions: [MacroAction]) -> String {
        let parts = actions.map(text)
        return parts.isEmpty ? "No steps" : parts.joined(separator: "  ")
    }

    static func text(_ action: MacroAction) -> String {
        switch action {
        case let .text(text):
            "“\(text.replacingOccurrences(of: "\n", with: "⏎").replacingOccurrences(of: "\t", with: "⇥"))”"
        case let .shortcut(chord): chordName(chord)
        case let .pause(ms): pause(ms)
        case let .recorded(steps): text(steps)
        }
    }

    /// "0.5 s pause"; under a second, in hundredths.
    static func pause(_ ms: Int) -> String {
        ms % 100 == 0 || ms >= 1000 ? String(format: "%.1f s pause", Double(ms) / 1000)
            : String(format: "%.2f s pause", Double(ms) / 1000)
    }

    /// How long the macro takes at its speed, in seconds.
    static func duration(_ macro: Macro) -> Double {
        guard macro.speed != .instant else { return 0 }
        return Double(macro.steps.reduce(0) { $0 + $1.delay }) / 1000 / macro.speed.factor
    }
}

extension MacroSpeed {
    var label: String {
        switch self {
        case .normal: "1×"
        case .double: "2×"
        case .quadruple: "4×"
        case .instant: "Instant"
        }
    }
}
