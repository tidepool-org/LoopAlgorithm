//
//  BasalRelativeDose.swift
//  
//
//  Created by Pete Schwamb on 12/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public enum BasalRelativeDoseType: Equatable {
    case bolus
    case basal(scheduledRate: Double)
}

public struct BasalRelativeDose: TimelineValue {
    public var type: BasalRelativeDoseType
    public var startDate: Date
    public var endDate: Date
    public var volume: Double
    public var insulinModel: InsulinModel

    public var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }

    public init(type: BasalRelativeDoseType, startDate: Date, endDate: Date, volume: Double, insulinModel: InsulinModel = ExponentialInsulinModelPreset.rapidActingAdult) {
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.volume = volume
        self.insulinModel = insulinModel
    }
}

extension BasalRelativeDose {
    /// The number of units delivered, net the basal rate scheduled during that time, which can be used to compute insulin on-board and glucose effects
    public var netBasalUnits: Double {

        if case .basal(let scheduledRate) = type {
            guard duration.hours > 0 else {
                return 0
            }
            let scheduledUnits = scheduledRate * duration.hours
            return volume - scheduledUnits
        } else {
            return volume
        }
    }
}

extension BasalRelativeDose {
    static func fromBolus(dose: InsulinDose) -> BasalRelativeDose {
        precondition(dose.deliveryType == .bolus, "Dose passed to fromBolus() must be a bolus.")
        
        return BasalRelativeDose(
            type: .bolus,
            startDate: dose.startDate,
            endDate: dose.endDate,
            volume: dose.volume,
            insulinModel: dose.insulinModel
        )
    }
}

extension BasalRelativeDoseType: Codable {}

extension BasalRelativeDose: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(BasalRelativeDoseType.self, forKey: .type)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.endDate = try container.decode(Date.self, forKey: .endDate)
        self.volume = try container.decode(Double.self, forKey: .volume)
        // Not encoded atm. Could at some point define some "fixture" models"
        self.insulinModel = ExponentialInsulinModelPreset.rapidActingAdult.model
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(volume, forKey: .volume)
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case startDate
        case endDate
        case volume
    }

}

