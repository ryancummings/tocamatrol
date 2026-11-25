import Foundation

/// One finger on the trackpad, in points.
public struct TouchSample: Equatable, Sendable {
    public var id: Int
    public var x: Double
    public var y: Double
    /// The contact's major radius in points (UITouch.majorRadius). Large contacts are palms.
    public var radius: Double

    public init(id: Int, x: Double, y: Double, radius: Double = 0) {
        self.id = id
        self.x = x
        self.y = y
        self.radius = radius
    }
}

/// What a trackpad gesture asks the PC to do.
public enum TrackpadAction: Equatable, Sendable {
    /// Pointer counts, after pointer acceleration.
    case move(dx: Double, dy: Double)
    /// Horizontal and vertical scroll ticks (fractional). Positive `dx` scrolls right; positive `dy` scrolls up.
    case scroll(dx: Double, dy: Double)
    case click(MouseButtons)
    case press(MouseButtons)
    case release(MouseButtons)
}

/// Turns raw touches into trackpad actions:
///
/// - one finger moves the pointer, through pointer acceleration;
/// - a tap is a left click, sent once the tap-then-drag window has passed;
/// - touching again within that window and moving is a left-button drag until lift;
/// - a two-finger tap is a right click;
/// - two fingers moving scroll horizontally and vertically through scroll acceleration;
///   lifting them while they still move coasts until the coast slows to a stop or a finger
///   touches again;
/// - a three-finger tap is a middle click; three fingers moving drag with the middle button;
/// - a contact larger than `palmRadius` is a palm and is ignored for its whole life.
///
/// Distances are in millimetres inside, so every screen feels the same under the finger.
/// Time is in seconds on any steady clock (UITouch timestamps and CACurrentMediaTime agree).
public struct TrackpadGestures: Sendable {
    public var pointsPerMillimetre: Double
    public var pointer: AccelerationCurve
    public var scroll: AccelerationCurve
    /// Natural direction: content follows the fingers (default true).
    public var naturalScroll = true
    /// Two-finger scroll coasts after a flick.
    public var coasts = true

    public var tapMaxDuration = 0.25
    /// Millimetres a tap may wander.
    public var tapMaxTravel = 2.0
    public var tapDragWindow = 0.2
    /// Contacts with a major radius above this many millimetres are palms.
    public var palmRadius = 10.0
    /// Time constant in seconds of the finger-speed smoothing that feeds the curves.
    public var speedSmoothing = 0.04
    /// Time constant in seconds of the coast's exponential slow-down.
    public var coastDecay = 0.35
    /// Scroll speed in ticks per second a flick needs to coast.
    public var coastMinRate = 20.0
    /// The fastest coast, in ticks per second.
    public var coastMaxRate = 300.0
    /// The coast stops below this many ticks per second.
    public var coastStopRate = 3.0
    /// Fingers that rested longer than this before lifting do not coast.
    public var coastMaxPause = 0.05

    private enum Mode: Sendable { case idle, pointing, scrolling, dragArmed, dragging, threeFinger, middleDragging }

    private struct Coast: Sendable {
        var start: Double
        var rateX: Double
        var rateY: Double
        var emittedUntil: Double
    }

    /// Finger positions in millimetres.
    private var positions: [Int: (x: Double, y: Double)] = [:]
    private var palms: Set<Int> = []
    private var mode = Mode.idle
    private var sessionStart = 0.0
    private var maxFingers = 0
    private var travel = 0.0
    private var lastMoveTime = 0.0
    /// Smoothed finger speed in millimetres per second.
    private var speed = 0.0
    /// Smoothed two-finger scroll speed in ticks per second.
    private var scrollRateX = 0.0
    private var scrollRateY = 0.0
    /// When the last single tap ended, while its click waits for the tap-then-drag window.
    private var pendingTapEnd: Double?
    private var coast: Coast?

    public init(pointsPerMillimetre: Double, pointer: AccelerationCurve, scroll: AccelerationCurve) {
        self.pointsPerMillimetre = pointsPerMillimetre
        self.pointer = pointer
        self.scroll = scroll
    }

    public mutating func began(_ touches: [TouchSample], at time: Double) -> [TrackpadAction] {
        let fingers = touches.filter { !isPalm($0) }
        let palmIDs = touches.filter { isPalm($0) }.map(\.id)
        palms.formUnion(palmIDs)
        guard !fingers.isEmpty else { return [] }

        coast = nil
        var actions = flushPendingTap(at: time)
        if positions.isEmpty {
            sessionStart = time
            lastMoveTime = time
            maxFingers = 0
            travel = 0
            speed = 0
            scrollRateX = 0
            scrollRateY = 0
            if pendingTapEnd != nil {
                pendingTapEnd = nil
                mode = .dragArmed  // the click waits: this touch is a drag or a second tap
            } else {
                mode = .pointing
            }
        }
        for t in fingers { positions[t.id] = millimetres(t) }
        maxFingers = max(maxFingers, positions.count)
        if positions.count >= 2 && (mode == .pointing || mode == .dragArmed) {
            if mode == .dragArmed { actions.append(.click(.left)) }  // honour the earlier tap
            mode = .scrolling
        }
        if positions.count >= 3 && mode == .scrolling && travel <= tapMaxTravel {
            mode = .threeFinger
        }
        return actions
    }

