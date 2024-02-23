//
//  AlgorithmInput.swift
//  LoopAlgorithm
//
//  Created by Pete Schwamb on 9/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit


public protocol AlgorithmInput {
    associatedtype CarbType: CarbEntry
    associatedtype GlucoseType: GlucoseSampleValue
    associatedtype InsulinDoseType: InsulinDose

    var predictionStart: Date { get }
    var glucoseHistory: [GlucoseType] { get }
    var doses: [InsulinDoseType] { get }
    var carbEntries: [CarbType] { get }
    var basal: [AbsoluteScheduleValue<Double>] { get }
    var sensitivity: [AbsoluteScheduleValue<HKQuantity>] { get }
    var carbRatio: [AbsoluteScheduleValue<Double>] { get }
    var target: GlucoseRangeTimeline { get }
    var suspendThreshold: HKQuantity? { get }
    var maxBolus: Double { get }
    var maxBasalRate: Double { get }
    var useIntegralRetrospectiveCorrection: Bool { get }
    var includePositiveVelocityAndRC: Bool { get }
    var carbAbsorptionModel: CarbAbsorptionModel { get }
    var recommendationInsulinModel: InsulinModel { get }
    var recommendationType: DoseRecommendationType { get }
    var automaticBolusApplicationFactor: Double? { get }
}


