//
//  AlgorithmInput.swift
//  Learn
//
//  Created by Pete Schwamb on 7/29/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public struct LoopPredictionInput<CarbType: CarbEntry, GlucoseType: GlucoseSampleValue, InsulinDoseType: InsulinDose> {
    // Algorithm input time range: t-10h to t
    public var glucoseHistory: [GlucoseType]

    // Algorithm input time range: t-16h to t
    public var doses: [InsulinDoseType]

    // Algorithm input time range: t-10h to t
    public var carbEntries: [CarbType]

    // Expected time range coverage: t-16h to t
    public var basal: [AbsoluteScheduleValue<Double>]

    // Expected time range coverage: t-16h to t (eventually with mid-absorption isf changes, it will be t-10h to t)
    public var sensitivity: [AbsoluteScheduleValue<LoopQuantity>]

    // Expected time range coverage: t-10h to t+6h
    public var carbRatio: [AbsoluteScheduleValue<Double>]

    // Correction-range timeline. Used only for the IntegralRC integral-correction
    // clamp when `emulation.integralRCClamp` is enabled; may be empty otherwise.
    public var target: GlucoseRangeTimeline = []

    public var algorithmEffectsOptions: AlgorithmEffectsOptions

    public var useIntegralRetrospectiveCorrection: Bool = false
    
    public var includePositiveVelocityAndRC: Bool = true

    public var carbAbsorptionModel: CarbAbsorptionModel = .piecewiseLinear
    
    public var gradualTransitionsThreshold: Double? = 40.0

    public var emulation: AlgorithmEmulationOptions? = nil

    public init(
        glucoseHistory: [GlucoseType],
        doses: [InsulinDoseType],
        carbEntries: [CarbType],
        basal: [AbsoluteScheduleValue<Double>],
        sensitivity: [AbsoluteScheduleValue<LoopQuantity>],
        carbRatio: [AbsoluteScheduleValue<Double>],
        target: GlucoseRangeTimeline = [],
        algorithmEffectsOptions: AlgorithmEffectsOptions,
        useIntegralRetrospectiveCorrection: Bool,
        includePositiveVelocityAndRC: Bool,
        carbAbsorptionModel: CarbAbsorptionModel,
        gradualTransitionsThreshold: Double? = 40.0,
        emulation: AlgorithmEmulationOptions? = nil
    )
    {
        self.glucoseHistory = glucoseHistory
        self.doses = doses
        self.carbEntries = carbEntries
        self.basal = basal
        self.sensitivity = sensitivity
        self.carbRatio = carbRatio
        self.target = target
        self.algorithmEffectsOptions = algorithmEffectsOptions
        self.useIntegralRetrospectiveCorrection = useIntegralRetrospectiveCorrection
        self.includePositiveVelocityAndRC = includePositiveVelocityAndRC
        self.carbAbsorptionModel = carbAbsorptionModel
        self.gradualTransitionsThreshold = gradualTransitionsThreshold
        self.emulation = emulation
    }
}


extension LoopPredictionInput: Codable where CarbType == FixtureCarbEntry, GlucoseType == FixtureGlucoseSample, InsulinDoseType == FixtureInsulinDose {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.glucoseHistory = try container.decode([FixtureGlucoseSample].self, forKey: .glucoseHistory)
        self.doses = try container.decode([FixtureInsulinDose].self, forKey: .doses)
        self.carbEntries = try container.decode([FixtureCarbEntry].self, forKey: .carbEntries)
        self.basal = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .basal)
        let sensitivityMgdl = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .sensitivity)
        self.sensitivity = sensitivityMgdl.map { AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.value))}
        self.carbRatio = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .carbRatio)
        if let targetMgdl = try container.decodeIfPresent([TargetEntry].self, forKey: .target) {
            self.target = targetMgdl.map {
                let lower = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.lowerBound)
                let upper = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.upperBound)
                return AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: lower...upper)
            }
        } else {
            self.target = []
        }
        if let algorithmEffectsOptionsRaw = try container.decodeIfPresent(AlgorithmEffectsOptions.RawValue.self, forKey: .algorithmEffectsOptions) {
            self.algorithmEffectsOptions = AlgorithmEffectsOptions(rawValue: algorithmEffectsOptionsRaw)
        } else {
            self.algorithmEffectsOptions = .all
        }
        self.useIntegralRetrospectiveCorrection = try container.decodeIfPresent(Bool.self, forKey: .useIntegralRetrospectiveCorrection) ?? false
        self.includePositiveVelocityAndRC = try container.decodeIfPresent(Bool.self, forKey: .includePositiveVelocityAndRC) ?? true
        self.carbAbsorptionModel = try container.decodeIfPresent(CarbAbsorptionModel.self, forKey: .carbAbsorptionModel) ?? .piecewiseLinear
        self.gradualTransitionsThreshold = try container.decodeIfPresent(Double.self, forKey: .gradualTransitionsThreshold) ?? 40.0
        self.emulation = try container.decodeIfPresent(AlgorithmEmulationOptions.self, forKey: .emulation)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(glucoseHistory, forKey: .glucoseHistory)
        try container.encode(doses, forKey: .doses)
        try container.encode(carbEntries, forKey: .carbEntries)
        try container.encode(basal, forKey: .basal)
        let sensitivityMgdl = sensitivity.map { AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: $0.value.doubleValue(for: .milligramsPerDeciliter)) }
        try container.encode(sensitivityMgdl, forKey: .sensitivity)
        try container.encode(carbRatio, forKey: .carbRatio)
        if !target.isEmpty {
            let targetMgdl = target.map {
                TargetEntry(
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    lowerBound: $0.value.lowerBound.doubleValue(for: .milligramsPerDeciliter),
                    upperBound: $0.value.upperBound.doubleValue(for: .milligramsPerDeciliter))
            }
            try container.encode(targetMgdl, forKey: .target)
        }
        if algorithmEffectsOptions != .all {
            try container.encode(algorithmEffectsOptions.rawValue, forKey: .algorithmEffectsOptions)
        }
        if !useIntegralRetrospectiveCorrection {
            try container.encode(useIntegralRetrospectiveCorrection, forKey: .useIntegralRetrospectiveCorrection)
        }
        if !includePositiveVelocityAndRC {
            try container.encode(includePositiveVelocityAndRC, forKey: .includePositiveVelocityAndRC)
        }
        try container.encode(carbAbsorptionModel, forKey: .carbAbsorptionModel)
        try container.encode(gradualTransitionsThreshold, forKey: .gradualTransitionsThreshold)
        if let emulation {
            try container.encode(emulation, forKey: .emulation)
        }
    }

    struct TargetEntry: Codable {
        var startDate: Date
        var endDate: Date
        var lowerBound: Double
        var upperBound: Double
    }

    private enum CodingKeys: String, CodingKey {
        case glucoseHistory
        case doses
        case carbEntries
        case basal
        case sensitivity
        case carbRatio
        case target
        case algorithmEffectsOptions
        case useIntegralRetrospectiveCorrection
        case includePositiveVelocityAndRC
        case carbAbsorptionModel
        case gradualTransitionsThreshold
        case emulation
    }
}
