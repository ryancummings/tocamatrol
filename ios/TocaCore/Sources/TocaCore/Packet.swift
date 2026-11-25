// Phone → dongle packets. Layout: protocol/PROTOCOL.md (single source of truth).
import Foundation

/// Protocol constants shared with the dongle firmware.
public enum TocaProtocol {
    public static let version: UInt8 = 1
    public static let pointerType: UInt8 = 0
    public static let pointerPacketSize = 11
    public static let keyboardType: UInt8 = 1
    public static let keyboardPacketSize = 9
    /// Keys a keyboard packet can hold at once.
    public static let maxKeys = 6

    public static let serviceUUID = "cc8e0001-115b-4a7a-8d7c-16299db8fcaf"
    public static let inputUUID = "cc8e0002-115b-4a7a-8d7c-16299db8fcaf"
    public static let infoUUID = "cc8e0003-115b-4a7a-8d7c-16299db8fcaf"
    public static let nameUUID = "cc8e0004-115b-4a7a-8d7c-16299db8fcaf"
    public static let deviceName = "Tocamatrol"
}

/// Mouse buttons held, as the pointer packet's `buttons` bitmask.
public struct MouseButtons: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let left = MouseButtons(rawValue: 0x01)
    public static let right = MouseButtons(rawValue: 0x02)
    public static let middle = MouseButtons(rawValue: 0x04)
}

/// One pointer packet (type 0): movement, vertical/horizontal scroll ticks, and buttons since the last one.
public struct PointerPacket: Equatable, Sendable {
    public var seq: UInt8
    public var buttons: MouseButtons
    /// Positive is right.
    public var dx: Int16
    /// Positive is down.
    public var dy: Int16
    /// Whole vertical scroll ticks. Positive scrolls up, as a mouse wheel does.
    public var vscroll: Int16
    /// Whole horizontal scroll ticks (AC Pan). Positive scrolls right.
    public var hscroll: Int16

    public init(seq: UInt8, buttons: MouseButtons, dx: Int16, dy: Int16, vscroll: Int16, hscroll: Int16 = 0) {
        self.seq = seq
        self.buttons = buttons
        self.dx = dx
        self.dy = dy
        self.vscroll = vscroll
        self.hscroll = hscroll
    }

    public func encoded() -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(TocaProtocol.pointerPacketSize)
        bytes.append(TocaProtocol.pointerType << 4 | TocaProtocol.version)
        bytes.append(seq)
        bytes.append(buttons.rawValue)
        for value in [dx, dy, vscroll, hscroll] {
            let bits = UInt16(bitPattern: value)
            bytes.append(UInt8(bits & 0xFF))
            bytes.append(UInt8(bits >> 8))
        }
        return bytes
    }
}

/// Modifiers held, as the keyboard packet's `modifiers` bitmask (USB boot keyboard bits).
public struct KeyModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let leftControl = KeyModifiers(rawValue: 0x01)
    public static let leftShift = KeyModifiers(rawValue: 0x02)
    public static let leftAlt = KeyModifiers(rawValue: 0x04)
    public static let leftGUI = KeyModifiers(rawValue: 0x08)
    public static let rightControl = KeyModifiers(rawValue: 0x10)
    public static let rightShift = KeyModifiers(rawValue: 0x20)
    public static let rightAlt = KeyModifiers(rawValue: 0x40)
    public static let rightGUI = KeyModifiers(rawValue: 0x80)
}

/// One keyboard packet (type 1): every modifier and key held now.
public struct KeyboardPacket: Equatable, Sendable {
    public var seq: UInt8
    public var modifiers: KeyModifiers
    /// USB HID Keyboard page usage IDs, at most `TocaProtocol.maxKeys`.
    public var keys: [UInt8]

    public init(seq: UInt8, modifiers: KeyModifiers, keys: [UInt8]) {
        self.seq = seq
        self.modifiers = modifiers
        self.keys = keys
    }

    public func encoded() -> [UInt8] {
        var bytes: [UInt8] = [TocaProtocol.keyboardType << 4 | TocaProtocol.version, seq, modifiers.rawValue]
        bytes += keys.prefix(TocaProtocol.maxKeys)
        bytes += Array(repeating: 0, count: TocaProtocol.keyboardPacketSize - bytes.count)
        return bytes
    }
}

/// What a dongle's advertisement says about it (PROTOCOL.md "Advertising").
public struct DongleAdvert: Equatable, Sendable {
    /// The dongle accepts a new phone now.
    public var pairingWindowOpen: Bool

    /// Reads the manufacturer data; nil when it is not a Tocamatrol dongle's (company ID 0xFFFF).
    public init?(manufacturerData: [UInt8]) {
        guard manufacturerData.count >= 3, manufacturerData[0] == 0xFF, manufacturerData[1] == 0xFF else {
            return nil
        }
        pairingWindowOpen = manufacturerData[2] & 0x01 != 0
    }
}

/// A dongle name as written to the Name characteristic (PROTOCOL.md "Name characteristic").
public enum DongleName {
    public static let maxLength = 20

    /// The bytes to write, cleaned as the dongle cleans them, so the app shows what the dongle
    /// will keep. Empty means "back to the default name".
    public static func bytes(for name: String) -> [UInt8] {
        let ascii = name.trimmingCharacters(in: .whitespaces).unicodeScalars.map { scalar -> UInt8 in
            (0x20...0x7E).contains(scalar.value) ? UInt8(scalar.value) : UInt8(ascii: "?")
        }
        var kept = Array(ascii.prefix(maxLength))
        while kept.last == UInt8(ascii: " ") { kept.removeLast() }
        return kept
    }
}
