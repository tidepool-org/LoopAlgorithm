//
//  IntegralRetrospectiveCorrection.swift
//  Loop
//
//  Created by Dragan Maksimovic on 9/19/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

/**
    Integral Retrospective Correction (IRC) calculates a correction effect in glucose prediction based on a timeline of past discrepancies between observed glucose movement and movement expected based on insulin and carb models. Integral retrospective correction acts as a proportional-integral-differential (PID) controller aimed at reducing modeling errors in glucose prediction.
 
    In the above summary, "discrepancy" is a difference between the actual glucose and the model predicted glucose over retrospective correction grouping interval (set to 30 min in LoopSettings), whereas "past discrepancies" refers to a timeline of discrepancies computed over retrospective correction integration interval (set to 180 min in Loop Settings).
 
 */
public class IntegralRetrospectiveCorrection: RetrospectiveCorrection {
    public static let retrospectionInterval = TimeInterval(minutes: 180)

    /// RetrospectiveCorrection protocol variables
    /// Standard effect duration
    let effectDuration: TimeInterval
    /// Overall retrospective correction effect
    public var totalGlucoseCorrectionEffect: LoopQuantity?
    
    /**
     Integral retrospective correction parameters:
     - currentDiscrepancyGain: Standard retrospective correction gain
     - persistentDiscrepancyGain: Gain for persistent long-term modeling errors, must be greater than or equal to currentDiscrepancyGain
     - correctionTimeConstant: How fast integral effect accumulates in response to persistent errors
     - differentialGain: Differential effect gain
     - delta: Glucose sampling time interval (5 min)
     - maximumCorrectionEffectDuration: Maximum duration of the correction effect in glucose prediction
     - retrospectiveCorrectionIntegrationInterval: Maximum duration over which to integrate retrospective correction changes
    */
    static let currentDiscrepancyGain: Double = 1.0
    static let persistentDiscrepancyGain: Double = 2.0 // was 5.0
    static let correctionTimeConstant: TimeInterval = TimeInterval(minutes: 60.0) // was 90.0
    static let differentialGain: Double = 2.0
    static let delta: TimeInterval = TimeInterval(minutes: 5.0)
    static let maximumCorrectionEffectDuration: TimeInterval = TimeInterval(minutes: 180.0) // was 240.0
    
    /// Initialize computed integral retrospective correction parameters
    static let integralForget: Double = exp( -delta.minutes / correctionTimeConstant.minutes )
    static let integralGain: Double = ((1 - integralForget) / integralForget) *
        (persistentDiscrepancyGain - currentDiscrepancyGain)
    static let proportionalGain: Double = currentDiscrepancyGain - integralGain
    
    /// All math is performed with glucose expressed in mg/dL
    private let unit = LoopUnit.milligramsPerDeciliter
    
    /// State variables reported in diagnostic issue report
    var recentDiscrepancyValues: [Double] = []
    var integralCorrectionEffectDuration: TimeInterval?
    var proportionalCorrection: Double = 0.0
    var integralCorrection: Double = 0.0
    var differentialCorrection: Double = 0.0
    var currentDate: Date = Date()

    public init(effectDuration: TimeInterval) {
        self.effectDuration = effectDuration
    }
    
