// Expected values are worked out by hand from the gesture rules in TrackpadGestures' doc
// comment and the curves below. 5 points are 1 mm throughout.
import Testing
import TocaCore

/// Drives a gesture engine with fingers in millimetres and collects what it asks for.
private struct Pad {
    var gestures = TrackpadGestures(
        pointsPerMillimetre: 5,
        pointer: AccelerationCurve(slowGain: 6, fastGain: 42, slowSpeed: 25, fastSpeed: 400),
        scroll: AccelerationCurve(slowGain: 0.5, fastGain: 2.5, slowSpeed: 20, fastSpeed: 250))
    var actions: [TrackpadAction] = []
    var fingers: [Int: (x: Double, y: Double)] = [:]

    mutating func down(_ ids: [Int], at t: Double, radius: Double = 1.5) {
        let samples = ids.map { id -> TouchSample in
            fingers[id] = (Double(id) * 15, 0)
            return sample(id, radius: radius)
        }
        actions += gestures.began(samples, at: t)
    }

    /// Moves every finger in `ids` by (dx, dy) millimetres.
    mutating func move(_ ids: [Int], dx: Double = 0, dy: Double = 0, at t: Double, radius: Double = 1.5) {
        let samples = ids.map { id -> TouchSample in
            fingers[id]!.x += dx
            fingers[id]!.y += dy
            return sample(id, radius: radius)
        }
        actions += gestures.moved(samples, at: t)
    }

    /// `steps` equal moves, `dt` seconds apart, starting `dt` after `start`. Returns the end time.
    @discardableResult
    mutating func slide(_ ids: [Int], dx: Double = 0, dy: Double = 0, steps: Int, dt: Double, from start: Double) -> Double {
        var t = start
        for _ in 0..<steps {
            t += dt
            move(ids, dx: dx, dy: dy, at: t)
        }
        return t
    }

    mutating func up(_ ids: [Int], at t: Double) {
        for id in ids { fingers[id] = nil }
        actions += gestures.ended(ids, at: t)
    }

    mutating func tick(at t: Double) {
        actions += gestures.tick(at: t)
    }

    func sample(_ id: Int, radius: Double) -> TouchSample {
        TouchSample(id: id, x: fingers[id]!.x * 5, y: fingers[id]!.y * 5, radius: radius * 5)
    }

    var moved: (dx: Double, dy: Double) {
        actions.reduce(into: (0.0, 0.0)) { sum, action in
            if case let .move(dx, dy) = action { sum.0 += dx; sum.1 += dy }
        }
    }

    var scrolled: (dx: Double, dy: Double) {
        actions.reduce(into: (0.0, 0.0)) { sum, action in
            if case let .scroll(dx, dy) = action { sum.0 += dx; sum.1 += dy }
        }
    }

    /// Everything but movement and scroll.
    var buttons: [TrackpadAction] {
        actions.filter {
            switch $0 {
            case .move, .scroll: false
            default: true
            }
        }
    }
}

@Suite struct PointerTests {
    @Test func slowMovementMovesSixCountsPerMillimetre() {
        var pad = Pad()
        pad.down([1], at: 0)
        pad.slide([1], dx: 1, steps: 10, dt: 0.1, from: 0)  // 10 mm/s

        #expect(abs(pad.moved.dx - 60) < 1e-9)
        #expect(pad.moved.dy == 0)
    }

    @Test func aSettledFastSwipeGetsTheFastGain() {
        var pad = Pad()
        pad.down([1], at: 0)
        pad.slide([1], dx: 4, steps: 60, dt: 0.004, from: 0)  // 1000 mm/s

        guard case let .move(dx, _) = pad.actions.last else {
            Issue.record("last action was not a move")
            return
        }
        #expect(abs(dx - 4 * 42) < 1e-9)
    }
}

@Suite struct ClickTests {
    @Test func aTapClicksLeftOnceTheDragWindowHasPassed() {
        var pad = Pad()
        pad.down([1], at: 0)
        pad.up([1], at: 0.1)
        pad.tick(at: 0.2)
        #expect(pad.buttons.isEmpty)

        pad.tick(at: 0.35)
        #expect(pad.buttons == [.click(.left)])
    }

    @Test func tapThenSlideDragsWithTheLeftButton() {
        var pad = Pad()
        pad.down([1], at: 0)
        pad.up([1], at: 0.1)
        pad.down([1], at: 0.2)
        let end = pad.slide([1], dx: 1, steps: 10, dt: 0.05, from: 0.2)
        pad.up([1], at: end)

        #expect(pad.buttons == [.press(.left), .release(.left)])
        #expect(pad.moved.dx > 0)
    }

    @Test func aTwoFingerTapClicksRight() {
        var pad = Pad()
        pad.down([1, 2], at: 0)
        pad.up([1, 2], at: 0.1)

        #expect(pad.buttons == [.click(.right)])
    }

    @Test func aThreeFingerTapClicksMiddle() {
        var pad = Pad()
        pad.down([1, 2, 3], at: 0)
        pad.up([1, 2, 3], at: 0.1)

        #expect(pad.buttons == [.click(.middle)])
    }

    @Test func aThirdFingerLandingLateStillMakesAMiddleClick() {
        var pad = Pad()
        pad.down([1, 2], at: 0)
        pad.down([3], at: 0.05)
        pad.up([1, 2, 3], at: 0.15)

        #expect(pad.buttons == [.click(.middle)])
    }

