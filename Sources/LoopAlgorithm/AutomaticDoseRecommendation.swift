//
//  AutomaticDoseRecommendation.swift
//  LoopAlgorithm
//
//  Created by Pete Schwamb on 1/16/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

public struct AutomaticDoseRecommendation: Equatable {
    
    public enum Direction: String, Codable {
        case decrease
        case neutral
        case increase
        
        static func from(correction: InsulinCorrection) -> Self {
            switch correction {
            case .inRange:
                return .neutral
            case .aboveRange:
                return .increase
            case .entirelyBelowRange, .suspend:
                return .decrease
            }
        }
    }
    
    public var basalAdjustment: TempBasalRecommendation
    public var bolusUnits: Double?
    public var direction: Direction

    public init(basalAdjustment: TempBasalRecommendation, direction: Direction, bolusUnits: Double? = nil) {
        self.basalAdjustment = basalAdjustment
        self.direction = direction
        self.bolusUnits = bolusUnits
    }
}

extension AutomaticDoseRecommendation: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Provide default TempBasalRecommendation if basalAdjustment is missing
        self.basalAdjustment = try container.decodeIfPresent(TempBasalRecommendation.self, forKey: .basalAdjustment) ?? TempBasalRecommendation(unitsPerHour: 0, duration: 0)
        self.bolusUnits = try container.decodeIfPresent(Double.self, forKey: .bolusUnits)
        self.direction = try container.decode(Direction.self, forKey: .direction)
    }
}
