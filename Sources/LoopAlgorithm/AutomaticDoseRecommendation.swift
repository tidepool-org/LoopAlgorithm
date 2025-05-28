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
        
        static func from(neutral: Double, temp: Double) -> Self {
            if temp > neutral {
                return .increase
            } else if temp < neutral {
                return .decrease
            } else {
                return .neutral
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

extension AutomaticDoseRecommendation: Codable {}
