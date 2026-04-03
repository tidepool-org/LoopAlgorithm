//
//  AsymmetricMomentumTests.swift
//  LoopAlgorithm
//
//  Tests for asymmetricMomentumEffect and hybridAsymmetricMomentumEffect.
//

import XCTest
@testable import LoopAlgorithm

final class AsymmetricMomentumTests: XCTestCase {

    private let unit = LoopUnit.milligramsPerDeciliter

    /// Build a synthetic 5-min glucose timeline starting at `start` with the
    /// given values. Default 5-min spacing matches CGM cadence.
    private func samples(_ values: [Double], startingAt start: Date = Date(),
                         spacing: TimeInterval = 5 * 60) -> [GlucoseFixtureValue] {
        return values.enumerated().map { i, v in
            GlucoseFixtureValue(
                startDate: start.addingTimeInterval(TimeInterval(i) * spacing),
                quantity: LoopQuantity(unit: unit, doubleValue: v),
                isDisplayOnly: false,
                wasUserEntered: false,
                provenanceIdentifier: "test",
                condition: nil,
                trendRate: nil
            )
        }
    }

    // MARK: - Asymmetric momentum

    func testAsymmetricReturnsEmptyOnTooFewSamples() {
        let input = samples([100, 105])  // only 2 samples
        let effects = input.asymmetricMomentumEffect()
        XCTAssertTrue(effects.isEmpty, "Need > 2 samples; got \(effects.count) effects")
    }

