import Foundation

/// One key going down or up in a macro, after a pause.
public struct MacroStep: Hashable, Sendable {
    public enum Action: String, Sendable { case press, release }

    public var action: Action
    public var key: KeyChord
    /// Milliseconds after the step before it; the first step's is 0.
    public var delay: Int

    public init(_ action: Action, _ key: KeyChord, after delay: Int = 0) {
        self.action = action
        self.key = key
        self.delay = delay
    }
}

/// Turns what the virtual keyboard sees, key downs and ups with their times, into macro steps.
public struct MacroRecorder: Sendable {
    public private(set) var steps: [MacroStep] = []
    /// Keys the macro has pressed and not yet released, in press order.
    private var held: [KeyChord] = []
    private var lastTime: TimeInterval?

    public init() {}

    public mutating func press(_ chord: KeyChord, at time: TimeInterval) {
        guard !held.contains(chord) else { return }
        held.append(chord)
        record(.press, chord, at: time)
    }

    /// Ignored for a key the macro did not press, such as one held before recording began.
    public mutating func release(_ chord: KeyChord, at time: TimeInterval) {
        guard let index = held.firstIndex(of: chord) else { return }
        held.remove(at: index)
        record(.release, chord, at: time)
    }

    /// The macro's steps, ending with every key up: keys still held are released at once,
    /// last pressed first.
    public mutating func finish() -> [MacroStep] {
        while let chord = held.popLast() {
            steps.append(MacroStep(.release, chord))
        }
        return steps
    }

    private mutating func record(_ action: MacroStep.Action, _ chord: KeyChord, at time: TimeInterval) {
        let delay = lastTime.map { Int(((time - $0) * 1000).rounded()) } ?? 0
        lastTime = time
        steps.append(MacroStep(action, chord, after: delay))
    }
}

/// How fast a macro plays: its pauses are divided by the factor.
public enum MacroSpeed: String, CaseIterable, Codable, Sendable {
    case normal, double, quadruple, instant

    /// Recorded pauses are divided by this; Instant drops them.
    public var factor: Double {
        switch self {
        case .normal: 1
        case .double: 2
        case .quadruple: 4
        case .instant: .infinity
        }
    }
}

/// Plays a macro's steps against the clock. The send tick asks it for the steps due by now
/// and hands them to the key sender, which sends each key change in its own packet.
public struct MacroPlayer: Sendable {
    /// Each step with its playback time, in order.
    private let schedule: [(time: TimeInterval, step: MacroStep)]
    private var next = 0
    /// Keys pressed by steps already handed out and not yet released.
    private var held: [KeyChord] = []

    public init(_ steps: [MacroStep], speed: MacroSpeed, startingAt start: TimeInterval) {
        var time = start
        schedule = steps.map { step in
            time += Double(step.delay) / 1000 / speed.factor
            return (time, step)
        }
    }

    public var isFinished: Bool { next == schedule.count }

    /// The steps whose time has come by `time`, oldest first. Each step is handed out once.
    public mutating func due(at time: TimeInterval) -> [MacroStep] {
        var steps: [MacroStep] = []
        while next < schedule.count, schedule[next].time <= time {
            let step = schedule[next].step
            switch step.action {
            case .press: held.append(step.key)
            case .release: held.removeAll { $0 == step.key }
            }
            steps.append(step)
            next += 1
        }
        return steps
    }

    /// Ends playback now: the releases for every key the macro still holds, last pressed
    /// first. No further steps come due.
    public mutating func stop() -> [MacroStep] {
        next = schedule.count
        var releases: [MacroStep] = []
        while let chord = held.popLast() {
            releases.append(MacroStep(.release, chord))
        }
        return releases
    }
}
