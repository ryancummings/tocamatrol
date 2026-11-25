// Expected values are worked out by hand from the curve definitions in the doc comments.
import Testing
import TocaCore

@Suite struct AccelerationCurveTests {
    // 6 counts per mm up to 25 mm/s, 42 counts per mm from 400 mm/s.
    let curve = AccelerationCurve(slowGain: 6, fastGain: 42, slowSpeed: 25, fastSpeed: 400)

    @Test func slowMovementGetsTheSlowGain() {
        #expect(curve.gain(speed: 0) == 6)
        #expect(curve.gain(speed: 25) == 6)
    }

    @Test func fastMovementGetsTheFastGain() {
        #expect(curve.gain(speed: 400) == 42)
        #expect(curve.gain(speed: 3000) == 42)
    }

    @Test func easesOverOnALogSpeedScale() {
        // 100 mm/s is halfway from 25 to 400 on a log scale (×4, then ×4 again), so the gain is halfway.
        #expect(abs(curve.gain(speed: 100) - 24) < 1e-9)
        // A quarter of the way (×2): smoothstep(0.25) = 0.15625 of the 36 extra, so 11.625.
        #expect(abs(curve.gain(speed: 50) - 11.625) < 1e-9)
    }

    @Test func equalGainsIsLinear() {
        let flat = AccelerationCurve(slowGain: 6, fastGain: 6, slowSpeed: 25, fastSpeed: 400)

        #expect(flat.gain(speed: 10) == 6)
        #expect(flat.gain(speed: 3000) == 6)
    }
}
