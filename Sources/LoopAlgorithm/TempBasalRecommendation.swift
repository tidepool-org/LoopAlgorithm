//
//  TempBasalRecommendation.swift
//  LoopAlgorithm
//
//  Created by Darin Krauss on 5/21/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public struct TempBasalRecommendation: Equatable {
    
    public enum Direction: Codable {
        case decrease
        case neutral
        case increase
    }
    
    public var neutralUnitsPerHour: Double
    public var unitsPerHour: Double
    public let duration: TimeInterval
    
    public var direction: Direction {
        if unitsPerHour > neutralUnitsPerHour {
            return .increase
        } else if unitsPerHour < neutralUnitsPerHour {
            return .decrease
        } else {
            return .neutral
        }
    }

    public init(neutralUnitsPerHour: Double, unitsPerHour: Double, duration: TimeInterval) {
        self.neutralUnitsPerHour = neutralUnitsPerHour
        self.unitsPerHour = unitsPerHour
        self.duration = duration
    }
}

extension TempBasalRecommendation: Codable {}
