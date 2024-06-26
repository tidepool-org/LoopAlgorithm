//
//  ClosedRange.swift
//  LoopAlgorithm
//
//  Created by Michael Pangburn on 6/23/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
import HealthKit

extension ClosedRange where Bound == HKQuantity {
    public func averageValue(for unit: HKUnit) -> Double {
        let minValue = lowerBound.doubleValue(for: unit)
        let maxValue = upperBound.doubleValue(for: unit)
        return (maxValue + minValue) / 2
    }
}

