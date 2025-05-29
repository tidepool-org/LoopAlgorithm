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
        
        static func from(correction: InsulinCorrection) -> Self? {
            switch correction {
            case .inRange:
                return .neutral
            case .aboveRange:
                return .increase
            case .entirelyBelowRange:
                return .decrease
            case .suspend:
                return nil
            }
        }
    }
    
    public var basalAdjustment: TempBasalRecommendation
    public var bolusUnits: Double?
    public var direction: Direction?

    public init(basalAdjustment: TempBasalRecommendation, direction: Direction?, bolusUnits: Double? = nil) {
        self.basalAdjustment = basalAdjustment
        self.direction = direction
        self.bolusUnits = bolusUnits
    }
}

extension AutomaticDoseRecommendation: Codable {}
