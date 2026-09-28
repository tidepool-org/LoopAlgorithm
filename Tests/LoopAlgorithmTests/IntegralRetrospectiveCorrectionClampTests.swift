//
//  IntegralRetrospectiveCorrectionClampTests.swift
//  LoopAlgorithm
//
//  Tests for the deployed-LoopKit integral-correction CLAMP that was dropped in
//  the LoopAlgorithm port. The clamp bounds the wound-up integral term by an
//  ISF×basal-scaled, target-relative window so IRC can't drive the forecast
//  into over-/under-dosing. When the clamp settings are nil, IRC must behave
//  exactly as before (unclamped), byte-identical to prior runs.
//

import XCTest
@testable import LoopAlgorithm

final class IntegralRetrospectiveCorrectionClampTests: XCTestCase {

    private let unit = LoopUnit.milligramsPerDeciliter

    /// Builds a dense (5-min spaced) run of constant same-sign discrepancies over
    /// the full 180-min retrospection window so the integral converges toward its
    /// asymptote (≈ 1.087 × discrepancy value). The last entry ends at `glucoseDate`
    /// so it passes the recency guard.
    private func discrepancies(value: Double, endingAt glucoseDate: Date, count: Int = 36) -> [GlucoseChange] {
        (0..<count).map { i in
            let end = glucoseDate.addingTimeInterval(TimeInterval(minutes: Double(-(count - 1 - i) * 5)))
            return GlucoseChange(
                startDate: end.addingTimeInterval(.minutes(-30)),
                endDate: end,
                quantity: LoopQuantity(unit: unit, doubleValue: value))
        }
    }

    private func makeIRC() -> IntegralRetrospectiveCorrection {
        IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
    }

    private func range(_ lo: Double, _ hi: Double) -> ClosedRange<LoopQuantity> {
        LoopQuantity(unit: unit, doubleValue: lo)...LoopQuantity(unit: unit, doubleValue: hi)
    }

    // MARK: – Positive clamp

    func testPositiveIntegralIsClampedToPositiveLimit() {
        let glucoseDate = Date()
        let startingGlucose = SimpleGlucoseValue(startDate: glucoseDate, quantity: LoopQuantity(unit: unit, doubleValue: 200))
        let discr = discrepancies(value: 100, endingAt: glucoseDate)

        // zeroTempEffect = |50 × 1.0| = 50.
        // positiveLimit = min(max(200-120, 1×50), 4×50) = min(max(80,50),200) = 80.
        let isf = LoopQuantity(unit: unit, doubleValue: 50)
        let basal = 1.0

        // Unclamped reference (nil inputs ⇒ clamp skipped).
        let ircUnclamped = makeIRC()
        _ = ircUnclamped.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: discr,
            recencyInterval: .minutes(15),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)
        XCTAssertGreaterThan(ircUnclamped.integralCorrection, 80,
                             "Unclamped integral should wind up past the would-be clamp limit")

        // Clamped run.
        let ircClamped = makeIRC()
        _ = ircClamped.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: discr,
            recencyInterval: .minutes(15),
            integralClamp: IntegralRCClampSettings(insulinSensitivity: isf, basalRate: basal, correctionRange: range(100, 120)),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)
        XCTAssertEqual(ircClamped.integralCorrection, 80, accuracy: 1e-9,
                       "Wound-up positive integral must be clamped to the ISF×basal/target positive limit")
    }

    // MARK: – Negative clamp

    func testNegativeIntegralIsClampedToNegativeLimit() {
        let glucoseDate = Date()
        // BG below range: negativeLimit = -max(10, 60-100) = -max(10,-40) = -10.
        let startingGlucose = SimpleGlucoseValue(startDate: glucoseDate, quantity: LoopQuantity(unit: unit, doubleValue: 60))
        let discr = discrepancies(value: -100, endingAt: glucoseDate)
        let isf = LoopQuantity(unit: unit, doubleValue: 50)

        let ircUnclamped = makeIRC()
        _ = ircUnclamped.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: discr,
            recencyInterval: .minutes(15),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)
        XCTAssertLessThan(ircUnclamped.integralCorrection, -10,
                          "Unclamped negative integral should wind down past the would-be clamp floor")

        let ircClamped = makeIRC()
        _ = ircClamped.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: discr,
            recencyInterval: .minutes(15),
            integralClamp: IntegralRCClampSettings(insulinSensitivity: isf, basalRate: 1.0, correctionRange: range(100, 120)),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)
        XCTAssertEqual(ircClamped.integralCorrection, -10, accuracy: 1e-9,
                       "Wound-up negative integral must be clamped to the target-relative negative limit")
    }

    // MARK: – Clamp is a no-op within bounds

    func testIntegralWithinBoundsIsUnchangedByClamp() {
        let glucoseDate = Date()
        let startingGlucose = SimpleGlucoseValue(startDate: glucoseDate, quantity: LoopQuantity(unit: unit, doubleValue: 130))
        // Small discrepancy ⇒ integral ≈ 5.4, well inside posLimit (=50 at BG 130).
        let discr = discrepancies(value: 5, endingAt: glucoseDate)
        let isf = LoopQuantity(unit: unit, doubleValue: 50)

        let ircUnclamped = makeIRC()
        _ = ircUnclamped.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: discr,
            recencyInterval: .minutes(15),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)

        let ircClamped = makeIRC()
        _ = ircClamped.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: discr,
            recencyInterval: .minutes(15),
            integralClamp: IntegralRCClampSettings(insulinSensitivity: isf, basalRate: 1.0, correctionRange: range(100, 120)),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)

        XCTAssertEqual(ircClamped.integralCorrection, ircUnclamped.integralCorrection, accuracy: 1e-12,
                       "An integral already inside the clamp window must be left unchanged")
    }

    // MARK: – End-to-end effect magnitude

    func testClampReducesTotalCorrectionEffectMagnitude() {
        let glucoseDate = Date()
        let startingGlucose = SimpleGlucoseValue(startDate: glucoseDate, quantity: LoopQuantity(unit: unit, doubleValue: 200))
        let discr = discrepancies(value: 100, endingAt: glucoseDate)
        let isf = LoopQuantity(unit: unit, doubleValue: 50)

        let ircUnclamped = makeIRC()
        let effUnclamped = ircUnclamped.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: discr,
            recencyInterval: .minutes(15),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)

        let ircClamped = makeIRC()
        let effClamped = ircClamped.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: discr,
            recencyInterval: .minutes(15),
            integralClamp: IntegralRCClampSettings(insulinSensitivity: isf, basalRate: 1.0, correctionRange: range(100, 120)),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)

        XCTAssertFalse(effUnclamped.isEmpty)
        XCTAssertFalse(effClamped.isEmpty)

        let lastUnclamped = effUnclamped.last!.quantity.doubleValue(for: unit)
        let lastClamped = effClamped.last!.quantity.doubleValue(for: unit)
        XCTAssertGreaterThan(lastUnclamped, lastClamped,
                             "Clamping the integral must reduce the projected positive correction effect")

        let totalUnclamped = ircUnclamped.totalGlucoseCorrectionEffect!.doubleValue(for: unit)
        let totalClamped = ircClamped.totalGlucoseCorrectionEffect!.doubleValue(for: unit)
        // Difference should equal the integral reduction (proportional/differential unchanged).
        XCTAssertEqual(totalUnclamped - totalClamped,
                       ircUnclamped.integralCorrection - ircClamped.integralCorrection,
                       accuracy: 1e-9)
    }
}
