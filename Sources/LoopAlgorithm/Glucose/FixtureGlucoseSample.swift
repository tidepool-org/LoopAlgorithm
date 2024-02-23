//
//  FixtureGlucoseSample.swift
//  LoopAlgorithm
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit

public struct FixtureGlucoseSample: GlucoseSampleValue, Equatable {
    public static let defaultProvenanceIdentifier = "com.LoopKit.Loop"

    public let provenanceIdentifier: String
    public let startDate: Date
    public let quantity: HKQuantity
    public let isDisplayOnly: Bool
    public let wasUserEntered: Bool
    public var condition: GlucoseCondition?
    public var trendRate: HKQuantity?

    public init(
        provenanceIdentifier: String = Self.defaultProvenanceIdentifier,
        startDate: Date,
        quantity: HKQuantity,
        isDisplayOnly: Bool = false,
        wasUserEntered: Bool = false
    ) {
        self.provenanceIdentifier = provenanceIdentifier
        self.startDate = startDate
        self.quantity = quantity
        self.isDisplayOnly = isDisplayOnly
        self.wasUserEntered = wasUserEntered
    }
}

extension FixtureGlucoseSample: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let provenanceIdentifier = try container.decodeIfPresent(String.self, forKey: .provenanceIdentifier) ?? Self.defaultProvenanceIdentifier
        let isDisplayOnly = try container.decodeIfPresent(Bool.self, forKey: .isDisplayOnly) ?? false
        let wasUserEntered = try container.decodeIfPresent(Bool.self, forKey: .wasUserEntered) ?? false

        self.init(provenanceIdentifier: provenanceIdentifier,
                  startDate: try container.decode(Date.self, forKey: .date),
                  quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: try container.decode(Double.self, forKey: .value)),
                  isDisplayOnly: isDisplayOnly,
                  wasUserEntered: wasUserEntered
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if provenanceIdentifier != Self.defaultProvenanceIdentifier {
            try container.encode(provenanceIdentifier, forKey: .provenanceIdentifier)
        }
        try container.encode(startDate, forKey: .date)
        try container.encode(quantity.doubleValue(for: .milligramsPerDeciliter), forKey: .value)
        if isDisplayOnly {
            try container.encode(isDisplayOnly, forKey: .isDisplayOnly)
        }
        if wasUserEntered {
            try container.encode(wasUserEntered, forKey: .wasUserEntered)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case provenanceIdentifier
        case date
        case value
        case isDisplayOnly
        case wasUserEntered
    }
}
