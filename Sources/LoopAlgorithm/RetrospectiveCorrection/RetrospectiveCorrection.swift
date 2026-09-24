//
//  RetrospectiveCorrection.swift
//  Loop
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


/// Decision-time settings for the integral-correction clamp that deployed
/// LoopKit's IntegralRetrospectiveCorrection applies: the wound-up integral term
/// is bounded by an ISF×basal-scaled, correction-range-relative window. All three
/// values are required for the bound to be well defined, so they travel together.
public struct IntegralRCClampSettings {
    /// Insulin sensitivity at decision time
    public var insulinSensitivity: LoopQuantity
    /// Scheduled basal rate at decision time, in U/hr
    public var basalRate: Double
    /// Correction range at decision time
    public var correctionRange: ClosedRange<LoopQuantity>

    public init(insulinSensitivity: LoopQuantity, basalRate: Double, correctionRange: ClosedRange<LoopQuantity>) {
        self.insulinSensitivity = insulinSensitivity
        self.basalRate = basalRate
        self.correctionRange = correctionRange
    }
}

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
    ///   - integralClamp: Settings for the integral-correction clamp. Ignored by StandardRetrospectiveCorrection; when nil, IntegralRetrospectiveCorrection skips the clamp.
    ///   - retrospectiveCorrectionGroupingInterval: Duration of discrepancy measurements
    /// - Returns: Glucose correction effects
    func computeEffect(
        startingAt startingGlucose: GlucoseValue,
        retrospectiveGlucoseDiscrepanciesSummed: [GlucoseChange]?,
        recencyInterval: TimeInterval,
        integralClamp: IntegralRCClampSettings?,
        retrospectiveCorrectionGroupingInterval: TimeInterval
    ) -> [GlucoseEffect]
}