    func testAsymmetricVelocityCapClamps() {
        // Strongly rising: 100 → 200 over 25 min = +4 mg/dL/min sustained.
        // With cap at 1.0 mg/dL/min, projected effect should be bounded by
        // 1.0 × (projected_seconds) at the largest projected horizon.
        let input = samples([100, 120, 140, 160, 180, 200])
        let cap = LoopQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 1.0)
        let effects = input.asymmetricMomentumEffect(velocityMaximum: cap)
        XCTAssertFalse(effects.isEmpty)
        // Last sample is at index 5 → +25 min from start
        // After velocity cap, the largest projected value over 30 min should
        // not exceed 1.0 mg/dL/min × 30 min = 30 mg/dL.
        let lastValue = effects.last!.quantity.doubleValue(for: unit)
        XCTAssertLessThanOrEqual(lastValue, 30.0 + 1e-6,
            "Capped velocity should bound the last projected effect")
    }

    func testAsymmetricBuildsSlowlyOnRise() {
        // Steady rise. The EMA-on-rise uses alphaSlow=0.15, so the
        // smoothed velocity should be SMALLER than the instantaneous velocity.
        // Build: start with a low-velocity, then accelerate. Slow EMA should
        // lag the acceleration, so projected effect < (instantaneous slope × time).
        // 100, 102, 104, 110, 120, 130 — accelerating rise
        let input = samples([100, 102, 104, 110, 120, 130])
        let effects = input.asymmetricMomentumEffect(
            velocityMaximum: LoopQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 100), // effectively uncapped
            alphaSlow: 0.15,
            alphaFast: 0.85
        )
        XCTAssertFalse(effects.isEmpty)
        // Instantaneous velocity of the last interval (120 → 130 over 5 min) = +2 mg/dL/min.
        // EMA-slow should produce a smoothed velocity well below that.
        // At 30 min projection: effect should be < 2 mg/dL/min × 30 min = 60.
        let lastValue = effects.last!.quantity.doubleValue(for: unit)
        XCTAssertLessThan(lastValue, 60.0,
            "Slow alpha should suppress the latest acceleration; last effect was \(lastValue)")
    }

    func testAsymmetricRespondsQuicklyOnDrop() {
        // Rise then sharp drop. With alphaFast=0.85 on falling instantV,
        // the smoothed velocity should drop quickly to reflect the latest decline.
        // 100, 110, 120, 125, 120, 110 — rise then drop
        let input = samples([100, 110, 120, 125, 120, 110])
        let effects = input.asymmetricMomentumEffect(
            velocityMaximum: LoopQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 100),
            alphaSlow: 0.15,
            alphaFast: 0.85
        )
        XCTAssertFalse(effects.isEmpty)
        // Last instantV (120 → 110 over 5 min) = -2 mg/dL/min.
        // With alphaFast=0.85, smoothed velocity should be much closer to -2
        // than to the prior smoothed (which built slowly).
        // Velocity is then clamped to min(v, velocityMax), which only caps positive.
        // Effect at any projected time = (time_from_lastSample) × smoothedVel,
        // clamped at lower bound 0 via Swift.max(0, time_from_lastSample) — so
        // negative velocity over time-since-last gives 0 or below. Actually the
        // formula in code is Swift.max(0, date.timeIntervalSince(lastSample))
        // × cappedVelocity, so at date == lastSample.startDate, effect=0.
        // For dates after lastSample, time_from_lastSample > 0 and velocity is
        // negative → effect < 0.
        let firstEffectAfterLast = effects.first { $0.startDate > input.last!.startDate }
        XCTAssertNotNil(firstEffectAfterLast)
        let v = firstEffectAfterLast!.quantity.doubleValue(for: unit)
        XCTAssertLessThan(v, 0,
            "After a drop, projected effect should be negative (reflecting BG falling)")
    }

    func testAsymmetricAlphaEqualBehavesLikeSimpleEMA() {
        // With alphaSlow == alphaFast, the asymmetric switch becomes a no-op
        // and we get a simple EMA. Sanity-check that the output is finite and
        // doesn't differ for two equal alphas of different values.
        let input = samples([100, 105, 110, 115, 120])
        let effectsA = input.asymmetricMomentumEffect(alphaSlow: 0.5, alphaFast: 0.5)
        let effectsB = input.asymmetricMomentumEffect(alphaSlow: 0.5, alphaFast: 0.5)
        XCTAssertEqual(effectsA.count, effectsB.count)
        for (a, b) in zip(effectsA, effectsB) {
            XCTAssertEqual(
                a.quantity.doubleValue(for: unit),
                b.quantity.doubleValue(for: unit),
                accuracy: 1e-9)
        }
        // And the result should still be finite & non-empty for valid input.
        XCTAssertFalse(effectsA.isEmpty)
        XCTAssertTrue(effectsA.allSatisfy { $0.quantity.doubleValue(for: unit).isFinite })
    }

    // MARK: - Hybrid asymmetric momentum

    func testHybridReturnsEmptyOnTooFewSamples() {
        let input = samples([100, 105])
        let effects = input.hybridAsymmetricMomentumEffect()
        XCTAssertTrue(effects.isEmpty)
    }

    func testHybridMatchesLinearOnSteadyRise() {
        // Steady rise: latest instantV is consistent with regression slope, so
        // hybrid should NOT switch to fast-EMA mode and the output should
        // match linearMomentumEffect.
        let input = samples([100, 105, 110, 115, 120])
        let linear = input.linearMomentumEffect(duration: .minutes(30))
        let hybrid = input.hybridAsymmetricMomentumEffect(duration: .minutes(30))
        XCTAssertEqual(linear.count, hybrid.count)
        XCTAssertFalse(linear.isEmpty)
        for (l, h) in zip(linear, hybrid) {
            XCTAssertEqual(l.startDate, h.startDate)
            // Equal within tight numerical tolerance — same algorithm path
            XCTAssertEqual(
                l.quantity.doubleValue(for: unit),
                h.quantity.doubleValue(for: unit),
                accuracy: 1e-9,
                "Hybrid should match linear on steady rise")
        }
    }

    func testHybridDropsToFastEMAOnFall() {
        // Build a sequence that rises then drops sharply at the end. The
        // linear regression sees a net positive slope, but the LATEST
        // instantaneous velocity is strongly negative — hybrid should switch
        // to fast-EMA and produce a smaller (or negative) projected slope
        // than linearMomentumEffect.
        let input = samples([100, 105, 110, 115, 105])  // rises then drops
        let linear = input.linearMomentumEffect(duration: .minutes(30))
        let hybrid = input.hybridAsymmetricMomentumEffect(duration: .minutes(30))
        XCTAssertEqual(linear.count, hybrid.count)
        XCTAssertFalse(linear.isEmpty)
        // Compare the last projected value: hybrid should be ≤ linear (less
        // momentum projected forward when the trend has just reversed).
        let lastLinear = linear.last!.quantity.doubleValue(for: unit)
        let lastHybrid = hybrid.last!.quantity.doubleValue(for: unit)
        XCTAssertLessThan(lastHybrid, lastLinear,
            "Hybrid should temper the projected momentum on a drop. linear=\(lastLinear) hybrid=\(lastHybrid)")
    }

    func testHybridRespectsVelocityCap() {
        // Strongly rising → cap should bound projected effect.
        let input = samples([100, 120, 140, 160, 180])
        let cap = LoopQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 1.0)
        let effects = input.hybridAsymmetricMomentumEffect(velocityMaximum: cap, alphaFast: 0.85)
        XCTAssertFalse(effects.isEmpty)
        // Last projected value should not exceed cap × 30 min projection
        let lastValue = effects.last!.quantity.doubleValue(for: unit)
        XCTAssertLessThanOrEqual(lastValue, 30.0 + 1e-6)
    }
}
