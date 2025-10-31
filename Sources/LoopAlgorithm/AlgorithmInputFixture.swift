//
//  AlgorithmInputFixture.swift
//  
//
//  Created by Pete Schwamb on 2/23/24.
//

import Foundation

public enum AlgorithmInputFixtureDecodingError: Error {
    case invalidDoseRecommendationType
    case invalidInsulinType
    case doseRateMissing
    case doseVolumeMissing
}

public struct AlgorithmInputFixture: AlgorithmInput {
    public var predictionStart: Date
    public var glucoseHistory: [FixtureGlucoseSample]
    public var doses: [FixtureInsulinDose]
    public var carbEntries: [FixtureCarbEntry]
    public var basal: [AbsoluteScheduleValue<Double>]
    public var sensitivity: [AbsoluteScheduleValue<LoopQuantity>]
    public var carbRatio: [AbsoluteScheduleValue<Double>]
    public var target: GlucoseRangeTimeline
    public var suspendThreshold: LoopQuantity?
    public var maxBolus: Double
    public var maxBasalRate: Double
    public var useIntegralRetrospectiveCorrection: Bool
    public var includePositiveVelocityAndRC: Bool
    public var useMidAbsorptionISF: Bool
    public var carbAbsorptionModel: CarbAbsorptionModel = .piecewiseLinear
    public var recommendationInsulinType: FixtureInsulinType = .novolog
    public var recommendationType: DoseRecommendationType = .automaticBolus
    public var automaticBolusApplicationFactor: Double?
    public var gradualTransitionsThreshold: Double?

    public var recommendationInsulinModel: InsulinModel {
        recommendationInsulinType.insulinModel
    }

    struct TargetEntry: Codable {
        var startDate: Date
        var endDate: Date
        var lowerBound: Double
        var upperBound: Double
    }

    struct Glucose {
        var value: Double
        var isCalibration: Bool
        var date: Date
    }

    public init(
        predictionStart: Date,
        glucoseHistory: [FixtureGlucoseSample],
        doses: [FixtureInsulinDose],
        carbEntries: [FixtureCarbEntry],
        basal: [AbsoluteScheduleValue<Double>],
        sensitivity: [AbsoluteScheduleValue<LoopQuantity>],
        carbRatio: [AbsoluteScheduleValue<Double>],
        target: GlucoseRangeTimeline,
        suspendThreshold: LoopQuantity?,
        maxBolus: Double,
        maxBasalRate: Double,
        useIntegralRetrospectiveCorrection: Bool = false,
        useMidAbsorptionISF: Bool = false,
        includePositiveVelocityAndRC: Bool = true,
        carbAbsorptionModel: CarbAbsorptionModel = .piecewiseLinear,
        recommendationInsulinType: FixtureInsulinType,
        recommendationType: DoseRecommendationType,
        automaticBolusApplicationFactor: Double? = nil,
        gradualTransitionsThreshold: Double? = 20.0
    ) {
        self.predictionStart = predictionStart
        self.glucoseHistory = glucoseHistory
        self.doses = doses
        self.carbEntries = carbEntries
        self.basal = basal
        self.sensitivity = sensitivity
        self.carbRatio = carbRatio
        self.target = target
        self.suspendThreshold = suspendThreshold
        self.maxBolus = maxBolus
        self.maxBasalRate = maxBasalRate
        self.useIntegralRetrospectiveCorrection = useIntegralRetrospectiveCorrection
        self.includePositiveVelocityAndRC = includePositiveVelocityAndRC
        self.useMidAbsorptionISF = useMidAbsorptionISF
        self.carbAbsorptionModel = carbAbsorptionModel
        self.recommendationInsulinType = recommendationInsulinType
        self.recommendationType = recommendationType
        self.automaticBolusApplicationFactor = automaticBolusApplicationFactor
        self.gradualTransitionsThreshold = gradualTransitionsThreshold
    }
}


