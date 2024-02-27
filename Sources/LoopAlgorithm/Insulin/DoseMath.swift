//
//  DoseMath.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/8/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit

public enum InsulinCorrection {
    case inRange
    case aboveRange(min: GlucoseValue, correcting: GlucoseValue, minTarget: HKQuantity, units: Double)
    case entirelyBelowRange(min: GlucoseValue, minTarget: HKQuantity, units: Double)
    case suspend(min: GlucoseValue)
}

extension InsulinCorrection {
    /// The delivery units for the correction
    private var units: Double {
        switch self {
        case .aboveRange(min: _, correcting: _, minTarget: _, units: let units):
            return units
        case .entirelyBelowRange(min: _, minTarget: _, units: let units):
            return units
        case .inRange, .suspend:
            return 0
        }
    }

    /// Determines the temp basal over `duration` needed to perform the correction.
    ///
    /// - Parameters:
    ///   - neutralBasalRate: The basal rate that should effect no glucose change
    ///   - maxBasalRate: The maximum allowed basal rate
    ///   - duration: The duration of the temporary basal
    ///   - rateRounder: The smallest fraction of a unit supported in basal delivery
    /// - Returns: A temp basal recommendation
    public func asTempBasal(
        neutralBasalRate: Double,
        maxBasalRate: Double,
        duration: TimeInterval,
        rateRounder: ((Double) -> Double)? = nil
    ) -> TempBasalRecommendation {
        var rate = units / (duration / TimeInterval(hours: 1))  // units/hour
        switch self {
        case .aboveRange, .inRange, .entirelyBelowRange:
            rate += neutralBasalRate
        case .suspend:
            break
        }

        rate = Swift.min(maxBasalRate, Swift.max(0, rate))

        rate = rateRounder?(rate) ?? rate

        return TempBasalRecommendation(
            unitsPerHour: rate,
            duration: duration
        )
    }

    private var bolusRecommendationNotice: BolusRecommendationNotice? {
        switch self {
        case .suspend(min: let minimum):
            return .glucoseBelowSuspendThreshold(minGlucose: SimpleGlucoseValue(minimum))
        case .inRange:
            return .predictedGlucoseInRange
        case .entirelyBelowRange(min: let min, minTarget: _, units: _):
            return .allGlucoseBelowTarget(minGlucose: SimpleGlucoseValue(min))
        case .aboveRange(min: let min, correcting: _, minTarget: let target, units: let units):
            if units > 0 && min.quantity < target {
                return .predictedGlucoseBelowTarget(minGlucose: SimpleGlucoseValue(min))
            } else {
                return nil
            }
        }
    }

    /// Determines the bolus needed to perform the correction, subtracting any insulin already scheduled for
    ///  delivery, such as the remaining portion of an ongoing temp basal.
    ///
    /// - Parameters:
    ///   - maxBolus: The maximum allowable bolus value in units
    /// - Returns: A bolus recommendation
    public func asManualBolus(maxBolus: Double) -> ManualBolusRecommendation {
        return ManualBolusRecommendation(
            amount: Swift.min(maxBolus, Swift.max(0, units)),
            notice: bolusRecommendationNotice
        )
    }

    /// Determines the bolus amount to perform a partial application correction
    ///
    /// - Parameters:
    ///   - partialApplicationFactor: The fraction of needed insulin to deliver now
    ///   - maxBolus: The maximum allowable bolus value in units
    ///   - volumeRounder: Method to round computed dose to deliverable volume
    /// - Returns: A bolus recommendation
    public func asPartialBolus(
        partialApplicationFactor: Double,
        maxBolusUnits: Double,
        volumeRounder: ((Double) -> Double)? = nil
    ) -> Double {

        let partialDose = units * partialApplicationFactor

        return Swift.min(Swift.max(0, volumeRounder?(partialDose) ?? partialDose),volumeRounder?(maxBolusUnits) ?? maxBolusUnits)
    }
}

/// Computes a total insulin amount necessary to correct a glucose differential at a given sensitivity
///
/// - Parameters:
///   - fromValue: The starting glucose value
///   - toValue: The desired glucose value
///   - effectedSensitivity: The sensitivity, in glucose-per-insulin-unit
/// - Returns: The insulin correction in units
private func insulinCorrectionUnits(fromValue: Double, toValue: Double, effectedSensitivity: Double) -> Double {
    guard effectedSensitivity > 0 else {
        preconditionFailure("Negative effected sensitivity: \(effectedSensitivity)")
    }

    let glucoseCorrection = fromValue - toValue

    return glucoseCorrection / effectedSensitivity
}

/// Computes a target glucose value for a correction, at a given time during the insulin effect duration
///
/// - Parameters:
///   - percentEffectDuration: The percent of time elapsed of the insulin effect duration
///   - minValue: The minimum (starting) target value
///   - maxValue: The maximum (eventual) target value
/// - Returns: A target value somewhere between the minimum and maximum
private func targetGlucoseValue(percentEffectDuration: Double, minValue: Double, maxValue: Double) -> Double {
    // The inflection point in time: before it we use minValue, after it we linearly blend from minValue to maxValue
    let useMinValueUntilPercent = 0.5

    guard percentEffectDuration > useMinValueUntilPercent else {
        return minValue
    }

    guard percentEffectDuration < 1 else {
        return maxValue
    }

    let slope = (maxValue - minValue) / (1 - useMinValueUntilPercent)
    return minValue + slope * (percentEffectDuration - useMinValueUntilPercent)
}

public typealias GlucoseRangeTimeline = [AbsoluteScheduleValue<ClosedRange<HKQuantity>>]

extension Array where Element: GlucoseValue {

