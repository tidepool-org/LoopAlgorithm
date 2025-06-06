//
//  ManualBolusRecommendation.swift
//  LoopAlgorithm
//
//  Created by Pete Schwamb on 1/2/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation

public enum BolusRecommendationNotice: Equatable {
    case glucoseBelowSuspendThreshold(minGlucose: SimpleGlucoseValue)
    case currentGlucoseBelowTarget(glucose: SimpleGlucoseValue)
    case predictedGlucoseBelowTarget(minGlucose: SimpleGlucoseValue)
    case predictedGlucoseInRange
    case allGlucoseBelowTarget(minGlucose: SimpleGlucoseValue)
}

extension BolusRecommendationNotice: Codable {
    public init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            switch string {
            case CodableKeys.predictedGlucoseInRange.rawValue:
                self = .predictedGlucoseInRange
            default:
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        } else {
            let container = try decoder.container(keyedBy: CodableKeys.self)
            if let glucoseBelowSuspendThreshold = try container.decodeIfPresent(GlucoseBelowSuspendThreshold.self, forKey: .glucoseBelowSuspendThreshold) {
                self = .glucoseBelowSuspendThreshold(minGlucose: glucoseBelowSuspendThreshold.minGlucose)
            } else if let currentGlucoseBelowTarget = try container.decodeIfPresent(CurrentGlucoseBelowTarget.self, forKey: .currentGlucoseBelowTarget) {
                self = .currentGlucoseBelowTarget(glucose: currentGlucoseBelowTarget.glucose)
            } else if let predictedGlucoseBelowTarget = try container.decodeIfPresent(PredictedGlucoseBelowTarget.self, forKey: .predictedGlucoseBelowTarget) {
                self = .predictedGlucoseBelowTarget(minGlucose: predictedGlucoseBelowTarget.minGlucose)
            } else if let allGlucoseBelowTarget = try container.decodeIfPresent(AllGlucoseBelowTarget.self, forKey: .allGlucoseBelowTarget) {
                self = .allGlucoseBelowTarget(minGlucose: allGlucoseBelowTarget.minGlucose)
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .glucoseBelowSuspendThreshold(let minGlucose):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(GlucoseBelowSuspendThreshold(minGlucose: SimpleGlucoseValue(minGlucose)), forKey: .glucoseBelowSuspendThreshold)
        case .currentGlucoseBelowTarget(let glucose):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(CurrentGlucoseBelowTarget(glucose: SimpleGlucoseValue(glucose)), forKey: .currentGlucoseBelowTarget)
        case .predictedGlucoseBelowTarget(let minGlucose):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(PredictedGlucoseBelowTarget(minGlucose: SimpleGlucoseValue(minGlucose)), forKey: .predictedGlucoseBelowTarget)
        case .predictedGlucoseInRange:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.predictedGlucoseInRange.rawValue)
        case .allGlucoseBelowTarget(minGlucose: let minGlucose):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(AllGlucoseBelowTarget(minGlucose: SimpleGlucoseValue(minGlucose)), forKey: .allGlucoseBelowTarget)
        }
    }

    private struct GlucoseBelowSuspendThreshold: Codable {
        let minGlucose: SimpleGlucoseValue
    }

    private struct CurrentGlucoseBelowTarget: Codable {
        let glucose: SimpleGlucoseValue
    }

    private struct PredictedGlucoseBelowTarget: Codable {
        let minGlucose: SimpleGlucoseValue
    }

    private struct AllGlucoseBelowTarget: Codable {
        let minGlucose: SimpleGlucoseValue
    }

    private enum CodableKeys: String, CodingKey {
        case glucoseBelowSuspendThreshold
        case currentGlucoseBelowTarget
        case predictedGlucoseBelowTarget
        case predictedGlucoseInRange
        case allGlucoseBelowTarget
    }
}

public struct ManualBolusRecommendation {
    public var amount: Double
    public var notice: BolusRecommendationNotice?

    public init(amount: Double, notice: BolusRecommendationNotice? = nil) {
        self.amount = amount
        self.notice = notice
    }
}

extension ManualBolusRecommendation: Codable {}

extension ManualBolusRecommendation: Equatable {
    public static func ==(lhs: ManualBolusRecommendation, rhs: ManualBolusRecommendation) -> Bool {
        return lhs.amount == rhs.amount
    }
}
