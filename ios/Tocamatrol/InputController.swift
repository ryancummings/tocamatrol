import QuartzCore
import TocaCore
import UIKit

/// Joins the macro pad keys, the trackpad, and the BLE link. Everything runs on the main thread:
/// touches, the 15 ms send tick, and Core Bluetooth callbacks.
final class InputController: ObservableObject {
    /// Shown by the debug overlay; refreshed four times a second.
    struct Stats: Equatable {
        var packetsPerSecond = 0
    }

    @Published private(set) var stats = Stats()
    /// The macro playing now, if any.
    @Published private(set) var playingMacro: UUID?

    let link = DongleLink()

    private var accumulator = SendAccumulator()
    private var keys = KeySender()
    private var player: MacroPlayer?
    private var gestures = TrackpadGestures(pointsPerMillimetre: ScreenMetrics.pointsPerMillimetre,
                                            pointer: InputSettings().pointerCurve,
                                            scroll: InputSettings().scrollCurve)
    private let haptics = UIImpactFeedbackGenerator(style: .light)

    private var sendTimer: Timer?
    private var packetsThisWindow = 0
    private var statsWindowStart = CACurrentMediaTime()

    /// One packet per send tick at most: the 15 ms connection interval.
    static let sendTick: TimeInterval = 0.015

    init() {
        link.onDisconnect = { [weak self] in
            // The dongle released every button and key; start again from "none held".
            self?.accumulator.reset()
            self?.keys.reset()
            self?.player = nil
            self?.playingMacro = nil
        }
    }

    func apply(_ settings: InputSettings) {
        gestures.pointer = settings.pointerCurve
        gestures.scroll = settings.scrollCurve
        gestures.coasts = settings.scrollCoast
        gestures.naturalScroll = settings.naturalScroll
    }

    /// Starts the send tick. Call when the app becomes active.
    func start() {
        haptics.prepare()
        guard sendTimer == nil else { return }
        let timer = Timer(timeInterval: Self.sendTick, repeats: true) { [weak self] _ in self?.sendTick() }
        // .common so it keeps firing while touches are being tracked.
        RunLoop.main.add(timer, forMode: .common)
        sendTimer = timer
    }

    /// Stops the send tick, releasing anything held. Call when the app leaves the foreground.
    func stop() {
        handle(gestures.cancelAll())
        stopMacro()
        keys.releaseAll()
        sendTimer?.invalidate()
        sendTimer = nil
        // Leaving the foreground: send everything queued (a drag's or key's release above all), not one
        // tick's worth.
        while link.canSend, let packet = keys.drain() {
            link.send(packet.encoded())
        }
        while link.canSend, let packet = accumulator.drain() {
            link.send(packet.encoded())
        }
    }

    // MARK: - Virtual keyboard

    /// Holds a key until `releaseKey`.
    func pressKey(_ chord: KeyChord) {
        keys.press(chord)
        haptics.impactOccurred()
    }

    func releaseKey(_ chord: KeyChord) {
        keys.release(chord)
    }

    // MARK: - Macros

    /// Plays a macro from its first step, stopping any macro already playing. Without a ready
    /// dongle it does nothing: queued keys would type later, wherever the PC's focus is then.
    func play(_ macro: Macro) {
        guard link.state == .ready else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        stopMacro()
        let now = CACurrentMediaTime()
        player = MacroPlayer(macro.steps, speed: macro.speed, startingAt: now)
        playingMacro = macro.id
        haptics.impactOccurred()
        advanceMacro(at: now)
    }

    /// Stops the playing macro and lets go of every key it holds.
    func stopMacro() {
        guard var player else { return }
        apply(player.stop())
        self.player = nil
        playingMacro = nil
    }

    private func advanceMacro(at time: TimeInterval) {
        guard var player else { return }
        apply(player.due(at: time))
        // Still playing until its last key change has gone out, so a second tap stops it
        // rather than playing it again.
        if player.isFinished && keys.isIdle {
            self.player = nil
            playingMacro = nil
        } else {
            self.player = player
        }
    }

    private func apply(_ steps: [MacroStep]) {
        for step in steps {
            switch step.action {
            case .press: keys.press(step.key)
            case .release: keys.release(step.key)
            }
        }
    }

    // MARK: - Trackpad

    func touchesBegan(_ touches: [TouchSample], at time: TimeInterval) {
        handle(gestures.began(touches, at: time))
    }

    func touchesMoved(_ touches: [TouchSample], at time: TimeInterval) {
        handle(gestures.moved(touches, at: time))
    }

    func touchesEnded(_ ids: [Int], at time: TimeInterval) {
        handle(gestures.ended(ids, at: time))
    }

    private func handle(_ actions: [TrackpadAction]) {
        for action in actions {
            switch action {
            case let .move(dx, dy):
                accumulator.addPointer(dx: dx, dy: dy)
            case let .scroll(dx, dy):
                accumulator.addScroll(horizontal: dx, vertical: dy)
            case let .click(button):
                accumulator.click(button)
                haptics.impactOccurred()
            case let .press(button):
                accumulator.press(button)
                haptics.impactOccurred()
            case let .release(button):
                accumulator.release(button)
            }
        }
    }

    // MARK: - Sending

    private func sendTick() {
        let now = CACurrentMediaTime()
        handle(gestures.tick(at: now))
        advanceMacro(at: now)
        flush()
        if now - statsWindowStart >= 0.25 {
            let rate = Int((Double(packetsThisWindow) / (now - statsWindowStart)).rounded())
            let new = Stats(packetsPerSecond: rate)
            if new != stats { stats = new }
            packetsThisWindow = 0
            statsWindowStart = now
        }
    }

    /// Sends this tick's packets, keyboard first (PROTOCOL.md), if the link can take them;
    /// otherwise everything waits for the next tick. Without a ready dongle nothing waits:
    /// keys pressed then would type when one connects, wherever the PC's focus is by then.
    private func flush() {
        guard link.state == .ready else {
            keys.reset()
            accumulator.reset()
            return
        }
        if link.canSend, let packet = keys.drain() {
            link.send(packet.encoded())
            packetsThisWindow += 1
        }
        if link.canSend, let packet = accumulator.drain() {
            link.send(packet.encoded())
            packetsThisWindow += 1
        }
    }
}
