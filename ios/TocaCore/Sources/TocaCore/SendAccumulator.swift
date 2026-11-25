/// Collects pointer movement, scroll and button changes between send ticks and hands out at
/// most one packet per tick (PROTOCOL.md "Rules for the phone").
///
/// Nothing is dropped: fractions of a pointer count or scroll tick stay until they add up,
/// values beyond `Int16` carry to the next packet, and every button change gets its own
/// packet so a quick click is never merged away.
public struct SendAccumulator: Sendable {
    private var dx: Double = 0
    private var dy: Double = 0
    private var vscroll: Double = 0
    private var hscroll: Double = 0
    /// Button states not yet sent, oldest first.
    private var pendingButtons: [MouseButtons] = []
    private var sentButtons: MouseButtons = []
    private var nextSeq: UInt8 = 0

    public init() {}

    /// The button state after every queued change.
    public var buttons: MouseButtons { pendingButtons.last ?? sentButtons }

    public mutating func addPointer(dx: Double, dy: Double) {
        self.dx += dx
        self.dy += dy
    }

    /// Adds scroll in ticks (fractional). Positive vertical scrolls up; positive horizontal scrolls right.
    public mutating func addScroll(horizontal: Double = 0, vertical: Double = 0) {
        self.hscroll += horizontal
        self.vscroll += vertical
    }

    public mutating func press(_ button: MouseButtons) {
        setButtons(buttons.union(button))
    }

    public mutating func release(_ button: MouseButtons) {
        setButtons(buttons.subtracting(button))
    }

    /// Press then release, as two packets.
    public mutating func click(_ button: MouseButtons) {
        press(button)
        release(button)
    }

    /// Forgets everything, as after a disconnect: the dongle has released all buttons.
    public mutating func reset() {
        self = SendAccumulator()
    }

    /// The packet for this send tick, or nil when there is nothing to send.
    public mutating func drain() -> PointerPacket? {
        let buttonsNow = pendingButtons.isEmpty ? sentButtons : pendingButtons.removeFirst()
        let x = Self.takeWhole(&dx)
        let y = Self.takeWhole(&dy)
        let v = Self.takeWhole(&vscroll)
        let h = Self.takeWhole(&hscroll)
        guard buttonsNow != sentButtons || x != 0 || y != 0 || v != 0 || h != 0 else { return nil }
        sentButtons = buttonsNow
        defer { nextSeq &+= 1 }
        return PointerPacket(seq: nextSeq, buttons: buttonsNow, dx: x, dy: y, vscroll: v, hscroll: h)
    }

    private mutating func setButtons(_ new: MouseButtons) {
        if new != buttons { pendingButtons.append(new) }
    }

    /// Takes the whole part of `value` that fits in an Int16 and leaves the rest.
    private static func takeWhole(_ value: inout Double) -> Int16 {
        let whole = value.rounded(.towardZero)
        let clamped = min(max(whole, Double(Int16.min)), Double(Int16.max))
        value -= clamped
        return Int16(clamped)
    }
}
