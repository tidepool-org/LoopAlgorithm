//
//  AbsorbedCarbValue.swift
//  LoopAlgorithm
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation


/// A quantity of carbs absorbed over a given date interval
public struct AbsorbedCarbValue: SampleValue {
    /// The quantity of carbs absorbed
    public let observed: LoopQuantity
    /// The quantity of carbs absorbed, clamped to the original prediction
    public let clamped: LoopQuantity
    /// The quantity of carbs entered as eaten
    public let total: LoopQuantity
    /// The quantity of carbs expected to still absorb
    public let remaining: LoopQuantity
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

    public var observedProgress: LoopQuantity {
        let gram = LoopUnit.gram
        let totalGrams = total.doubleValue(for: gram)
        let percent = LoopUnit.percent

        guard totalGrams > 0 else {
            return LoopQuantity(unit: percent, doubleValue: 0)
        }

        return LoopQuantity(
            unit: percent,
            doubleValue: observed.doubleValue(for: gram) / totalGrams
        )
    }

    // MARK: SampleValue

    public var quantity: LoopQuantity {
        return clamped
    }

    public var startDate: Date {
        return estimatedDate.start
    }
}

extension AbsorbedCarbValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.observed = LoopQuantity(
            unit: .gram,
            doubleValue: try container.decode(Double.self, forKey: .observed)
        )
        self.clamped = LoopQuantity(
            unit: .gram,
            doubleValue: try container.decode(Double.self, forKey: .clamped)
        )
        self.total = LoopQuantity(
            unit: .gram,
            doubleValue: try container.decode(Double.self, forKey: .total)
        )
        self.remaining = LoopQuantity(
            unit: .gram,
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
        try container.encode(observed.doubleValue(for: .gram), forKey: .observed)
        try container.encode(clamped.doubleValue(for: .gram), forKey: .observed)
        try container.encode(total.doubleValue(for: .gram), forKey: .observed)
        try container.encode(remaining.doubleValue(for: .gram), forKey: .observed)

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
