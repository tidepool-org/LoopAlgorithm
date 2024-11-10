//
//  File.swift
//  LoopAlgorithm
//
//  Created by Cameron Ingham on 11/8/24.
//

import Foundation

public enum LoopUnit: Sendable, CaseIterable {
    case gram
    case internationalUnit
    case milligramsPerDeciliter
    case milligramsPerDeciliterPerSecond
    case milligramsPerDeciliterPerMinute
    case millimolesPerLiter
    case millimolesPerLiterPerSecond
    case millimolesPerLiterPerMinute
    case percent
    
    public init(from string: String) {
        self = LoopUnit.allCases.first(where: { $0.unitString == string }) ?? .gram
    }
    
    public func conversionFactor(from unit: LoopUnit) -> Double? {
        switch (self, unit) {
        case (.gram, .gram),
             (.internationalUnit, .internationalUnit),
             (.milligramsPerDeciliter, .milligramsPerDeciliter),
             (.milligramsPerDeciliterPerSecond, .milligramsPerDeciliterPerSecond),
             (.milligramsPerDeciliterPerMinute, .milligramsPerDeciliterPerMinute),
             (.millimolesPerLiter, .millimolesPerLiter),
             (.millimolesPerLiterPerSecond, .millimolesPerLiterPerSecond),
             (.millimolesPerLiterPerMinute, .millimolesPerLiterPerMinute),
             (.percent, .percent):
            return 1
        case (.milligramsPerDeciliterPerSecond, .milligramsPerDeciliterPerMinute),
             (.millimolesPerLiterPerSecond, .millimolesPerLiterPerMinute):
            return 60
        case (.milligramsPerDeciliterPerMinute, .milligramsPerDeciliterPerSecond),
             (.millimolesPerLiterPerMinute, .millimolesPerLiterPerSecond):
            return 1/60
        case (.milligramsPerDeciliterPerSecond, .millimolesPerLiterPerSecond):
            return 0.0555
        case (.milligramsPerDeciliterPerSecond, .millimolesPerLiterPerMinute):
            return 0.0555 * 60
        case (.milligramsPerDeciliterPerMinute, .millimolesPerLiterPerSecond):
            return 0.0555 / 60
        case (.milligramsPerDeciliterPerMinute, .millimolesPerLiterPerMinute):
            return 0.0555
        case (.millimolesPerLiterPerSecond, .milligramsPerDeciliterPerSecond):
            return 18.018
        case (.millimolesPerLiterPerSecond, .milligramsPerDeciliterPerMinute):
            return 18.018 * 60
        case (.millimolesPerLiterPerMinute, .milligramsPerDeciliterPerSecond):
            return 18.018 / 60
        case (.millimolesPerLiterPerMinute, .milligramsPerDeciliterPerMinute):
            return 18.018
        case (.gram, _),
             (.internationalUnit, _),
             (.milligramsPerDeciliter, _),
             (.milligramsPerDeciliterPerSecond, _),
             (.milligramsPerDeciliterPerMinute, _),
             (.millimolesPerLiter, _),
             (.millimolesPerLiterPerSecond, _),
             (.millimolesPerLiterPerMinute, _),
             (.percent, _):
            return nil
        }
    }
    
    public var unitString: String {
        switch self {
        case .gram:
            return "g"
        case .percent:
            return "%"
        case .milligramsPerDeciliter:
            return "mg/dL"
        case .milligramsPerDeciliterPerSecond:
            return "mg/dL·s"
        case .milligramsPerDeciliterPerMinute:
            return "mg/min·dL"
        case .millimolesPerLiter:
            return "mmol/L"
        case .millimolesPerLiterPerSecond:
            return "mmol/L·s"
        case .millimolesPerLiterPerMinute:
            return "mmol/min·L"
        case .internationalUnit:
            return "IU"
        }
    }
}
