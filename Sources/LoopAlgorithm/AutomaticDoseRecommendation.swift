//
//  AutomaticDoseRecommendation.swift
//  LoopAlgorithm
//
//  Created by Pete Schwamb on 1/16/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

public struct AutomaticDoseRecommendation: Equatable {
    public var basalAdjustment: TempBasalRecommendation?
    public var bolusUnits: Double?

    public init(basalAdjustment: TempBasalRecommendation?, bolusUnits: Double? = nil) {
        self.basalAdjustment = basalAdjustment
        self.bolusUnits = bolusUnits
    }
}

extension AutomaticDoseRecommendation: Codable {}