extension AlgorithmInputFixture: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.predictionStart = try container.decode(Date.self, forKey: .predictionStart)
        self.glucoseHistory = try container.decode([FixtureGlucoseSample].self, forKey: .glucoseHistory)
        self.doses = try container.decode([FixtureInsulinDose].self, forKey: .doses)
        self.carbEntries = try container.decode([FixtureCarbEntry].self, forKey: .carbEntries)
        self.basal = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .basal)
        let sensitivityMgdl = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .sensitivity)
        self.sensitivity = sensitivityMgdl.map { AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.value))}
        self.carbRatio = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .carbRatio)
        let targetMgdl = try container.decode([TargetEntry].self, forKey: .target)
        self.target = targetMgdl.map {
            let lower = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.lowerBound)
            let upper = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.upperBound)
            let range = ClosedRange(uncheckedBounds: (lower: lower, upper: upper))
            return AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: range)
        }
        if let suspendThresholdMgdl = try container.decodeIfPresent(Double.self, forKey: .suspendThreshold) {
            self.suspendThreshold = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: suspendThresholdMgdl)
        }
        self.maxBolus = try container.decode(Double.self, forKey: .maxBolus)
        self.maxBasalRate = try container.decode(Double.self, forKey: .maxBasalRate)
        self.useIntegralRetrospectiveCorrection = try container.decodeIfPresent(Bool.self, forKey: .useIntegralRetrospectiveCorrection) ?? false
        self.includePositiveVelocityAndRC = try container.decodeIfPresent(Bool.self, forKey: .includePositiveVelocityAndRC) ?? true
        self.useMidAbsorptionISF = try container.decodeIfPresent(Bool.self, forKey: .useMidAbsorptionISF) ?? false

        if let rawRecommendationInsulinType = try container.decodeIfPresent(String.self, forKey: .recommendationInsulinType) {
            guard let decodedRecommendationInsulinType = FixtureInsulinType(rawValue: rawRecommendationInsulinType) else {
                throw AlgorithmInputFixtureDecodingError.invalidInsulinType
            }
            self.recommendationInsulinType = decodedRecommendationInsulinType
        } else {
            self.recommendationInsulinType = .novolog
        }

        if let rawRecommendationType = try container.decodeIfPresent(String.self, forKey: .recommendationType) {
            guard let decodedRecommendationType = DoseRecommendationType(rawValue: rawRecommendationType) else {
                throw AlgorithmInputFixtureDecodingError.invalidDoseRecommendationType
            }
            self.recommendationType = decodedRecommendationType
        } else {
            self.recommendationType = .automaticBolus
        }

        self.automaticBolusApplicationFactor = try container.decodeIfPresent(Double.self, forKey: .automaticBolusApplicationFactor)
        self.gradualTransitionsThreshold = try container.decodeIfPresent(Double.self, forKey: .gradualTransitionsThreshold) ?? 20.0

    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(predictionStart, forKey: .predictionStart)
        try container.encode(glucoseHistory, forKey: .glucoseHistory)
        try container.encode(glucoseHistory, forKey: .glucoseHistory)
        try container.encode(doses, forKey: .doses)
        try container.encode(carbEntries, forKey: .carbEntries)
        try container.encode(basal, forKey: .basal)
        let sensitivityMgdl = sensitivity.map { AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: $0.value.doubleValue(for: .milligramsPerDeciliter)) }
        try container.encode(sensitivityMgdl, forKey: .sensitivity)
        try container.encode(carbRatio, forKey: .carbRatio)
        let targetMgdl = target.map {
            let lower = $0.value.lowerBound.doubleValue(for: .milligramsPerDeciliter)
            let upper = $0.value.upperBound.doubleValue(for: .milligramsPerDeciliter)
            return TargetEntry(startDate: $0.startDate, endDate: $0.endDate, lowerBound: lower, upperBound: upper)
        }
        try container.encode(targetMgdl, forKey: .target)
        try container.encode(suspendThreshold?.doubleValue(for: .milligramsPerDeciliter), forKey: .suspendThreshold)
        try container.encode(maxBolus, forKey: .maxBolus)
        try container.encode(maxBasalRate, forKey: .maxBasalRate)
        if useIntegralRetrospectiveCorrection {
            try container.encode(useIntegralRetrospectiveCorrection, forKey: .useIntegralRetrospectiveCorrection)
        }
        if !includePositiveVelocityAndRC {
            try container.encode(includePositiveVelocityAndRC, forKey: .includePositiveVelocityAndRC)
        }
        try container.encode(useMidAbsorptionISF, forKey: .useMidAbsorptionISF)
        try container.encode(recommendationInsulinType.rawValue, forKey: .recommendationInsulinType)
        try container.encode(recommendationType.rawValue, forKey: .recommendationType)
        try container.encode(automaticBolusApplicationFactor, forKey: .automaticBolusApplicationFactor)
        try container.encode(gradualTransitionsThreshold, forKey: .gradualTransitionsThreshold)
    }

    private enum CodingKeys: String, CodingKey {
        case predictionStart
        case glucoseHistory
        case doses
        case carbEntries
        case basal
        case sensitivity
        case carbRatio
        case target
        case suspendThreshold
        case maxBolus
        case maxBasalRate
        case useIntegralRetrospectiveCorrection
        case includePositiveVelocityAndRC
        case useMidAbsorptionISF
        case recommendationInsulinType
        case recommendationType
        case automaticBolusApplicationFactor
        case gradualTransitionsThreshold
    }
}

extension AlgorithmInputFixture {
    static public func printFixture(_ input: any AlgorithmInput) {
        let fixture = AlgorithmInputFixture(
            predictionStart: input.predictionStart,
            glucoseHistory: input.glucoseHistory.map(\.asFixtureGlucoseSample),
            doses: input.doses.map(\.asFixtureInsulinDose),
            carbEntries: input.carbEntries.map(\.asFixtureCarbEntry),
            basal: input.basal,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            target: input.target,
            suspendThreshold: input.suspendThreshold,
            maxBolus: input.maxBolus,
            maxBasalRate: input.maxBasalRate,
            useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection,
            useMidAbsorptionISF: input.useMidAbsorptionISF,
            includePositiveVelocityAndRC: input.includePositiveVelocityAndRC,
            carbAbsorptionModel: input.carbAbsorptionModel,
            recommendationInsulinType: .novolog,
            recommendationType: input.recommendationType,
            automaticBolusApplicationFactor: input.automaticBolusApplicationFactor,
            gradualTransitionsThreshold: input.gradualTransitionsThreshold
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let encoded = try encoder.encode(fixture)
            print(String(data: encoded , encoding: .utf8)!)
        } catch {
            print("Error encoding fixture: \(error)")
        }
    }
}

extension GlucoseSampleValue {
    var asFixtureGlucoseSample: FixtureGlucoseSample {
        return .init(startDate: startDate, quantity: quantity)
    }
}

extension InsulinDose {
    var asFixtureInsulinDose: FixtureInsulinDose {
        return .init(deliveryType: deliveryType, startDate: startDate, endDate: endDate, volume: volume)
    }
}

extension CarbEntry {
    var asFixtureCarbEntry: FixtureCarbEntry {
        return FixtureCarbEntry(
            absorptionTime: absorptionTime,
            startDate: startDate,
            quantity: quantity,
            foodType: nil
        )
    }
}
