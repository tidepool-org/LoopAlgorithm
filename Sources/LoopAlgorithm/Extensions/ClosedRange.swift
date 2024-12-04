//
//  ClosedRange.swift
//  LoopAlgorithm
//
//  Created by Michael Pangburn on 6/23/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

extension ClosedRange where Bound == LoopQuantity {
    public func averageValue(for unit: LoopUnit) -> Double {
        let minValue = lowerBound.doubleValue(for: unit)
        let maxValue = upperBound.doubleValue(for: unit)
        return (maxValue + minValue) / 2
    }
}

