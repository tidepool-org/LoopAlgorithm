//
//  AlgorithmInput.swift
//  LoopAlgorithm
//
//  Created by Pete Schwamb on 9/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation


public protocol AlgorithmInput {
    associatedtype CarbType: CarbEntry
    associatedtype GlucoseType: GlucoseSampleValue
    associatedtype InsulinDoseType: InsulinDose

    var predictionStart: Date { get }
    var glucoseHistory: [GlucoseType] { get }
    var doses: [InsulinDoseType] { get }
    var carbEntries: [CarbType] { get }
    var basal: [AbsoluteScheduleValue<Double>] { get }
    var sensitivity: [AbsoluteScheduleValue<LoopQuantity>] { get }
    var carbRatio: [AbsoluteScheduleValue<Double>] { get }
    var target: GlucoseRangeTimeline { get }
    var suspendThreshold: LoopQuantity? { get }
    var maxBolus: Double { get }
    var maxBasalRate: Double { get }
    var useIntegralRetrospectiveCorrection: Bool { get }
    var includePositiveVelocityAndRC: Bool { get }
    var useMidAbsorptionISF: Bool { get }
    var carbAbsorptionModel: CarbAbsorptionModel { get }
    var recommendationInsulinModel: InsulinModel { get }
    var recommendationType: DoseRecommendationType { get }
    var automaticBolusApplicationFactor: Double? { get }
}


