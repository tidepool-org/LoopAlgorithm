//
//  IntegralRetrospectiveCorrectionTests.swift
//  
//
//  Created by Pete Schwamb on 2/21/24.
//

import XCTest
@testable import LoopAlgorithm

final class IntegralRetrospectiveCorrectionTests: XCTestCase {

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()


    func testIntegralRestrospectiveCorrection() {
        let startDate = dateFormatter.date(from: "2015-07-13T12:02:37")!

        func d(_ interval: TimeInterval) -> Date {
            return startDate.addingTimeInterval(interval)
        }

        let startingGlucose = SimpleGlucoseValue(startDate: startDate, quantity: .glucose(100))

        // +10 mg/dL over 30 minutes
        let retrospectiveGlucoseDiscrepanciesSummed = [
            GlucoseChange(startDate: d(.minutes(-30)), endDate: startDate, quantity: .glucose(10))
        ]

        let irc = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)

        let effect = irc.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: retrospectiveGlucoseDiscrepanciesSummed,
            recencyInterval:  TimeInterval(minutes: 15),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval
        )

        XCTAssertEqual(effect.last?.quantity.doubleValue(for: .milligramsPerDeciliter) ?? 0, 110, accuracy: 0.05)
        XCTAssertEqual(effect.last?.startDate, dateFormatter.date(from: "2015-07-13T13:00:00")!)
    }

    // MARK: - Integral-correction clamp (deployed-LoopKit safety bound)
    //
    // The clamp bounds the wound-up integral term by an ISF×basal-scaled, target-relative
    // window (restored from deployed LoopKit; dropped in the LoopAlgorithm port). It is
    // active only when insulinSensitivity, basalRate and correctionRange are supplied.

    /// `count` contiguous 5-min discrepancies of `valuePerStep` mg/dL, ending at `endingAt`.
    private func windup(endingAt: Date, count: Int, valuePerStep: Double) -> [GlucoseChange] {
        (0..<count).reversed().map { i in
            let end = endingAt.addingTimeInterval(.minutes(-Double(i) * 5))
            return GlucoseChange(startDate: end.addingTimeInterval(.minutes(-5)),
                                 endDate: end,
                                 quantity: .glucose(valuePerStep))
        }
    }

    func testIntegralCorrectionClampedToPositiveLimit() {
        let start = dateFormatter.date(from: "2015-07-13T12:00:00")!
        // Glucose 150, above a 100–120 correction range; ISF 50, basal 1 U/hr → zeroTempEffect 50.
        // positive limit = min(max(150 − 120, 1×50), 4×50) = 50
        let startingGlucose = SimpleGlucoseValue(startDate: start, quantity: .glucose(150))
        // Large sustained under-prediction so the integral winds up past the (generous,
        // 1×–4× zeroTempEffect) positive limit and the clamp is exercised.
        let discrepancies = windup(endingAt: start, count: 18, valuePerStep: 100)
        let positiveLimit = 50.0

        let unclamped = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        let unclampedEffect = unclamped.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: discrepancies,
            recencyInterval: TimeInterval(minutes: 15),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)
        XCTAssertGreaterThan(unclamped.integralCorrection, positiveLimit,
                             "windup must exceed the clamp limit so the clamp is exercised")

        let clamped = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        let clampedEffect = clamped.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: discrepancies,
            recencyInterval: TimeInterval(minutes: 15),
            insulinSensitivity: .glucose(50),
            basalRate: 1.0,
            correctionRange: .glucose(100)...(.glucose(120)),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)

        XCTAssertEqual(clamped.integralCorrection, positiveLimit, accuracy: 0.001)
        // Clamping the integral pulls the forecast down relative to unclamped.
        XCTAssertLessThan(clampedEffect.last!.quantity.doubleValue(for: .milligramsPerDeciliter),
                          unclampedEffect.last!.quantity.doubleValue(for: .milligramsPerDeciliter))
    }

    func testIntegralCorrectionClampedToNegativeLimit() {
        let start = dateFormatter.date(from: "2015-07-13T12:00:00")!
        // Glucose 90, below a 100–120 correction range.
        // negative limit = −max(10, 90 − 100) = −10
        let startingGlucose = SimpleGlucoseValue(startDate: start, quantity: .glucose(90))
        let discrepancies = windup(endingAt: start, count: 18, valuePerStep: -20)
        let negativeLimit = -10.0

        let unclamped = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        _ = unclamped.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: discrepancies,
            recencyInterval: TimeInterval(minutes: 15),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)
        XCTAssertLessThan(unclamped.integralCorrection, negativeLimit,
                          "negative windup must exceed the clamp limit so the clamp is exercised")

        let clamped = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        _ = clamped.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: discrepancies,
            recencyInterval: TimeInterval(minutes: 15),
            insulinSensitivity: .glucose(50),
            basalRate: 1.0,
            correctionRange: .glucose(100)...(.glucose(120)),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)

        XCTAssertEqual(clamped.integralCorrection, negativeLimit, accuracy: 0.001)
    }

    func testClampIsInertWhenIntegralWithinLimits() {
        let start = dateFormatter.date(from: "2015-07-13T12:00:00")!
        let startingGlucose = SimpleGlucoseValue(startDate: start, quantity: .glucose(150))
        // Small windup: integral stays well within the ±limits, so the clamp must not alter anything.
        let discrepancies = windup(endingAt: start, count: 2, valuePerStep: 4)

        let unclamped = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        let e1 = unclamped.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: discrepancies,
            recencyInterval: TimeInterval(minutes: 15),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)
        XCTAssertLessThan(abs(unclamped.integralCorrection), 50.0)

        let clamped = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        let e2 = clamped.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: discrepancies,
            recencyInterval: TimeInterval(minutes: 15),
            insulinSensitivity: .glucose(50),
            basalRate: 1.0,
            correctionRange: .glucose(100)...(.glucose(120)),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)

        XCTAssertEqual(clamped.integralCorrection, unclamped.integralCorrection, accuracy: 0.001)
        XCTAssertEqual(e2.last!.quantity.doubleValue(for: .milligramsPerDeciliter),
                       e1.last!.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: 0.001)
    }
}
