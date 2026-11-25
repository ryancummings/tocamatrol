// A macro is what the virtual keyboard saw: key downs and ups with the pauses between
// them. Usages are from the USB HID Keyboard page.
import Testing
import TocaCore

private let ctrl = KeyChord(0, .leftControl)
private let c = KeyChord(0x06)
private let v = KeyChord(0x07)

/// "+06 after 250 ms" style, so a failure reads as a timeline.
private func timeline(_ steps: [MacroStep]) -> [String] {
    steps.map { step in
        let key = step.key.modifiers.isEmpty
            ? String(step.key.usage, radix: 16)
            : "\(step.key.modifiers.rawValue)|\(String(step.key.usage, radix: 16))"
        return "\(step.action == .press ? "+" : "-")\(key) \(step.delay)"
    }
}

@Suite struct MacroRecorderTests {
    @Test func recordsDownsAndUpsWithThePausesBetweenThem() {
        // Ctrl held, C tapped, then V tapped: copy, then paste.
        var recorder = MacroRecorder()
        recorder.press(ctrl, at: 10.0)
        recorder.press(c, at: 10.2)
        recorder.release(c, at: 10.25)
        recorder.press(v, at: 11.0)
        recorder.release(v, at: 11.05)
        recorder.release(ctrl, at: 11.3)

        #expect(timeline(recorder.finish()) == [
            "+1|0 0", "+6 200", "-6 50", "+7 750", "-7 50", "-1|0 250",
        ])
    }

    @Test func keysStillHeldWhenRecordingStopsAreReleasedAtTheEnd() {
        var recorder = MacroRecorder()
        recorder.press(ctrl, at: 0)
        recorder.press(c, at: 0.1)

        #expect(timeline(recorder.finish()) == ["+1|0 0", "+6 100", "-6 0", "-1|0 0"])
    }

    @Test func aReleaseWithoutItsPressIsNotRecorded() {
        // Held down before recording started: the macro never pressed it.
        var recorder = MacroRecorder()
        recorder.release(ctrl, at: 0)
        recorder.press(c, at: 0.3)
        recorder.release(c, at: 0.35)

        #expect(timeline(recorder.finish()) == ["+6 0", "-6 50"])
    }
}

/// Copy then paste, recorded at 1×: Ctrl down, C 200 ms later, V 750 ms after that.
private let copyPaste = [
    MacroStep(.press, ctrl), MacroStep(.press, c, after: 200), MacroStep(.release, c, after: 50),
    MacroStep(.press, v, after: 750), MacroStep(.release, v, after: 50), MacroStep(.release, ctrl, after: 250),
]

@Suite struct MacroPlayerTests {
    @Test func atNormalSpeedStepsComeDueAfterTheirRecordedPauses() {
        var player = MacroPlayer(copyPaste, speed: .normal, startingAt: 100)

        #expect(timeline(player.due(at: 100)) == ["+1|0 0"])
        #expect(timeline(player.due(at: 100.199)).isEmpty)
        #expect(timeline(player.due(at: 100.26)) == ["+6 200", "-6 50"])
        #expect(timeline(player.due(at: 101.3)) == ["+7 750", "-7 50", "-1|0 250"])
        #expect(player.isFinished)
    }

    @Test func atFourTimesSpeedEveryPauseIsAQuarter() {
        var player = MacroPlayer(copyPaste, speed: .quadruple, startingAt: 0)

        #expect(timeline(player.due(at: 0.049)) == ["+1|0 0"])
        #expect(timeline(player.due(at: 0.0625)) == ["+6 200", "-6 50"])
        #expect(timeline(player.due(at: 0.249)).isEmpty)
        #expect(timeline(player.due(at: 0.3251)) == ["+7 750", "-7 50", "-1|0 250"])
    }

    @Test func instantPlaysEveryStepAtOnceInOrder() {
        // The key sender still gives each key change its own packet, one per send tick.
        var player = MacroPlayer(copyPaste, speed: .instant, startingAt: 5)

        #expect(timeline(player.due(at: 5)) == timeline(copyPaste))
        #expect(player.isFinished)
    }

    @Test func stoppingPartWayReleasesWhatTheMacroHoldsAndPlaysNoMore() {
        var player = MacroPlayer(copyPaste, speed: .normal, startingAt: 0)
        _ = player.due(at: 0.21)  // Ctrl and C are down

        #expect(timeline(player.stop()) == ["-6 0", "-1|0 0"])
        #expect(player.isFinished)
        #expect(player.due(at: 10).isEmpty)
    }

    @Test func stoppingWhenNothingIsHeldReleasesNothing() {
        var player = MacroPlayer(copyPaste, speed: .normal, startingAt: 0)
        _ = player.due(at: 0.3)  // C is back up; Ctrl is still down

        #expect(timeline(player.stop()) == ["-1|0 0"])
        #expect(player.stop().isEmpty)
    }
}
