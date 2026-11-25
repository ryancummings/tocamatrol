// Expected bytes come from protocol/PROTOCOL.md, not from the encoder.
import Testing
import TocaCore

@Suite struct PacketTests {
    @Test func encodesTheProtocolExamplePointerPacket() {
        // PROTOCOL.md: left held, right 3, up 2, vscroll -1, hscroll +2, seq 7.
        let packet = PointerPacket(seq: 7, buttons: .left, dx: 3, dy: -2, vscroll: -1, hscroll: 2)

        #expect(packet.encoded() == [0x01, 0x07, 0x01, 0x03, 0x00, 0xFE, 0xFF, 0xFF, 0xFF, 0x02, 0x00])
    }

    @Test func encodesExtremeValuesAndAllButtons() {
        let packet = PointerPacket(seq: 255, buttons: [.left, .right, .middle], dx: -32768, dy: 32767, vscroll: 1, hscroll: -32768)

        #expect(packet.encoded() == [0x01, 0xFF, 0x07, 0x00, 0x80, 0xFF, 0x7F, 0x01, 0x00, 0x00, 0x80])
    }
}

@Suite struct SendAccumulatorTests {
    @Test func accumulatesFractionalVerticalAndHorizontalScroll() {
        var acc = SendAccumulator()
        acc.addScroll(horizontal: 0.4, vertical: -0.6)
        #expect(acc.drain() == nil)

        acc.addScroll(horizontal: 0.7, vertical: -0.6)
        let first = acc.drain()
        #expect(first == PointerPacket(seq: 0, buttons: [], dx: 0, dy: 0, vscroll: -1, hscroll: 1))

        // Remaining fractional carry: horizontal 0.1, vertical -0.2
        acc.addScroll(horizontal: 0.9, vertical: -0.8)
        let second = acc.drain()
        #expect(second == PointerPacket(seq: 1, buttons: [], dx: 0, dy: 0, vscroll: -1, hscroll: 1))
    }

    @Test func clampsOverflowingScrollIntoNextPacket() {
        var acc = SendAccumulator()
        acc.addScroll(horizontal: 32770, vertical: -32770)

        let first = acc.drain()
        let second = acc.drain()
        #expect(first?.vscroll == Int16.min)
        #expect(first?.hscroll == Int16.max)
        #expect(second?.vscroll == -2)
        #expect(second?.hscroll == 3)
    }
}

@Suite struct KeyboardPacketTests {
    @Test func encodesTheProtocolExampleKeyboardPacket() {
        // PROTOCOL.md: Ctrl held with C (0x06), seq 4.
        let packet = KeyboardPacket(seq: 4, modifiers: .leftControl, keys: [0x06])

        #expect(packet.encoded() == [0x11, 0x04, 0x01, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00])
    }

    @Test func encodesSixKeysAndEveryModifier() {
        let packet = KeyboardPacket(
            seq: 255,
            modifiers: [.leftControl, .leftShift, .leftAlt, .leftGUI, .rightControl, .rightShift, .rightAlt, .rightGUI],
            keys: [0x68, 0x6C, 0x73, 0x04, 0x06, 0x19])

        #expect(packet.encoded() == [0x11, 0xFF, 0xFF, 0x68, 0x6C, 0x73, 0x04, 0x06, 0x19])
    }
}

@Suite struct DongleAdvertTests {
    @Test func readsTheOpenPairingWindow() {
        // PROTOCOL.md "Advertising": pairing window open is FF FF 01.
        #expect(DongleAdvert(manufacturerData: [0xFF, 0xFF, 0x01])?.pairingWindowOpen == true)
        #expect(DongleAdvert(manufacturerData: [0xFF, 0xFF, 0x00])?.pairingWindowOpen == false)
    }

    @Test func ignoresOtherManufacturersAndShortData() {
        #expect(DongleAdvert(manufacturerData: [0x4C, 0x00, 0x01]) == nil)
        #expect(DongleAdvert(manufacturerData: [0xFF, 0xFF]) == nil)
    }
}

@Suite struct DongleNameTests {
    // PROTOCOL.md "Name characteristic": trim spaces, non-ASCII becomes ?, 20 bytes at most.
    @Test func cleansANameAsTheDongleWill() {
        #expect(DongleName.bytes(for: "  Desk Mac 3  ") == Array("Desk Mac 3".utf8))
        #expect(DongleName.bytes(for: "Café") == Array("Caf?".utf8))
        #expect(DongleName.bytes(for: "ABCDEFGHIJKLMNOPQRS TUVWXYZ") == Array("ABCDEFGHIJKLMNOPQRS".utf8))
        #expect(DongleName.bytes(for: "   ").isEmpty)
    }
}
