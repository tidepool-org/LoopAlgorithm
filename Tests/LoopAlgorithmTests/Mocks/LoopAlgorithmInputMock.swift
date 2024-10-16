//
//  AlgorithmInputFixture.swift
//
//
//  Created by Pete Schwamb on 1/2/24.
//

import Foundation
import HealthKit
@testable import LoopAlgorithm

extension AlgorithmInputFixture {
    /// Mocks rising glucose, no insulin, no carbs, with reasonable settings
    static func mock(for now: Date = Date()) -> AlgorithmInputFixture {

        func d(_ interval: TimeInterval) -> Date {
            return now.addingTimeInterval(interval)
        }

        let forecastEnd = now.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration).dateCeiledToTimeInterval(GlucoseMath.defaultDelta)

        return AlgorithmInputFixture(
            predictionStart: now,
            glucoseHistory: [
                FixtureGlucoseSample(startDate: d(.minutes(-19)), quantity: .glucose(100)),
                FixtureGlucoseSample(startDate: d(.minutes(-14)), quantity: .glucose(120)),
                FixtureGlucoseSample(startDate: d(.minutes(-9)), quantity: .glucose(140)),
                FixtureGlucoseSample(startDate: d(.minutes(-4)), quantity: .glucose(160)),
            ],
            doses: [],
            carbEntries: [],
            basal: [AbsoluteScheduleValue(startDate: d(.hours(-10)), endDate: now, value: 1.0)],
            sensitivity: [AbsoluteScheduleValue(startDate: d(.hours(-10)), endDate: forecastEnd, value: .glucose(55))],
            carbRatio: [AbsoluteScheduleValue(startDate: d(.hours(-10)), endDate: now, value: 10)],
            target: [AbsoluteScheduleValue(startDate: d(.hours(-10)), endDate: now, value: ClosedRange(uncheckedBounds: (lower: .glucose(100), upper: .glucose(110))))],
            suspendThreshold: .glucose(65),
            maxBolus: 6,
            maxBasalRate: 8,
            recommendationInsulinType: .novolog,
            recommendationType: .tempBasal
        )
    }
}

extension HKQuantity {
    static func glucose(_ mgdl: Double) -> HKQuantity {
        return .init(unit: .milligramsPerDeciliter, doubleValue: mgdl)
    }

    static func carbs(_ grams: Double) -> HKQuantity {
        return .init(unit: .gram(), doubleValue: grams)
    }

}
