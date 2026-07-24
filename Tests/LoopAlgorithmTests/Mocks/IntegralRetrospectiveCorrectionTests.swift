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

    // MARK: - Correction-rate clamp (settings-free)
    //
    // A physiological ceiling on the RC correction rate replaces the deployed-LoopKit
    // integral clamp, which scaled the bound by ISF×basal and the target range. See
    // `defaultMaxCorrectionVelocity`.

    private let capMgdlPerSec = 4.0 / 60.0

    /// `count` contiguous 5-min discrepancies of `valuePerStep` mg/dL, ending at `endingAt`.
    private func windup(endingAt: Date, count: Int, valuePerStep: Double) -> [GlucoseChange] {
        (0..<count).reversed().map { i in
            let end = endingAt.addingTimeInterval(.minutes(-Double(i) * 5))
            return GlucoseChange(startDate: end.addingTimeInterval(.minutes(-5)),
                                 endDate: end, quantity: .glucose(valuePerStep))
        }
    }

    private func compute(_ irc: IntegralRetrospectiveCorrection, from: SimpleGlucoseValue,
                         _ discrepancies: [GlucoseChange]) -> [GlucoseEffect] {
        irc.computeEffect(
            startingAt: from,
            retrospectiveGlucoseDiscrepanciesSummed: discrepancies,
            recencyInterval: TimeInterval(minutes: 15),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval)
    }

    func testCorrectionRateClampedToCeiling() {
        let start = dateFormatter.date(from: "2015-07-13T12:00:00")!
        let g = SimpleGlucoseValue(startDate: start, quantity: .glucose(150))
        // Huge sustained under-prediction so the correction rate exceeds the ceiling.
        let discrepancies = windup(endingAt: start, count: 18, valuePerStep: 250)

        let unclamped = IntegralRetrospectiveCorrection(
            effectDuration: LoopMath.retrospectiveCorrectionEffectDuration, maxCorrectionVelocity: nil)
        let unclampedEffect = compute(unclamped, from: g, discrepancies)
        XCTAssertGreaterThan(unclamped.correctionVelocity!.doubleValue(for: .milligramsPerDeciliterPerSecond),
                             capMgdlPerSec, "windup must exceed the ceiling so the clamp is exercised")

        // Default ceiling (4 mg/dL/min).
        let clamped = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        let clampedEffect = compute(clamped, from: g, discrepancies)
        XCTAssertEqual(clamped.correctionVelocity!.doubleValue(for: .milligramsPerDeciliterPerSecond),
                       capMgdlPerSec, accuracy: 1e-9)
        // Clamping the rate reduces the forecast excursion.
        XCTAssertLessThan(clampedEffect.last!.quantity.doubleValue(for: .milligramsPerDeciliter),
                          unclampedEffect.last!.quantity.doubleValue(for: .milligramsPerDeciliter))
    }

    func testCorrectionRateClampIsSymmetricForNegativeDiscrepancies() {
        let start = dateFormatter.date(from: "2015-07-13T12:00:00")!
        let g = SimpleGlucoseValue(startDate: start, quantity: .glucose(90))
        let discrepancies = windup(endingAt: start, count: 18, valuePerStep: -250)

        let clamped = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        _ = compute(clamped, from: g, discrepancies)
        XCTAssertEqual(clamped.correctionVelocity!.doubleValue(for: .milligramsPerDeciliterPerSecond),
                       -capMgdlPerSec, accuracy: 1e-9)
    }

    func testCorrectionRateUnclampedWhenBelowCeiling() {
        let start = dateFormatter.date(from: "2015-07-13T12:00:00")!
        let g = SimpleGlucoseValue(startDate: start, quantity: .glucose(120))
        // Small windup: rate stays under the ceiling, so the clamp must not alter anything.
        let discrepancies = windup(endingAt: start, count: 3, valuePerStep: 5)

        let clamped = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        let e1 = compute(clamped, from: g, discrepancies)
        XCTAssertLessThan(abs(clamped.correctionVelocity!.doubleValue(for: .milligramsPerDeciliterPerSecond)),
                          capMgdlPerSec)

        let noClamp = IntegralRetrospectiveCorrection(
            effectDuration: LoopMath.retrospectiveCorrectionEffectDuration, maxCorrectionVelocity: nil)
        let e2 = compute(noClamp, from: g, discrepancies)
        XCTAssertEqual(e1.last!.quantity.doubleValue(for: .milligramsPerDeciliter),
                       e2.last!.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: 1e-9)
    }
}