    /**
     Calculates overall correction effect based on timeline of discrepancies, and updates glucoseCorrectionEffect
     
     - Parameters:
     - glucose: Most recent glucose
     - retrospectiveGlucoseDiscrepanciesSummed: Timeline of past discepancies
     
     - Returns:
     - totalRetrospectiveCorrection: Overall glucose effect
     */
    public func computeEffect(
        startingAt startingGlucose: GlucoseValue,
        retrospectiveGlucoseDiscrepanciesSummed: [GlucoseChange]?,
        recencyInterval: TimeInterval,
        retrospectiveCorrectionGroupingInterval: TimeInterval
        ) -> [GlucoseEffect] {
        
        // Loop settings relevant for calculation of effect limits
        // let settings = UserDefaults.appGroup?.loopSettings ?? LoopSettings()
        currentDate = Date()
        
        // Last discrepancy should be recent, otherwise clear the effect and return
        let glucoseDate = startingGlucose.startDate
        var glucoseCorrectionEffect: [GlucoseEffect] = []
        guard let currentDiscrepancy = retrospectiveGlucoseDiscrepanciesSummed?.last,
            glucoseDate.timeIntervalSince(currentDiscrepancy.endDate) <= recencyInterval
            else {
                totalGlucoseCorrectionEffect = nil
                return( [] )
        }
        
        // Default values if we are not able to calculate integral retrospective correction
        let currentDiscrepancyValue = currentDiscrepancy.quantity.doubleValue(for: unit)
        var scaledCorrection = currentDiscrepancyValue
        totalGlucoseCorrectionEffect = LoopQuantity(unit: unit, doubleValue: currentDiscrepancyValue)
        integralCorrectionEffectDuration = effectDuration
        
        // Calculate integral retrospective correction if past discrepancies over integration interval are available and if user settings are available
        if let pastDiscrepancies = retrospectiveGlucoseDiscrepanciesSummed?.filterDateRange(glucoseDate.addingTimeInterval(-Self.retrospectionInterval), glucoseDate) {

            // To reduce response delay, integral retrospective correction is computed over an array of recent contiguous discrepancy values having the same sign as the latest discrepancy value
            recentDiscrepancyValues = []
            var nextDiscrepancy = currentDiscrepancy
            let currentDiscrepancySign = currentDiscrepancy.quantity.doubleValue(for: unit).sign
            for pastDiscrepancy in pastDiscrepancies.reversed() {
                let pastDiscrepancyValue = pastDiscrepancy.quantity.doubleValue(for: unit)
                if (pastDiscrepancyValue.sign == currentDiscrepancySign &&
                    nextDiscrepancy.endDate.timeIntervalSince(pastDiscrepancy.endDate)
                    <= recencyInterval && abs(pastDiscrepancyValue) >= 0.1)
                {
                    recentDiscrepancyValues.append(pastDiscrepancyValue)
                    nextDiscrepancy = pastDiscrepancy
                } else {
                    break
                }
            }
            recentDiscrepancyValues = recentDiscrepancyValues.reversed()

            // Integral effect math
            integralCorrection = 0.0
            var integralCorrectionEffectMinutes = effectDuration.minutes - 2.0 * IntegralRetrospectiveCorrection.delta.minutes
            for discrepancy in recentDiscrepancyValues {
                integralCorrection =
                    IntegralRetrospectiveCorrection.integralForget * integralCorrection +
                    IntegralRetrospectiveCorrection.integralGain * discrepancy
                integralCorrectionEffectMinutes += 2.0 * IntegralRetrospectiveCorrection.delta.minutes
            }
            // Limit effect duration
            integralCorrectionEffectMinutes = min(integralCorrectionEffectMinutes, IntegralRetrospectiveCorrection.maximumCorrectionEffectDuration.minutes)
            
            // Differential effect math
            var differentialDiscrepancy: Double = 0.0
            if recentDiscrepancyValues.count > 1 {
                let previousDiscrepancyValue = recentDiscrepancyValues[recentDiscrepancyValues.count - 2]
                differentialDiscrepancy = currentDiscrepancyValue - previousDiscrepancyValue
            }
            
            // Overall glucose effect calculated as a sum of propotional, integral and differential effects
            proportionalCorrection = IntegralRetrospectiveCorrection.proportionalGain * currentDiscrepancyValue

	    // Differential effect added only when negative, to avoid upward stacking with momentum, while still mitigating sluggishness of retrospective correction when discrepancies start decreasing
            if differentialDiscrepancy < 0.0 {
                differentialCorrection = IntegralRetrospectiveCorrection.differentialGain * differentialDiscrepancy
            } else {
                differentialCorrection = 0.0
            }

            let totalCorrection = proportionalCorrection + integralCorrection + differentialCorrection
            totalGlucoseCorrectionEffect = LoopQuantity(unit: unit, doubleValue: totalCorrection)
            integralCorrectionEffectDuration = TimeInterval(minutes: integralCorrectionEffectMinutes)
            
            // correction value scaled to account for extended effect duration
            scaledCorrection = totalCorrection * effectDuration.minutes / integralCorrectionEffectDuration!.minutes
        }
        
        let retrospectionTimeInterval = currentDiscrepancy.endDate.timeIntervalSince(currentDiscrepancy.startDate)
        let discrepancyTime = max(retrospectionTimeInterval, retrospectiveCorrectionGroupingInterval)
            let velocity = LoopQuantity(unit: .milligramsPerDeciliterPerSecond, doubleValue: scaledCorrection / discrepancyTime)
        
        // Update array of glucose correction effects
        glucoseCorrectionEffect = startingGlucose.decayEffect(atRate: velocity, for: integralCorrectionEffectDuration!)
        
        // Return glucose correction effects
        return( glucoseCorrectionEffect )
    }

}
