//
//  File.swift
//  LoopAlgorithm
//
//  Created by Cameron Ingham on 11/8/24.
//

import Foundation

private let UnitMolarMassBloodGlucose = 180.1558800000541

public enum LoopUnit: Sendable, CaseIterable {
    case gram
    case gramsPerUnit
    case internationalUnit
    case internationalUnitsPerHour
    case milligramsPerDeciliter
    case milligramsPerDeciliterPerSecond
    case milligramsPerDeciliterPerMinute
    case milligramsPerDeciliterPerInternationalUnit
    case millimolesPerLiter
    case millimolesPerLiterPerSecond
    case millimolesPerLiterPerMinute
    case millimolesPerLiterPerInternationalUnit
    case percent
    case hour
    case minute
    case second
    
    public init(from string: String) {
        self = LoopUnit.allCases.first(where: { $0.unitString == string }) ?? .gram
    }
    
    public func conversionFactor(from unit: LoopUnit) -> Double? {
        switch (self, unit) {
        case (.gram, .gram),
             (.gramsPerUnit, .gramsPerUnit),
             (.internationalUnit, .internationalUnit),
             (.internationalUnitsPerHour, .internationalUnitsPerHour),
             (.milligramsPerDeciliter, .milligramsPerDeciliter),
             (.milligramsPerDeciliterPerSecond, .milligramsPerDeciliterPerSecond),
             (.milligramsPerDeciliterPerMinute, .milligramsPerDeciliterPerMinute),
             (.milligramsPerDeciliterPerInternationalUnit, .milligramsPerDeciliterPerInternationalUnit),
             (.millimolesPerLiter, .millimolesPerLiter),
             (.millimolesPerLiterPerSecond, .millimolesPerLiterPerSecond),
             (.millimolesPerLiterPerMinute, .millimolesPerLiterPerMinute),
             (.millimolesPerLiterPerInternationalUnit, .millimolesPerLiterPerInternationalUnit),
             (.percent, .percent),
             (.hour, .hour),
             (.minute, .minute),
             (.second, .second):
            return 1
        case (.milligramsPerDeciliterPerSecond, .milligramsPerDeciliterPerMinute),
             (.millimolesPerLiterPerSecond, .millimolesPerLiterPerMinute),
             (.second, .minute),
             (.minute, .hour):
            return 60
        case (.milligramsPerDeciliterPerMinute, .milligramsPerDeciliterPerSecond),
             (.millimolesPerLiterPerMinute, .millimolesPerLiterPerSecond),
             (.minute, .second),
             (.hour, .minute):
            return 1/60
        case (.second, .hour):
            return 3600
        case (.hour, .second):
            return 1/3600
        case (.milligramsPerDeciliter, .millimolesPerLiter),
             (.milligramsPerDeciliterPerSecond, .millimolesPerLiterPerSecond),
             (.milligramsPerDeciliterPerMinute, .millimolesPerLiterPerMinute),
             (.milligramsPerDeciliterPerInternationalUnit, .millimolesPerLiterPerInternationalUnit):
            return 1/18
        case (.millimolesPerLiter, .milligramsPerDeciliter),
             (.millimolesPerLiterPerSecond, .milligramsPerDeciliterPerSecond),
             (.millimolesPerLiterPerMinute, .milligramsPerDeciliterPerMinute),
             (.millimolesPerLiterPerInternationalUnit, .milligramsPerDeciliterPerInternationalUnit):
            return 1/18 * 60
        case (.milligramsPerDeciliterPerMinute, .millimolesPerLiterPerSecond),
             (.millimolesPerLiterPerMinute, .milligramsPerDeciliterPerSecond):
            return 1/18 / 60
        case (.millimolesPerLiterPerSecond, .milligramsPerDeciliterPerMinute),
             (.milligramsPerDeciliterPerSecond, .millimolesPerLiterPerMinute):
            return 18
        case (.gram, _),
             (.gramsPerUnit, _),
             (.internationalUnit, _),
             (.internationalUnitsPerHour, _),
             (.milligramsPerDeciliter, _),
             (.milligramsPerDeciliterPerSecond, _),
             (.milligramsPerDeciliterPerMinute, _),
             (.milligramsPerDeciliterPerInternationalUnit, _),
             (.millimolesPerLiter, _),
             (.millimolesPerLiterPerSecond, _),
             (.millimolesPerLiterPerMinute, _),
             (.millimolesPerLiterPerInternationalUnit, _),
             (.percent, _),
             (.hour, _),
             (.minute, _),
             (.second, _):
            return nil
        default:
            fatalError()
        }
    }
    
    public var unitString: String {
        switch self {
        case .gram:
            return "g"
        case .gramsPerUnit:
            return "g/IU"
        case .percent:
            return "%"
        case .milligramsPerDeciliter:
            return "mg/dL"
        case .milligramsPerDeciliterPerSecond:
            return "mg/dL·s"
        case .milligramsPerDeciliterPerMinute:
            return "mg/min·dL"
        case .milligramsPerDeciliterPerInternationalUnit:
            return "mg/dL·IU"
        case .millimolesPerLiter:
            return "mmol<\(UnitMolarMassBloodGlucose)>/L"
        case .millimolesPerLiterPerSecond:
            return "mmol<\(UnitMolarMassBloodGlucose)>/L·s"
        case .millimolesPerLiterPerMinute:
            return "mmol<\(UnitMolarMassBloodGlucose)>/min·L"
        case .millimolesPerLiterPerInternationalUnit:
            return "mmol<\(UnitMolarMassBloodGlucose)>/L·IU"
        case .internationalUnit:
            return "IU"
        case .internationalUnitsPerHour:
            return "IU/hr"
        case .hour:
            return "hr"
        case .minute:
            return "min"
        case .second:
            return "s"
        }
    }
}
