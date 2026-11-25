/// A key with the modifiers it is sent with, such as Ctrl+International 1. Usage 0 is a
/// modifier on its own, such as the virtual keyboard's Ctrl key.
public struct KeyChord: Hashable, Sendable {
    /// USB HID Keyboard page usage ID.
    public var usage: UInt8
    public var modifiers: KeyModifiers

    public init(_ usage: UInt8, _ modifiers: KeyModifiers = []) {
        self.usage = usage
        self.modifiers = modifiers
    }
}

/// Turns key presses, releases and taps into keyboard packets, at most one per send tick
/// (PROTOCOL.md "Keyboard packet").
///
/// Every key change gets its own packet, so a tap is always seen going down and up, and
/// taps queued in one tick all reach the PC in order.
public struct KeySender: Sendable {
    private struct KeyState: Equatable, Sendable {
        var modifiers: KeyModifiers = []
        var keys: [UInt8] = []
    }

    /// Keys held now, in press order.
    private var held: [KeyChord] = []
    /// States not yet sent, oldest first.
    private var pending: [KeyState] = []
    private var sent = KeyState()
    private var nextSeq: UInt8 = 0

    public init() {}

    /// Every key change has been handed out for sending.
    public var isIdle: Bool { pending.isEmpty }

    /// Holds `chord` until `release`. Ignored when it is already held or 6 keys are.
    public mutating func press(_ chord: KeyChord) {
        guard !held.contains(chord), held.count < TocaProtocol.maxKeys else { return }
        held.append(chord)
        enqueue(state(of: held))
    }

    public mutating func release(_ chord: KeyChord) {
        guard let index = held.firstIndex(of: chord) else { return }
        held.remove(at: index)
        enqueue(state(of: held))
    }

    /// Down then up, as two packets, with any held keys staying down.
    public mutating func tap(_ chord: KeyChord) {
        guard !held.contains(chord), held.count < TocaProtocol.maxKeys else { return }
        enqueue(state(of: held + [chord]))
        enqueue(state(of: held))
    }

    /// Lets go of every held key at once, as when the app leaves the foreground.
    public mutating func releaseAll() {
        held.removeAll()
        enqueue(KeyState())
    }

    /// Forgets everything, as after a disconnect: the dongle has released all keys.
    public mutating func reset() {
        self = KeySender()
    }

    /// The packet for this send tick, or nil when there is nothing to send.
    public mutating func drain() -> KeyboardPacket? {
        guard !pending.isEmpty else { return nil }
        sent = pending.removeFirst()
        defer { nextSeq &+= 1 }
        return KeyboardPacket(seq: nextSeq, modifiers: sent.modifiers, keys: sent.keys)
    }

    private var latest: KeyState { pending.last ?? sent }

    private mutating func enqueue(_ state: KeyState) {
        if state != latest { pending.append(state) }
    }

    private func state(of chords: [KeyChord]) -> KeyState {
        KeyState(
            modifiers: chords.reduce(into: KeyModifiers()) { $0.formUnion($1.modifiers) },
            keys: chords.map(\.usage).filter { $0 != 0 })
    }
}
