//
//  AlgorithmOutput.swift
//
//
//  Created by Pete Schwamb on 10/13/23.
//

import Foundation
import HealthKit

public struct AlgorithmOutput<CarbEntryType: CarbEntry> {
    public var recommendationResult: Result<LoopAlgorithmDoseRecommendation,Error>
    public var predictedGlucose: [PredictedGlucoseValue]
    public var effects: LoopAlgorithmEffects<CarbEntryType>
    public var dosesRelativeToBasal: [BasalRelativeDose]
    public var activeInsulin: Double?
    public var activeCarbs: Double?

    public init(
        recommendationResult: Result<LoopAlgorithmDoseRecommendation, Error>,
        predictedGlucose: [PredictedGlucoseValue],
        effects: LoopAlgorithmEffects<CarbEntryType>,
        dosesRelativeToBasal: [BasalRelativeDose],
        activeInsulin: Double? = nil,
        activeCarbs: Double? = nil
    ) {
        self.recommendationResult = recommendationResult
        self.predictedGlucose = predictedGlucose
        self.effects = effects
        self.dosesRelativeToBasal = dosesRelativeToBasal
        self.activeInsulin = activeInsulin
        self.activeCarbs = activeCarbs
    }

    public var recommendation: LoopAlgorithmDoseRecommendation? {
        switch recommendationResult {
        case .success(let rec):
            return rec
        case .failure:
            return nil
        }
    }
}


public typealias LoopAlgorithmOutputFixture = AlgorithmOutput<FixtureCarbEntry>


extension LoopAlgorithmOutputFixture: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch recommendationResult {
        case .success(let recommendation):
            try container.encode(recommendation, forKey: .recommendation)
        case .failure(let error):
            try container.encode(String(describing: error), forKey: .error)
        }
        try container.encode(predictedGlucose, forKey: .predictedGlucose)
        try container.encode(effects, forKey: .effects)
        try container.encode(dosesRelativeToBasal, forKey: .dosesRelativeToBasal)
        try container.encode(activeInsulin, forKey: .activeInsulin)
        try container.encode(activeCarbs, forKey: .activeCarbs)
    }

    private enum CodingKeys: String, CodingKey {
        case recommendation
        case error
        case predictedGlucose
        case effects
        case dosesRelativeToBasal
        case activeInsulin
        case activeCarbs
    }

}
