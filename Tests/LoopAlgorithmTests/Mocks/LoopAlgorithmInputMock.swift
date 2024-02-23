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
    /// Mocks stable, in range glucose, no insulin, no carbs, with reasonable settings
    static func mock(for now: Date = Date()) -> AlgorithmInputFixture {

        func d(_ interval: TimeInterval) -> Date {
            return now.addingTimeInterval(interval)
        }

        return AlgorithmInputFixture(
            predictionStart: now,
            glucoseHistory: [
                FixtureGlucoseSample(startDate: d(.minutes(-19)), quantity: .glucose(value: 100)),
                FixtureGlucoseSample(startDate: d(.minutes(-14)), quantity: .glucose(value: 120)),
                FixtureGlucoseSample(startDate: d(.minutes(-9)), quantity: .glucose(value: 140)),
                FixtureGlucoseSample(startDate: d(.minutes(-4)), quantity: .glucose(value: 160)),
            ],
            doses: [],
            carbEntries: [],
            basal: [AbsoluteScheduleValue(startDate: d(.hours(-10)), endDate: now, value: 1.0)],
            sensitivity: [AbsoluteScheduleValue(startDate: d(.hours(-10)), endDate: now.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration), value: .glucose(value: 55))],
            carbRatio: [AbsoluteScheduleValue(startDate: d(.hours(-10)), endDate: now, value: 10)],
            target: [AbsoluteScheduleValue(startDate: d(.hours(-10)), endDate: now, value: ClosedRange(uncheckedBounds: (lower: .glucose(value: 100), upper: .glucose(value: 110))))],
            suspendThreshold: .glucose(value: 65),
            maxBolus: 6,
            maxBasalRate: 8,
            recommendationInsulinType: .novolog,
            recommendationType: .tempBasal
        )
    }
}

extension HKQuantity {
    static func glucose(value: Double) -> HKQuantity {
        return .init(unit: .milligramsPerDeciliter, doubleValue: value)
    }

    static func carbs(value: Double) -> HKQuantity {
        return .init(unit: .gram(), doubleValue: value)
    }

}