    public mutating func moved(_ touches: [TouchSample], at time: Double) -> [TrackpadAction] {
        var sumDx = 0.0, sumDy = 0.0, count = 0.0
        for t in touches {
            guard let old = positions[t.id] else { continue }
            if isPalm(t) {
                // A finger that spread into a palm: drop it.
                positions[t.id] = nil
                palms.insert(t.id)
                continue
            }
            let new = millimetres(t)
            sumDx += new.x - old.x
            sumDy += new.y - old.y
            count += 1
            positions[t.id] = new
        }
        guard count > 0 else { return [] }
        let dx = sumDx / count, dy = sumDy / count
        let distance = (dx * dx + dy * dy).squareRoot()
        travel += distance
        let dt = max(time - lastMoveTime, 0.001)
        lastMoveTime = time
        let smoothing = 1 - exp(-dt / speedSmoothing)
        speed += smoothing * (distance / dt - speed)

        switch mode {
        case .idle:
            return []
        case .scrolling:
            let gain = scroll.gain(speed: speed)
            // Natural: fingers down (+dy) -> +vscroll (up); fingers left (-dx) -> +hscroll (right).
            let hSign = naturalScroll ? -1.0 : 1.0
            let vSign = naturalScroll ? 1.0 : -1.0
            let ticksX = dx * gain * hSign
            let ticksY = dy * gain * vSign
            scrollRateX += smoothing * (ticksX / dt - scrollRateX)
            scrollRateY += smoothing * (ticksY / dt - scrollRateY)
            return [.scroll(dx: ticksX, dy: ticksY)]
        case .dragArmed:
            guard travel > tapMaxTravel else { return [] }
            mode = .dragging
            return [.press(.left), pointerMove(dx: dx, dy: dy)]
        case .threeFinger:
            guard travel > tapMaxTravel else { return [] }
            mode = .middleDragging
            return [.press(.middle), pointerMove(dx: dx, dy: dy)]
        case .pointing, .dragging, .middleDragging:
            return [pointerMove(dx: dx, dy: dy)]
        }
    }

    public mutating func ended(_ ids: [Int], at time: Double) -> [TrackpadAction] {
        for id in ids {
            positions[id] = nil
            palms.remove(id)
        }
        guard positions.isEmpty, mode != .idle else { return [] }
        defer { mode = .idle }

        let isTap = time - sessionStart <= tapMaxDuration && travel <= tapMaxTravel
        switch mode {
        case .dragging:
            return [.release(.left)]
        case .middleDragging:
            return [.release(.middle)]
        case .dragArmed:
            // Tap, tap: a double click. Anything slower or longer: the first tap's click only.
            return isTap ? [.click(.left), .click(.left)] : [.click(.left)]
        case .threeFinger:
            return isTap ? [.click(.middle)] : []
        case .scrolling:
            if isTap && maxFingers == 2 { return [.click(.right)] }
            startCoast(at: time)
            return []
        case .pointing:
            if isTap && maxFingers == 1 { pendingTapEnd = time }
            return []
        case .idle:
            return []
        }
    }

    /// Call every send tick: sends a waiting tap's click once the tap-then-drag window passes,
    /// and the coast's scroll since the last tick.
    public mutating func tick(at time: Double) -> [TrackpadAction] {
        var actions = flushPendingTap(at: time)
        if let delta = coastTicks(until: time) { actions.append(.scroll(dx: delta.dx, dy: delta.dy)) }
        return actions
    }

    /// Drops all touches, as when the view goes away. A held drag is released.
    public mutating func cancelAll() -> [TrackpadAction] {
        let held: [TrackpadAction] = switch mode {
        case .dragging: [.release(.left)]
        case .middleDragging: [.release(.middle)]
        default: []
        }
        positions.removeAll()
        palms.removeAll()
        mode = .idle
        pendingTapEnd = nil
        coast = nil
        return held
    }

    private func isPalm(_ touch: TouchSample) -> Bool {
        palms.contains(touch.id) || touch.radius / pointsPerMillimetre > palmRadius
    }

    private func millimetres(_ touch: TouchSample) -> (x: Double, y: Double) {
        (touch.x / pointsPerMillimetre, touch.y / pointsPerMillimetre)
    }

    private mutating func flushPendingTap(at time: Double) -> [TrackpadAction] {
        guard let end = pendingTapEnd, time - end > tapDragWindow else { return [] }
        pendingTapEnd = nil
        return [.click(.left)]
    }

    private func pointerMove(dx: Double, dy: Double) -> TrackpadAction {
        let gain = pointer.gain(speed: speed)
        return .move(dx: dx * gain, dy: dy * gain)
    }

    private mutating func startCoast(at time: Double) {
        let magnitude = hypot(scrollRateX, scrollRateY)
        guard coasts, time - lastMoveTime <= coastMaxPause, magnitude >= coastMinRate else { return }
        let clamped = min(magnitude, coastMaxRate)
        let scale = clamped / magnitude
        coast = Coast(start: time, rateX: scrollRateX * scale, rateY: scrollRateY * scale, emittedUntil: time)
    }

    /// The coast's ticks from the last tick to `time`: the integral of rate × e^(−t/decay).
    private mutating func coastTicks(until time: Double) -> (dx: Double, dy: Double)? {
        guard let c = coast, time > c.emittedUntil else { return nil }
        let speed = hypot(c.rateX, c.rateY)
        guard speed > coastStopRate else {
            coast = nil
            return nil
        }
        let stopAfter = coastDecay * log(speed / coastStopRate)
        let from = c.emittedUntil - c.start
        let to = min(time - c.start, stopAfter)
        coast?.emittedUntil = time
        if time - c.start >= stopAfter { coast = nil }
        guard to > from else { return nil }
        let factor = coastDecay * (exp(-from / coastDecay) - exp(-to / coastDecay))
        return (c.rateX * factor, c.rateY * factor)
    }
}
