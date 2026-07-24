//
//  RetrospectiveCorrection.swift
//  Loop
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


/// Derives a continued glucose effect from recent prediction discrepancies
public protocol RetrospectiveCorrection {

    /// Overall retrospective correction effect
    var totalGlucoseCorrectionEffect: LoopQuantity? { get }

    /// Calculates overall correction effect based on timeline of discrepancies, and updates glucoseCorrectionEffect
    ///
    /// - Parameters:
    ///   - startingAt: Initial glucose value
    ///   - retrospectiveGlucoseDiscrepanciesSummed: Timeline of past discepancies
    ///   - recencyInterval: how recent discrepancy data must be, otherwise effect will be cleared
    ///   - insulinSensitivity: Insulin sensitivity at the decision time. Together with
    ///     `basalRate` and `correctionRange` this bounds the integral-correction effect
    ///     (the deployed-LoopKit safety clamp). Pass `nil` to skip the clamp.
    ///   - basalRate: Scheduled basal rate (U/hr) at the decision time. See `insulinSensitivity`.
    ///   - correctionRange: Correction range at the decision time. See `insulinSensitivity`.
    ///   - retrospectiveCorrectionGroupingInterval: Duration of discrepancy measurements
    /// - Returns: Glucose correction effects
    func computeEffect(
        startingAt startingGlucose: GlucoseValue,
        retrospectiveGlucoseDiscrepanciesSummed: [GlucoseChange]?,
        recencyInterval: TimeInterval,
        insulinSensitivity: LoopQuantity?,
        basalRate: Double?,
        correctionRange: ClosedRange<LoopQuantity>?,
        retrospectiveCorrectionGroupingInterval: TimeInterval
    ) -> [GlucoseEffect]
}
