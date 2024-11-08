//
//  File.swift
//  LoopAlgorithm
//
//  Created by Cameron Ingham on 11/8/24.
//

import Foundation

public struct LoopQuantity: Hashable, Equatable, Comparable, Sendable {

    public let unit: LoopUnit
    public let value: Double
    
    init(unit: LoopUnit, doubleValue value: Double) {
        self.unit = unit
        self.value = value
    }

    /**
     @method        isCompatibleWithUnit:
     @abstract      Returns yes if the receiver's value can be converted to a value of the given unit.
     */
    func `is`(compatibleWith unit: LoopUnit) -> Bool {
        self.unit.conversionFactor(from: unit) != nil
    }

    /**
     @method        doubleValueForUnit:
     @abstract      Returns the quantity value converted to the given unit.
     @discussion    Throws an exception if the receiver's value cannot be converted to one of the requested unit.
     */
    func doubleValue(for unit: LoopUnit) -> Double {
        guard let conversionFactor = self.unit.conversionFactor(from: unit) else {
            fatalError("Conversion Error: \(self.unit.unitString) is not compatible with \(unit.unitString).")
        }
        
        if self.unit == unit {
            return value
        } else {
            return value * conversionFactor
        }
    }

    /**
     @method        compare:
     @abstract      Returns an NSComparisonResult value that indicates whether the receiver is greater than, equal to, or
                    less than a given quantity.
     @discussion    Throws an exception if the unit of the given quantity is not compatible with the receiver's unit.
     */
    func compare(_ quantity: LoopQuantity) -> ComparisonResult {
        if value == quantity.value {
            return .orderedSame
        } else if value > quantity.value {
            return .orderedDescending
        } else {
            return .orderedAscending
        }
    }
    
    public static func <(lhs: LoopQuantity, rhs: LoopQuantity) -> Bool {
        return lhs.compare(rhs) == .orderedAscending
    }
}
