import Foundation

/// Speed-dependent gain, in output per millimetre of finger travel: the faster a finger moves,
/// the further each millimetre takes the pointer (pointer acceleration) or scroll (scroll
/// acceleration). Millimetres, not points, so every screen feels the same under the finger.
///
/// Up to `slowSpeed` the gain is `slowGain`; from `fastSpeed` it is `fastGain`. In between it
/// eases over (smoothstep) on a log scale of speed, so each doubling of speed adds a similar
/// share of the change.
public struct AccelerationCurve: Equatable, Sendable {
    /// Output per millimetre at slow speed: pointer counts, or scroll ticks.
    public var slowGain: Double
    /// Output per millimetre at fast speed. Equal to `slowGain` turns acceleration off.
    public var fastGain: Double
    /// Finger speed in millimetres per second where acceleration starts.
    public var slowSpeed: Double
    /// Finger speed in millimetres per second where acceleration is full.
    public var fastSpeed: Double

    public init(slowGain: Double, fastGain: Double, slowSpeed: Double, fastSpeed: Double) {
        self.slowGain = slowGain
        self.fastGain = fastGain
        self.slowSpeed = slowSpeed
        self.fastSpeed = fastSpeed
    }

    /// Output per millimetre at `speed` millimetres per second.
    public func gain(speed: Double) -> Double {
        guard speed > slowSpeed else { return slowGain }
        guard speed < fastSpeed else { return fastGain }
        let x = log(speed / slowSpeed) / log(fastSpeed / slowSpeed)
        let eased = x * x * (3 - 2 * x)
        return slowGain + (fastGain - slowGain) * eased
    }
}
