//
//  AbsorbedCarbValue.swift
//  LoopAlgorithm
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit


/// A quantity of carbs absorbed over a given date interval
public struct AbsorbedCarbValue: SampleValue {
    /// The quantity of carbs absorbed
    public let observed: HKQuantity
    /// The quantity of carbs absorbed, clamped to the original prediction
    public let clamped: HKQuantity
    /// The quantity of carbs entered as eaten
    public let total: HKQuantity
    /// The quantity of carbs expected to still absorb
    public let remaining: HKQuantity
    /// The dates over which absorption was observed
    public let observedDate: DateInterval

    /// The predicted time for the remaining carbs to absorb
    public let estimatedTimeRemaining: TimeInterval

    // Total predicted absorption time for this carb entry
    public var estimatedDate: DateInterval {
        return DateInterval(start: observedDate.start, duration: observedDate.duration + estimatedTimeRemaining)
    }

    /// The amount of time required to absorb observed carbs
    public let timeToAbsorbObservedCarbs: TimeInterval

    /// Whether absorption is still in-progress
    public var isActive: Bool {
        return estimatedTimeRemaining > 0
    }

    public var observedProgress: HKQuantity {
        let gram = HKUnit.gram()
        let totalGrams = total.doubleValue(for: gram)
        let percent = HKUnit.percent()

        guard totalGrams > 0 else {
            return HKQuantity(unit: percent, doubleValue: 0)
        }

        return HKQuantity(
            unit: percent,
            doubleValue: observed.doubleValue(for: gram) / totalGrams
        )
    }

    // MARK: SampleValue

    public var quantity: HKQuantity {
        return clamped
    }

    public var startDate: Date {
        return estimatedDate.start
    }
}

extension AbsorbedCarbValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.observed = HKQuantity(
            unit: .gram(),
            doubleValue: try container.decode(Double.self, forKey: .observed)
        )
        self.clamped = HKQuantity(
            unit: .gram(),
            doubleValue: try container.decode(Double.self, forKey: .clamped)
        )
        self.total = HKQuantity(
            unit: .gram(),
            doubleValue: try container.decode(Double.self, forKey: .total)
        )
        self.remaining = HKQuantity(
            unit: .gram(),
            doubleValue: try container.decode(Double.self, forKey: .remaining)
        )

        let observedDateStart = try container.decode(Date.self, forKey: .observedDateStart)
        let observedDateDuration = try container.decode(Double.self, forKey: .observedDateDuration)
        self.observedDate = DateInterval(start: observedDateStart, duration: observedDateDuration)

        self.estimatedTimeRemaining = try container.decode(Double.self, forKey: .estimatedTimeRemaining)
        self.timeToAbsorbObservedCarbs = try container.decode(Double.self, forKey: .timeToAbsorbObservedCarbs)

    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(observed.doubleValue(for: .gram()), forKey: .observed)
        try container.encode(clamped.doubleValue(for: .gram()), forKey: .observed)
        try container.encode(total.doubleValue(for: .gram()), forKey: .observed)
        try container.encode(remaining.doubleValue(for: .gram()), forKey: .observed)

        try container.encode(observedDate.start, forKey: .observedDateStart)
        try container.encode(observedDate.duration, forKey: .observedDateDuration)

        try container.encode(estimatedTimeRemaining, forKey: .estimatedTimeRemaining)
        try container.encode(timeToAbsorbObservedCarbs, forKey: .timeToAbsorbObservedCarbs)
    }

    private enum CodingKeys: String, CodingKey {
        case observed
        case clamped
        case total
        case remaining
        case observedDateStart
        case observedDateDuration
        case estimatedTimeRemaining
        case timeToAbsorbObservedCarbs
    }
}