    /// For a collection of glucose prediction, determine the least amount of insulin delivered at
    /// `date` to correct the predicted glucose to the middle of `correctionRange` at the time of prediction.
    ///
    /// - Parameters:
    ///   - correctionRange: The timeline of glucose ranges used for correction. Must cover the range of prediction timestamp contained in this array.
    ///   - date: The date the insulin correction is delivered
    ///   - suspendThreshold: The glucose value below which only suspension is returned
    ///   - insulinSensitivityTimeline: The timeline of expected insulin sensitivity over the period of dose absorption. Must cover the range of prediction timestamp contained in this array.
    ///   - model: The insulin effect model
    /// - Returns: A correction value in units, or nil if no correction needed
    func insulinCorrection(
        to correctionRange: GlucoseRangeTimeline,
        at date: Date,
        suspendThreshold: HKQuantity,
        insulinSensitivity: [AbsoluteScheduleValue<HKQuantity>],
        model: InsulinModel
    ) -> InsulinCorrection {
        var minGlucose: GlucoseValue!
        var eventualGlucose: GlucoseValue!
        var correctingGlucose: GlucoseValue?
        var minCorrectionUnits: Double?
        var effectedSensitivityAtMinGlucose: Double?

        let unit = HKUnit.milligramsPerDeciliter

        guard self.count > 0 else {
            preconditionFailure("Unable to compute correction for empty glucose array")
        }

        // If this is not true, then this method will return very large doses. For example, it takes a *lot* of
        // insulin to bring a predicted glucose of 200 down to range within 30 minutes, so we assert that the
        // prediction includes values out to the end of insulin activity.
        guard self.last!.startDate >= date.addingTimeInterval(model.effectDuration) else {
            preconditionFailure("Minimization method requires that glucose prediction covers at least the insulin effect duration.")
        }

        let suspendThresholdValue = suspendThreshold.doubleValue(for: unit)

        // For each prediction above target, determine the amount of insulin necessary to correct glucose based on the modeled effectiveness of the insulin at that time
        for prediction in self {
            guard prediction.startDate >= date else {
                continue
            }

            // If any predicted value is below the suspend threshold, return immediately
            guard prediction.quantity >= suspendThreshold else {
                return .suspend(min: prediction)
            }

            eventualGlucose = prediction

            let predictedGlucoseValue = prediction.quantity.doubleValue(for: unit)
            let time = prediction.startDate.timeIntervalSince(date)

            guard let correctionRangeItem = correctionRange.closestPrior(to: prediction.startDate) else {
                preconditionFailure("Correction range must cover date: \(prediction.startDate)")
            }

            // Compute the target value as a function of time since the dose started
            let targetValue = targetGlucoseValue(
                percentEffectDuration: time / model.effectDuration,
                minValue: suspendThresholdValue,
                maxValue: correctionRangeItem.value.averageValue(for: unit)
            )

            // Compute the dose required to bring this prediction to target:
            // dose = (Glucose Δ) / (% effect × sensitivity)

            let isfSegments = insulinSensitivity.filterDateRange(date, prediction.startDate)

            var isfEnd: TimeInterval?

            let effectedSensitivity = isfSegments.reduce(0) { partialResult, segment in
                let start = Swift.max(date, segment.startDate).timeIntervalSince(date)
                let end = Swift.min(prediction.startDate, segment.endDate).timeIntervalSince(date)
                let percentEffected = model.percentEffectRemaining(at: start) - model.percentEffectRemaining(at: end)
                isfEnd = end
                return percentEffected * segment.value.doubleValue(for: unit)
            }

            guard let isfEnd, isfEnd >= prediction.startDate.timeIntervalSince(date) else {
                preconditionFailure("Sensitivity timeline must cover date: \(prediction.startDate)")
            }

            // Update range statistics
            if minGlucose == nil || prediction.quantity < minGlucose!.quantity {
                minGlucose = prediction
                effectedSensitivityAtMinGlucose = effectedSensitivity
            }

            let correctionUnits = insulinCorrectionUnits(
                fromValue: predictedGlucoseValue,
                toValue: targetValue,
                effectedSensitivity: Swift.max(.ulpOfOne, effectedSensitivity)
            )

            guard correctionUnits > 0 else {
                continue
            }

            // Update the correction only if we've found a new minimum
            guard minCorrectionUnits == nil || correctionUnits < minCorrectionUnits! else {
                continue
            }

            correctingGlucose = prediction
            minCorrectionUnits = correctionUnits
        }

        // Choose either the minimum glucose or eventual glucose as the correction delta
        let minGlucoseTargets = correctionRange.closestPrior(to: minGlucose.startDate)!.value
        let eventualGlucoseTargets = correctionRange.closestPrior(to: eventualGlucose.startDate)!.value

        // Treat the mininum glucose when both are below range
        if minGlucose.quantity < minGlucoseTargets.lowerBound &&
            eventualGlucose.quantity < eventualGlucoseTargets.lowerBound
        {
            let units = insulinCorrectionUnits(
                fromValue: minGlucose.quantity.doubleValue(for: unit),
                toValue: minGlucoseTargets.averageValue(for: unit),
                effectedSensitivity: Swift.max(.ulpOfOne, effectedSensitivityAtMinGlucose!)
            )

            return .entirelyBelowRange(
                min: minGlucose,
                minTarget: minGlucoseTargets.lowerBound,
                units: units
            )
        } else if eventualGlucose.quantity > eventualGlucoseTargets.upperBound,
            let minCorrectionUnits = minCorrectionUnits, let correctingGlucose = correctingGlucose
        {
            return .aboveRange(
                min: minGlucose,
                correcting: correctingGlucose,
                minTarget: eventualGlucoseTargets.lowerBound,
                units: minCorrectionUnits
            )
        } else {
            return .inRange
        }
    }
}
