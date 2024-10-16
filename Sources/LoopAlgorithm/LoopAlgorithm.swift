//
//  LoopAlgorithm.swift
//
//  Created by Pete Schwamb on 6/30/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public enum AlgorithmError: Error {
    case missingGlucose
    case glucoseTooOld
    case basalTimelineIncomplete
    case missingSuspendThreshold
    case sensitivityTimelineStartsTooLate
    case sensitivityTimelineEndsTooEarly
    case futureBasalNotAllowed
}

public struct LoopAlgorithmEffects<CarbStatusType: CarbEntry> {
    public var insulin: [GlucoseEffect]
    public var carbs: [GlucoseEffect]
    public var carbStatus: [CarbStatus<CarbStatusType>]
    public var retrospectiveCorrection: [GlucoseEffect]
    public var momentum: [GlucoseEffect]
    public var insulinCounteraction: [GlucoseEffectVelocity]
    public var retrospectiveGlucoseDiscrepancies: [GlucoseChange]
    public var totalRetrospectiveCorrectionEffect: HKQuantity?

    public init(
        insulin: [GlucoseEffect],
        carbs: [GlucoseEffect],
        carbStatus: [CarbStatus<CarbStatusType>],
        retrospectiveCorrection: [GlucoseEffect],
        momentum: [GlucoseEffect],
        insulinCounteraction: [GlucoseEffectVelocity],
        retrospectiveGlucoseDiscrepancies: [GlucoseChange],
        totalRetrospectiveCorrectionEffect: HKQuantity? = nil
    ) {
        self.insulin = insulin
        self.carbs = carbs
        self.carbStatus = carbStatus
        self.retrospectiveCorrection = retrospectiveCorrection
        self.momentum = momentum
        self.insulinCounteraction = insulinCounteraction
        self.retrospectiveGlucoseDiscrepancies = retrospectiveGlucoseDiscrepancies
        self.totalRetrospectiveCorrectionEffect = totalRetrospectiveCorrectionEffect
    }
}

