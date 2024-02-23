//
//  FixtureInsulinDose.swift
//  
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public struct FixtureInsulinDose: InsulinDose, Equatable {

    public var deliveryType: InsulinDeliveryType

    public var startDate: Date

    public var endDate: Date

    public var volume: Double

    public var insulinType: FixtureInsulinType?

    public var insulinModel: InsulinModel {
        insulinType?.insulinModel ?? ExponentialInsulinModelPreset.rapidActingAdult
    }

    public init(deliveryType: InsulinDeliveryType, startDate: Date, endDate: Date, volume: Double, insulinType: FixtureInsulinType? = nil) {
        self.deliveryType = deliveryType
        self.startDate = startDate
        self.endDate = endDate
        self.volume = volume
        self.insulinType = insulinType
    }
}

extension FixtureInsulinDose: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.deliveryType = try container.decode(InsulinDeliveryType.self, forKey: .type)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.endDate = try container.decode(Date.self, forKey: .endDate)
        self.volume = try container.decode(Double.self, forKey: .volume)
        self.insulinType = try container.decodeIfPresent(FixtureInsulinType.self, forKey: .insulinType)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deliveryType, forKey: .type)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(volume, forKey: .volume)
        try container.encodeIfPresent(insulinType?.rawValue, forKey: .insulinType)
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case startDate
        case endDate
        case volume
        case insulinType
    }
}