    @Test func threeFingersSlidingDragWithTheMiddleButton() {
        var pad = Pad()
        pad.down([1, 2, 3], at: 0)
        let end = pad.slide([1, 2, 3], dy: 1, steps: 10, dt: 0.1, from: 0)  // 10 mm/s
        pad.up([1, 2, 3], at: end)

        #expect(pad.buttons == [.press(.middle), .release(.middle)])
        #expect(pad.moved.dy > 0)
        #expect(pad.scrolled == (0, 0))
    }

    @Test func aPalmIsIgnored() {
        var pad = Pad()
        pad.down([9], at: 0, radius: 15)
        pad.move([9], dx: 20, at: 0.05, radius: 15)
        pad.down([1], at: 0.1)
        pad.up([1], at: 0.2)
        pad.tick(at: 0.5)

        #expect(pad.moved.dx == 0)
        #expect(pad.buttons == [.click(.left)])
    }
}

@Suite struct ScrollTests {
    @Test func slowTwoFingerScrollIsHalfATickPerMillimetre() {
        var pad = Pad()
        pad.down([1, 2], at: 0)
        // Fingers move down 20 mm at 10 mm/s: natural direction scrolls up (+10).
        let end = pad.slide([1, 2], dy: 1, steps: 20, dt: 0.1, from: 0)
        pad.up([1, 2], at: end)
        pad.tick(at: end + 5)

        #expect(abs(pad.scrolled.dy - 10) < 1e-9)
        #expect(pad.scrolled.dx == 0)
        #expect(pad.buttons.isEmpty)
    }

    @Test func twoFingerHorizontalSwipeLeftScrollsRightInNaturalMode() {
        var pad = Pad()
        pad.down([1, 2], at: 0)
        let end = pad.slide([1, 2], dx: -1, steps: 20, dt: 0.1, from: 0)
        pad.up([1, 2], at: end)
        pad.tick(at: end + 5)

        #expect(abs(pad.scrolled.dx - 10) < 1e-9)
        #expect(pad.scrolled.dy == 0)
    }

    @Test func classicScrollFlipsBothVerticalAndHorizontalAxes() {
        var pad = Pad()
        pad.gestures.naturalScroll = false
        pad.down([1, 2], at: 0)
        let end = pad.slide([1, 2], dx: -1, dy: 1, steps: 20, dt: 0.1, from: 0)
        pad.up([1, 2], at: end)
        pad.tick(at: end + 5)

        // Diagonal distance per step = sqrt(2) mm at ~14.1 mm/s -> still slowGain 0.5
        #expect(abs(pad.scrolled.dx - (-10)) < 1e-9)
        #expect(abs(pad.scrolled.dy - (-10)) < 1e-9)
    }

    /// Two fingers flick down at 250 mm/s (625 ticks/s, capped at 300) and lift while moving.
    private func flick(dx: Double = 0, dy: Double = 2) -> (Pad, Double) {
        var pad = Pad()
        pad.down([1, 2], at: 0)
        let end = pad.slide([1, 2], dx: dx, dy: dy, steps: 40, dt: 0.008, from: 0)
        return (pad, end)
    }

    @Test func aFlickCoastsAndSlowsToAStop() {
        var (pad, end) = flick()
        pad.up([1, 2], at: end)
        let during = pad.scrolled.dy

        pad.tick(at: end + 0.1)
        let early = pad.scrolled.dy - during
        pad.tick(at: end + 5)
        let coast = pad.scrolled.dy - during

        // 300 ticks/s decaying with a 0.35 s time constant, stopping at 3 ticks/s:
        // 300 × 0.35 × (1 − 3/300) = 103.95 ticks.
        #expect(abs(coast - 103.95) < 1e-6)
        // The first 0.1 s: 300 × 0.35 × (1 − e^(−0.1/0.35)) ≈ 26.1 ticks.
        #expect(abs(early - 26.1) < 0.1)
    }

    @Test func aHorizontalFlickCoastsAndSlowsToAStop() {
        var (pad, end) = flick(dx: -2, dy: 0)
        pad.up([1, 2], at: end)
        let during = pad.scrolled.dx

        pad.tick(at: end + 5)
        let coast = pad.scrolled.dx - during

        #expect(abs(coast - 103.95) < 1e-6)
    }

    @Test func touchingTheTrackpadStopsTheCoast() {
        var (pad, end) = flick()
        pad.up([1, 2], at: end)
        pad.tick(at: end + 0.1)
        let beforeTouch = pad.scrolled.dy

        pad.down([1], at: end + 0.12)
        pad.tick(at: end + 5)

        #expect(pad.scrolled.dy == beforeTouch)
    }

    @Test func fingersThatStopBeforeLiftingDoNotCoast() {
        var (pad, end) = flick()
        pad.up([1, 2], at: end + 0.1)
        let atLift = pad.scrolled.dy
        pad.tick(at: end + 5)

        #expect(pad.scrolled.dy == atLift)
    }

    @Test func noCoastWhenCoastingIsOff() {
        var (pad, end) = flick()
        pad.gestures.coasts = false
        pad.up([1, 2], at: end)
        let atLift = pad.scrolled.dy
        pad.tick(at: end + 5)

        #expect(pad.scrolled.dy == atLift)
    }
}