extension LoopAlgorithmEffects<FixtureCarbEntry>: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.insulin = try container.decode([GlucoseEffect].self, forKey: .insulin)
        self.carbs = try container.decode([GlucoseEffect].self, forKey: .carbs)
        self.carbStatus = try container.decode([CarbStatus<FixtureCarbEntry>].self, forKey: .carbStatus)
        self.retrospectiveCorrection = try container.decode([GlucoseEffect].self, forKey: .retrospectiveCorrection)
        self.momentum = try container.decode([GlucoseEffect].self, forKey: .momentum)
        self.insulinCounteraction = try container.decode([GlucoseEffectVelocity].self, forKey: .insulinCounteraction)
        self.retrospectiveGlucoseDiscrepancies = try container.decode([GlucoseChange].self, forKey: .retrospectiveGlucoseDiscrepancies)

        if let totalRetrospectiveCorrectionEffectValue = try container.decodeIfPresent(Double.self, forKey: .totalRetrospectiveCorrectionEffect) {
            self.totalRetrospectiveCorrectionEffect = HKQuantity(
                unit: .milligramsPerDeciliter,
                doubleValue: totalRetrospectiveCorrectionEffectValue
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(insulin, forKey: .insulin)
        try container.encode(carbs, forKey: .carbs)
        try container.encode(carbStatus, forKey: .carbStatus)
        try container.encode(retrospectiveCorrection, forKey: .retrospectiveCorrection)
        try container.encode(momentum, forKey: .momentum)
        try container.encode(insulinCounteraction, forKey: .insulinCounteraction)
        try container.encode(retrospectiveGlucoseDiscrepancies, forKey: .retrospectiveGlucoseDiscrepancies)
        if let totalRetrospectiveCorrectionEffect {
            try container.encode(
                totalRetrospectiveCorrectionEffect.doubleValue(for: .milligramsPerDeciliter),
                forKey: .totalRetrospectiveCorrectionEffect
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case insulin
        case carbs
        case carbStatus
        case retrospectiveCorrection
        case momentum
        case insulinCounteraction
        case retrospectiveGlucoseDiscrepancies
        case totalRetrospectiveCorrectionEffect
    }
}


public struct AlgorithmEffectsOptions: OptionSet {
    public let rawValue: UInt8

    public static let carbs            = AlgorithmEffectsOptions(rawValue: 1 << 0)
    public static let insulin          = AlgorithmEffectsOptions(rawValue: 1 << 1)
    public static let momentum         = AlgorithmEffectsOptions(rawValue: 1 << 2)
    public static let retrospection    = AlgorithmEffectsOptions(rawValue: 1 << 3)

    public static let all: AlgorithmEffectsOptions = [.carbs, .insulin, .momentum, .retrospection]

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

public struct LoopPrediction<CarbStatusType: CarbEntry> {
    public var glucose: [PredictedGlucoseValue]
    public var effects: LoopAlgorithmEffects<CarbStatusType>
    public var dosesRelativeToBasal: [BasalRelativeDose]
    public var activeInsulin: Double?
    public var activeCarbs: Double?
}

public struct LoopAlgorithm {
    /// Percentage of recommended dose to apply as bolus when using automatic bolus dosing strategy
    static public let defaultBolusPartialApplicationFactor = 0.4

    /// The duration of recommended temp basals
    static public let tempBasalDuration = TimeInterval(minutes: 30)

    /// The amount of time since a given date that input data should be considered valid
    public static let inputDataRecencyInterval = TimeInterval(minutes: 15)

    /// Calculates the needed interval for insulin sensitivity to run the algorithm
    /// - Parameters:
    ///   - doses: The active doses affecting the forecast
    ///   - glucoseHistoryStart: The start date of glucose history
    ///   - recommendationEffectInterval:The interval covering effects of a recommended dose
    public static func timelineIntervalForSensitivity<DoseType: InsulinDose>(
        doses: [DoseType],
        glucoseHistoryStart: Date,
        recommendationEffectInterval: DateInterval
    ) -> DateInterval {
        return (doses.effectsInterval() ?? DateInterval(start: glucoseHistoryStart, end: glucoseHistoryStart))
            .extendedToInclude(glucoseHistoryStart)
            .extendedToInclude(recommendationEffectInterval)
            .extendedForSimulation()
    }

    /// Generates a forecast predicting glucose.
    /// Outputs may be incomplete, if there are issues with the provided data, but as many intermediate derived fields as can be computed, will be computed.
    ///
    /// Returns nil if the normal scheduled basal, or active temporary basal, is sufficient.
    /// 
    ///
    /// - Parameters:
    ///   - start: The starting time of the glucose prediction.
    ///   - glucoseHistory: History of glucose values: t-10h to t. Must include at least one value.
    ///   - doses: History of insulin doses: t-16h to t
    ///   - carbEntries: History of carb entries: t-10h to t
    ///   - basal: Scheduled basal rate timeline: t-16h to t
    ///   - sensitivity: Insulin sensitivity timeline: t-16h to t (eventually with mid-absorption isf changes, it will be t-10h to t)
    ///   - carbRatio: Carb ratio timeline: t-10h to t+6h
    ///   - algorithmEffectsOptions: Which effects to include when combining effects to generate glucose prediction
    ///   - useIntegralRetrospectiveCorrection: If true, the prediction will use Integral Retrospection. If false, will use traditional Retrospective Correction
    ///   - includingPositiveVelocityAndRC: If false, only net negative momentum and RC effects will used.
    ///   - carbAbsorptionModel: A model conforming to CarbAbsorptionComputable that is used for computing carb absorption over time.
    /// - Returns: A LoopPrediction struct containing the predicted glucose and the computed intermediate effects used to make the prediction

    public static func generatePrediction<CarbType, GlucoseType, InsulinDoseType>(
        start: Date,
        glucoseHistory: [GlucoseType],
        doses: [InsulinDoseType],
        carbEntries: [CarbType],
        basal: [AbsoluteScheduleValue<Double>],
        sensitivity: [AbsoluteScheduleValue<HKQuantity>],
        carbRatio: [AbsoluteScheduleValue<Double>],
        algorithmEffectsOptions: AlgorithmEffectsOptions = .all,
        useIntegralRetrospectiveCorrection: Bool = false,
        includingPositiveVelocityAndRC: Bool = true,
        useMidAbsorptionISF: Bool = false,
        carbAbsorptionModel: CarbAbsorptionComputable = PiecewiseLinearAbsorption()
    ) -> LoopPrediction<CarbType> where CarbType: CarbEntry, GlucoseType: GlucoseSampleValue, InsulinDoseType: InsulinDose {

        var prediction: [PredictedGlucoseValue] = []
        var insulinEffects: [GlucoseEffect] = []
        var carbEffects: [GlucoseEffect] = []
        var retrospectiveCorrectionEffects: [GlucoseEffect] = []
        var momentumEffects: [GlucoseEffect] = []
        var insulinCounteractionEffects: [GlucoseEffectVelocity] = []
        var retrospectiveGlucoseDiscrepanciesSummed: [GlucoseChange] = []
        var totalRetrospectiveCorrectionEffect: HKQuantity?
        var activeInsulin: Double?
        var activeCarbs: Double?
        //var carbStatus: [CarbStatus] = []
        var dosesRelativeToBasal: [BasalRelativeDose] = []

        // Ensure basal history covers doses
        let doseStart = doses.first?.startDate ?? start
        if !basal.isEmpty, basal.first!.startDate <= doseStart {
            // Overlay basal history on basal doses, splitting doses to get amount delivered relative to basal
            dosesRelativeToBasal = doses.annotated(with: basal)

            activeInsulin = dosesRelativeToBasal.insulinOnBoard(at: start)

            var insulinEffectsInterval = dosesRelativeToBasal.effectsInterval() ?? DateInterval(start: start, end: start)

            // Extend range of insulin effects to cover glucose, if needed
            if let glucoseStart = glucoseHistory.first?.startDate, glucoseStart < insulinEffectsInterval.start {
                insulinEffectsInterval.start = glucoseStart
            }

            if let glucoseEnd = glucoseHistory.last?.endDate, glucoseEnd > insulinEffectsInterval.end {
                insulinEffectsInterval.end = glucoseEnd
            }

            if useMidAbsorptionISF {
                insulinEffects = dosesRelativeToBasal.glucoseEffectsMidAbsorptionISF(
                    insulinSensitivityHistory: sensitivity,
                    from: insulinEffectsInterval.start,
                    to: insulinEffectsInterval.end)
            } else {
                insulinEffects = dosesRelativeToBasal.glucoseEffects(
                    insulinSensitivityHistory: sensitivity,
                    from: insulinEffectsInterval.start,
                    to: insulinEffectsInterval.end)
            }

            // ICE
            insulinCounteractionEffects = glucoseHistory.counteractionEffects(to: insulinEffects)
        } else {
            activeInsulin = 0
        }

        // Carb Effects
        let carbStatus = carbEntries.map(
            to: insulinCounteractionEffects,
            carbRatio: carbRatio,
            insulinSensitivity: sensitivity
        )

        carbEffects = carbStatus.dynamicGlucoseEffects(
            from: start.addingTimeInterval(-IntegralRetrospectiveCorrection.retrospectionInterval),
            carbRatios: carbRatio,
            insulinSensitivities: sensitivity,
            absorptionModel: carbAbsorptionModel
        )

        activeCarbs = carbStatus.dynamicCarbsOnBoard(at: start, absorptionModel: carbAbsorptionModel)

        // RC
        let retrospectiveGlucoseDiscrepancies = insulinCounteractionEffects.subtracting(carbEffects)
        retrospectiveGlucoseDiscrepanciesSummed = retrospectiveGlucoseDiscrepancies.combinedSums(of: LoopMath.retrospectiveCorrectionGroupingInterval * 1.01)

        let rc: RetrospectiveCorrection

        if useIntegralRetrospectiveCorrection {
            rc = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        } else {
            rc = StandardRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        }

        

        if let latestGlucose = glucoseHistory.last {
            retrospectiveCorrectionEffects = rc.computeEffect(
                startingAt: latestGlucose,
                retrospectiveGlucoseDiscrepanciesSummed: retrospectiveGlucoseDiscrepanciesSummed,
                recencyInterval: TimeInterval(minutes: 15),
                retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval
            )

            totalRetrospectiveCorrectionEffect = rc.totalGlucoseCorrectionEffect

            var effects = [[GlucoseEffect]]()

            if algorithmEffectsOptions.contains(.carbs) {
                effects.append(carbEffects)
            }

            if algorithmEffectsOptions.contains(.insulin) {
                effects.append(insulinEffects)
            }

            if algorithmEffectsOptions.contains(.retrospection) {
                if !includingPositiveVelocityAndRC, let netRC = retrospectiveCorrectionEffects.netEffect(), netRC.quantity.doubleValue(for: .milligramsPerDeciliter) > 0 {
                    // positive RC is turned off
                } else {
                    effects.append(retrospectiveCorrectionEffects)
                }
            }

            // Glucose Momentum
            var useMomentum: Bool = true
            if algorithmEffectsOptions.contains(.momentum) {
                let momentumInputData = glucoseHistory.filterDateRange(start.addingTimeInterval(-GlucoseMath.momentumDataInterval), start)
                momentumEffects = momentumInputData.linearMomentumEffect()
                if !includingPositiveVelocityAndRC, let netMomentum = momentumEffects.netEffect(), netMomentum.quantity.doubleValue(for: .milligramsPerDeciliter) > 0 {
                    // positive momentum is turned off
                    useMomentum = false
                }
            } else {
                useMomentum = false
            }

            prediction = LoopMath.predictGlucose(
                startingAt: latestGlucose,
                momentum: useMomentum ? momentumEffects : [],
                effects: effects
            )

            // Dosing requires prediction entries at least as long as the insulin model duration.
            // If our prediction is shorter than that, then extend it here.
            let finalDate = start.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration)
            if let last = prediction.last, last.startDate < finalDate {
                prediction.append(PredictedGlucoseValue(startDate: finalDate, quantity: last.quantity))
            }
        }

        return LoopPrediction(
            glucose: prediction,
            effects: LoopAlgorithmEffects(
                insulin: insulinEffects,
                carbs: carbEffects,
                carbStatus: carbStatus,
                retrospectiveCorrection: retrospectiveCorrectionEffects,
                momentum: momentumEffects,
                insulinCounteraction: insulinCounteractionEffects,
                retrospectiveGlucoseDiscrepancies: retrospectiveGlucoseDiscrepanciesSummed,
                totalRetrospectiveCorrectionEffect: totalRetrospectiveCorrectionEffect
            ),
            dosesRelativeToBasal: dosesRelativeToBasal,
            activeInsulin: activeInsulin,
            activeCarbs: activeCarbs
        )
    }

    // Helper to generate prediction with LoopPredictionInput struct
    public static func generatePrediction<CarbType, GlucoseType, InsulinDoseType>(input: LoopPredictionInput<CarbType, GlucoseType, InsulinDoseType>) -> LoopPrediction<CarbType> {

        return generatePrediction(
            start: input.glucoseHistory.last?.startDate ?? Date(),
            glucoseHistory: input.glucoseHistory,
            doses: input.doses,
            carbEntries: input.carbEntries,
            basal: input.basal,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            algorithmEffectsOptions: input.algorithmEffectsOptions,
            useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection,
            carbAbsorptionModel: input.carbAbsorptionModel.model
        )
    }

    // Computes an amount of insulin to correct the given prediction
    static func insulinCorrection(
        prediction: [PredictedGlucoseValue],
        at deliveryDate: Date,
        target: GlucoseRangeTimeline,
        suspendThreshold: HKQuantity,
        sensitivity: [AbsoluteScheduleValue<HKQuantity>],
        insulinModel: InsulinModel
    ) -> InsulinCorrection {
        return prediction.insulinCorrection(
            to: target,
            at: deliveryDate,
            suspendThreshold: suspendThreshold,
            insulinSensitivity: sensitivity,
            model: insulinModel)
    }

    // Computes a 30 minute temp basal dose to correct the given prediction
    static func recommendTempBasal(
        for correction: InsulinCorrection,
        neutralBasalRate: Double,
        activeInsulin: Double,
        maxBolus: Double,
        maxBasalRate: Double
    ) -> TempBasalRecommendation? {

        var maxBasalRate = maxBasalRate

        // TODO: Allow `highBasalThreshold` to be a configurable setting
        if case .aboveRange(min: let min, correcting: _, minTarget: let highBasalThreshold, units: _) = correction,
            min.quantity < highBasalThreshold
        {
            maxBasalRate = neutralBasalRate
        }

        // Enforce max IOB, calculated from the user entered maxBolus
        let automaticDosingIOBLimit = maxBolus * 2.0
        let iobHeadroom = automaticDosingIOBLimit - activeInsulin

        let maxThirtyMinuteRateToKeepIOBBelowLimit = iobHeadroom * (TimeInterval.hours(1) / tempBasalDuration) + neutralBasalRate  // 30 minutes of a U/hr rate
        maxBasalRate = Swift.min(maxThirtyMinuteRateToKeepIOBBelowLimit, maxBasalRate)

        return correction.asTempBasal(
            neutralBasalRate: neutralBasalRate,
            maxBasalRate: maxBasalRate,
            duration: tempBasalDuration
        )
    }

    // Computes a bolus or low-temp basal dose to correct the given prediction
    static func recommendAutomaticDose(
        for correction: InsulinCorrection,
        applicationFactor: Double,
        neutralBasalRate: Double,
        activeInsulin: Double,
        maxBolus: Double,
        maxBasalRate: Double
    ) -> AutomaticDoseRecommendation? {


        let deliveryHeadroom = max(0, maxBolus * 2.0 - activeInsulin)

        var deliveryMax = min(maxBolus * applicationFactor, deliveryHeadroom)

        if case .aboveRange(min: let min, correcting: _, minTarget: let minTarget, units: _) = correction,
            min.quantity < minTarget
        {
            deliveryMax = 0
        }

        let temp: TempBasalRecommendation? = correction.asTempBasal(
            neutralBasalRate: neutralBasalRate,
            maxBasalRate: neutralBasalRate,
            duration: .minutes(30)
        )

        let bolusUnits = correction.asPartialBolus(
            partialApplicationFactor: applicationFactor,
            maxBolusUnits: deliveryMax
        )

        if temp != nil || bolusUnits > 0 {
            return AutomaticDoseRecommendation(basalAdjustment: temp, bolusUnits: bolusUnits)
        }

        return nil
    }

    // Computes a manual bolus to correct the given prediction
    public static func recommendManualBolus(
        for correction: InsulinCorrection,
        maxBolus: Double,
        currentGlucose: GlucoseSampleValue,
        target: GlucoseRangeTimeline
    ) -> ManualBolusRecommendation {
        var bolus = correction.asManualBolus(maxBolus: maxBolus)

        if let targetAtCurrentGlucose = target.closestPrior(to: currentGlucose.startDate),
           currentGlucose.quantity < targetAtCurrentGlucose.value.lowerBound
        {
            bolus.notice = .currentGlucoseBelowTarget(glucose: SimpleGlucoseValue(currentGlucose))
        }

        return bolus
    }

    public static func run<LoopAlgorithmInputType: AlgorithmInput>(input: LoopAlgorithmInputType) -> AlgorithmOutput<LoopAlgorithmInputType.CarbType> {

        var prediction = LoopPrediction(
            glucose: [],
            effects: LoopAlgorithmEffects(
                insulin: [],
                carbs: [],
                carbStatus: [CarbStatus<LoopAlgorithmInputType.CarbType>](),
                retrospectiveCorrection: [],
                momentum: [],
                insulinCounteraction: [],
                retrospectiveGlucoseDiscrepancies: []
            ),
            dosesRelativeToBasal: []
        )

        // Now validate/recommend
        let result: Result<LoopAlgorithmDoseRecommendation,Error>

        do {
            guard let latestGlucose = input.glucoseHistory.last else {
                throw AlgorithmError.missingGlucose
            }

            guard input.predictionStart.timeIntervalSince(latestGlucose.startDate) < inputDataRecencyInterval else {
                throw AlgorithmError.glucoseTooOld
            }

            // When running the algorithm for automated dosing, future basal should not be included
            if let basalEnd = input.doses.filter({ $0.deliveryType == .basal }).map({ $0.endDate }).max() {
                guard !input.recommendationType.automated || basalEnd <= input.predictionStart else {
                    throw AlgorithmError.futureBasalNotAllowed
                }
            }

            let forecastEnd = input.predictionStart.addingTimeInterval(input.recommendationInsulinModel.effectDuration).dateCeiledToTimeInterval(GlucoseMath.defaultDelta)

            let glucoseStart = input.glucoseHistory.first?.startDate ?? input.predictionStart

            // Make sure ISF covers needed timeline
            let recommendationEffectInterval = DateInterval(
                start: input.predictionStart,
                duration: input.recommendationInsulinModel.effectDuration)
            let neededISFInterval = timelineIntervalForSensitivity(
                doses: input.doses,
                glucoseHistoryStart: glucoseStart,
                recommendationEffectInterval: recommendationEffectInterval
            )
            guard let sensitivityStartDate = input.sensitivity.first?.startDate, sensitivityStartDate <= neededISFInterval.start else {
                throw AlgorithmError.sensitivityTimelineStartsTooLate
            }
            guard let sensitivityEndDate = input.sensitivity.last?.endDate, sensitivityEndDate >= neededISFInterval.end else {
                throw AlgorithmError.sensitivityTimelineEndsTooEarly
            }

            // Make sure Basal covers needed timeline
            guard let scheduledBasalRate = input.basal.closestPrior(to: input.predictionStart)?.value else {
                throw AlgorithmError.basalTimelineIncomplete
            }

            guard let suspendThreshold = input.suspendThreshold ?? input.target.closestPrior(to: input.predictionStart)?.value.lowerBound else {
                throw AlgorithmError.missingSuspendThreshold
            }

            prediction = generatePrediction(
                start: input.predictionStart,
                glucoseHistory: input.glucoseHistory,
                doses: input.doses,
                carbEntries: input.carbEntries,
                basal: input.basal,
                sensitivity: input.sensitivity,
                carbRatio: input.carbRatio,
                algorithmEffectsOptions: .all,
                useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection,
                includingPositiveVelocityAndRC: input.includePositiveVelocityAndRC,
                useMidAbsorptionISF: input.useMidAbsorptionISF,
                carbAbsorptionModel: input.carbAbsorptionModel.model
            )

            let sensitivityForDosing: [AbsoluteScheduleValue<HKQuantity>]
            if input.useMidAbsorptionISF {
                sensitivityForDosing = input.sensitivity
            } else {
                // This sets a single ISF value for the duration of the dose.
                let sensitivityEnd = max(forecastEnd, prediction.effects.insulin.last?.startDate ?? .distantPast)
                let sensitivityAtPredictionStart = input.sensitivity.first { $0.startDate <= input.predictionStart && $0.endDate >= input.predictionStart }!
                let sensitivityOverPrediction = AbsoluteScheduleValue(
                    startDate: sensitivityAtPredictionStart.startDate,
                    endDate: sensitivityEnd,
                    value: sensitivityAtPredictionStart.value
                )
                sensitivityForDosing = [sensitivityOverPrediction]
            }

            let correction = insulinCorrection(
                prediction: prediction.glucose,
                at: input.predictionStart,
                target: input.target,
                suspendThreshold: suspendThreshold,
                sensitivity: sensitivityForDosing,
                insulinModel: input.recommendationInsulinModel)

            switch input.recommendationType {
            case .manualBolus:
                let recommendation = recommendManualBolus(
                    for: correction,
                    maxBolus: input.maxBolus,
                    currentGlucose: latestGlucose,
                    target: input.target)
                result = .success(.init(manual: recommendation))
            case .automaticBolus:
                let recommendation = recommendAutomaticDose(
                    for: correction,
                    applicationFactor: input.automaticBolusApplicationFactor ?? defaultBolusPartialApplicationFactor,
                    neutralBasalRate: scheduledBasalRate,
                    activeInsulin: prediction.activeInsulin!,
                    maxBolus: input.maxBolus,
                    maxBasalRate: input.maxBasalRate)
                result = .success(.init(automatic: recommendation))
            case .tempBasal:
                let recommendation = recommendTempBasal(
                    for: correction,
                    neutralBasalRate: scheduledBasalRate,
                    activeInsulin: prediction.activeInsulin!,
                    maxBolus: input.maxBolus,
                    maxBasalRate: input.maxBasalRate)
                result = .success(.init(automatic: AutomaticDoseRecommendation(basalAdjustment: recommendation)))
            }
        } catch {
            result = .failure(error)
        }

        return AlgorithmOutput(
            recommendationResult: result,
            predictedGlucose: prediction.glucose,
            effects: prediction.effects,
            dosesRelativeToBasal: prediction.dosesRelativeToBasal,
            activeInsulin: prediction.activeInsulin,
            activeCarbs: prediction.activeCarbs
        )
    }
}

