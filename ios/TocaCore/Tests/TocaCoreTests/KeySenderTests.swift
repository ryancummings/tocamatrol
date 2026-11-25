// Expected packets follow PROTOCOL.md "Keyboard packet": keys are state, and every key
// change gets its own packet. Usages are from the USB HID Keyboard page.
import Testing
import TocaCore

private let f17 = KeyChord(0x6C)
private let f18 = KeyChord(0x6D)
private let keyC = KeyChord(0x06)
private let ctrlC = KeyChord(0x06, .leftControl)
private let altF4 = KeyChord(0x3D, .leftAlt)

/// Every packet the sender hands out, one per send tick, until it has nothing left.
private func drainAll(_ sender: inout KeySender) -> [KeyboardPacket] {
    var packets: [KeyboardPacket] = []
    while let packet = sender.drain() { packets.append(packet) }
    return packets
}

private func state(_ packets: [KeyboardPacket]) -> [String] {
    packets.map { packet in
        let keys = packet.keys.map { String($0, radix: 16) }.joined(separator: " ")
        return packet.modifiers.isEmpty ? keys : "\(packet.modifiers.rawValue)|\(keys)"
    }
}

@Suite struct KeySenderTests {
    @Test func aTapIsTwoPacketsDownThenUp() {
        var sender = KeySender()
        sender.tap(keyC)

        #expect(state(drainAll(&sender)) == ["6", ""])
    }

    @Test func aHeldKeyStaysDownUntilReleased() {
        var sender = KeySender()
        sender.press(f17)
        #expect(state(drainAll(&sender)) == ["6c"])

        sender.release(f17)
        #expect(state(drainAll(&sender)) == [""])
    }

    @Test func aTapWithModifiersDuringAHoldKeepsTheHold() {
        var sender = KeySender()
        sender.press(f17)
        sender.tap(ctrlC)
        sender.release(f17)

        #expect(state(drainAll(&sender)) == ["6c", "1|6c 6", "6c", ""])
    }

    @Test func twoTapsInOneTickBothReachThePC() {
        var sender = KeySender()
        sender.tap(ctrlC)
        sender.tap(altF4)

        #expect(state(drainAll(&sender)) == ["1|6", "", "4|3d", ""])
    }

    @Test func twoHeldKeysAreHeldTogether() {
        var sender = KeySender()
        sender.press(f17)
        sender.press(f18)
        sender.release(f17)

        #expect(state(drainAll(&sender)) == ["6c", "6c 6d", "6d"])
    }

    @Test func aModifierHeldOnItsOwnSendsOnlyItsBit() {
        // The virtual keyboard's Ctrl key held while C is tapped: Ctrl+C.
        var sender = KeySender()
        sender.press(KeyChord(0, .leftControl))
        sender.tap(keyC)
        sender.release(KeyChord(0, .leftControl))

        #expect(state(drainAll(&sender)) == ["1|", "1|6", "1|", ""])
    }

    @Test func itIsIdleOnlyOnceEveryKeyChangeHasBeenSent() {
        var sender = KeySender()
        #expect(sender.isIdle)
        sender.tap(keyC)
        #expect(!sender.isIdle)
        _ = sender.drain()
        #expect(!sender.isIdle)
        _ = sender.drain()
        #expect(sender.isIdle)
    }

    @Test func aSeventhKeyIsNotSentAndItsReleaseChangesNothing() {
        var sender = KeySender()
        for usage in UInt8(0x68)...0x6D { sender.press(KeyChord(usage)) }
        _ = drainAll(&sender)

        sender.press(KeyChord(0x6E))
        sender.release(KeyChord(0x6E))
        #expect(drainAll(&sender).isEmpty)
    }

    @Test func seqCountsEveryKeyboardPacket() {
        var sender = KeySender()
        sender.tap(keyC)
        sender.tap(keyC)

        #expect(drainAll(&sender).map(\.seq) == [0, 1, 2, 3])
    }

    @Test func releaseAllLetsGoOfEveryHeldKeyInOnePacket() {
        var sender = KeySender()
        sender.press(f17)
        sender.press(f18)
        _ = drainAll(&sender)

        sender.releaseAll()
        #expect(state(drainAll(&sender)) == [""])

        sender.press(f17)
        #expect(state(drainAll(&sender)) == ["6c"])
    }

    @Test func afterAResetNothingIsHeldOrWaiting() {
        var sender = KeySender()
        sender.press(f17)
        sender.tap(keyC)
        sender.reset()
        #expect(drainAll(&sender).isEmpty)

        sender.press(f18)
        let packets = drainAll(&sender)
        #expect(state(packets) == ["6d"])
        #expect(packets.map(\.seq) == [0])
    }
}
