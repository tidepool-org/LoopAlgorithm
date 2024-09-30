//
//  GlucoseEffectVelocity.swift
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit


/// The first-derivative of GlucoseEffect, blood glucose over time.
public struct GlucoseEffectVelocity: SampleValue {
    public let startDate: Date
    public let endDate: Date
    public let quantity: HKQuantity

    public init(startDate: Date, endDate: Date, quantity: HKQuantity) {
        self.startDate = startDate
        self.endDate = endDate
        self.quantity = quantity
    }
}


extension GlucoseEffectVelocity {
    public static let perSecondUnit = HKUnit.milligramsPerDeciliter.unitDivided(by: .second())

    /// The integration of the velocity span
    public var effect: GlucoseEffect {
        let duration = endDate.timeIntervalSince(startDate)
        let velocityPerSecond = quantity.doubleValue(for: GlucoseEffectVelocity.perSecondUnit)

        return GlucoseEffect(
            startDate: endDate,
            quantity: HKQuantity(
                unit: .milligramsPerDeciliter,
                doubleValue: velocityPerSecond * duration
            )
        )
    }
}

extension GlucoseEffectVelocity: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.endDate = try container.decode(Date.self, forKey: .endDate)
        self.quantity = HKQuantity(
            unit: GlucoseEffectVelocity.perSecondUnit,
            doubleValue: try container.decode(Double.self, forKey: .mgdlPerSecond)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(quantity.doubleValue(for: GlucoseEffectVelocity.perSecondUnit), forKey: .mgdlPerSecond)
    }

    private enum CodingKeys: String, CodingKey {
        case startDate
        case endDate
        case mgdlPerSecond
    }
}
