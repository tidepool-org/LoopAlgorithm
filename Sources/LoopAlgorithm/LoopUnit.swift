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
             (.percent, .percent):
            return 1
        case (.milligramsPerDeciliterPerSecond, .milligramsPerDeciliterPerMinute):
            return 60
        case (.milligramsPerDeciliterPerMinute, .milligramsPerDeciliterPerSecond):
            return 1/60
        case (.gram, _),
             (.internationalUnit, _),
             (.milligramsPerDeciliter, _),
             (.milligramsPerDeciliterPerSecond, _),
             (.milligramsPerDeciliterPerMinute, _),
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
        case .internationalUnit:
            return "IU"
        }
    }
}
