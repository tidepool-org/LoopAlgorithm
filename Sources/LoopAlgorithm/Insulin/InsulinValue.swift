//
//  InsulinValue.swift
//  LoopAlgorithm
//
//  Created by Nathan Racklyeft on 4/3/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit

public struct InsulinValue: TimelineValue, Equatable {
    public let startDate: Date
    public let value: Double

    public init(startDate: Date, value: Double) {
        self.startDate = startDate
        self.value = value
    }

    public var quantity: HKQuantity {
        HKQuantity(unit: .internationalUnit(), doubleValue: value)
    }
}

extension InsulinValue: Codable {}
