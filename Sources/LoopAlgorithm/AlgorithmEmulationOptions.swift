//
//  AlgorithmEmulationOptions.swift
//  LoopAlgorithm
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

/// Options that switch individual algorithm behaviors back to how earlier deployed
/// versions of Loop computed them, so simulators and replay tools can reproduce the
/// forecasts and dosing decisions of a specific deployed algorithm version. The
/// default value of every option preserves current LoopAlgorithm behavior.
///
/// These options exist for research and evaluation. They intentionally re-introduce
/// behaviors that were later fixed or bounded, and should not be enabled for live
/// dosing.
public struct AlgorithmEmulationOptions: Equatable, Sendable {

    /// Reproduce the pre-#35 delta-quantized basal IOB integration bound. Deployed
    /// Loop quantizes the integration upper bound to the delta grid, so a whole
    /// chunk of a basal segment's IOB is added discontinuously each time the
    /// evaluation time crosses a delta boundary — a delta-scale "ripple" on any
    /// basal segment longer than one delta. False (default) integrates continuously.
    public var legacyBasalIOB: Bool

    /// Reproduce the pre-#33 step-by-step retrospective-correction decay. #33
    /// (porting LoopKit#556) reformulated `decayEffect` as a closed-form quadratic;
    /// the two are identical for delta-aligned samples but differ for unaligned
    /// (real-CGM) timestamps. False (default) uses the continuous formulation.
    public var legacyRCDecay: Bool

    /// Apply the integral-correction clamp that deployed LoopKit's
    /// IntegralRetrospectiveCorrection uses: the wound-up integral term is bounded
    /// by an ISF×basal-scaled, correction-range-relative window. Requires the
    /// caller to supply a correction-range timeline; has no effect unless integral
    /// retrospective correction is enabled. False (default) leaves the integral
    /// term unclamped, matching the current port.
    public var integralRCClamp: Bool

    /// Disable the settings-free correction-velocity ceiling (#37) on integral
    /// retrospective correction. Deployed Loop predates that ceiling; enable this
    /// together with `integralRCClamp` for deployed-faithful IRC. False (default)
    /// keeps the ceiling.
    public var disableIRCVelocityCeiling: Bool

    public init(
        legacyBasalIOB: Bool = false,
        legacyRCDecay: Bool = false,
        integralRCClamp: Bool = false,
        disableIRCVelocityCeiling: Bool = false
    ) {
        self.legacyBasalIOB = legacyBasalIOB
        self.legacyRCDecay = legacyRCDecay
        self.integralRCClamp = integralRCClamp
        self.disableIRCVelocityCeiling = disableIRCVelocityCeiling
    }

    /// Emulate the algorithm as shipped in Tidepool Loop 1.0: the pre-extraction,
    /// in-LoopKit algorithm behavior — every legacy behavior on, every
    /// post-extraction bound off.
    ///
    /// These options cover the prediction/effects math only. Tidepool Loop 1.0
    /// also dosed exclusively by temp basal (no automatic bolus, although LoopKit
    /// supported it at the time); to reproduce that, callers should additionally
    /// set `recommendationType` to `.tempBasal`.
    public static let loop1 = AlgorithmEmulationOptions(
        legacyBasalIOB: true,
        legacyRCDecay: true,
        integralRCClamp: true,
        disableIRCVelocityCeiling: true
    )
}

extension AlgorithmEmulationOptions: Codable {
    private static let loop1PresetName = "loop-1.0"

    private enum CodingKeys: String, CodingKey {
        case legacyBasalIOB
        case legacyRCDecay
        case integralRCClamp
        case disableIRCVelocityCeiling
    }

    public init(from decoder: Decoder) throws {
        // Accept either a preset name ("loop-1.0") or an object of individual flags.
        if let container = try? decoder.singleValueContainer(), let preset = try? container.decode(String.self) {
            guard preset == Self.loop1PresetName else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown emulation preset '\(preset)'"
                ))
            }
            self = .loop1
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.legacyBasalIOB = try container.decodeIfPresent(Bool.self, forKey: .legacyBasalIOB) ?? false
        self.legacyRCDecay = try container.decodeIfPresent(Bool.self, forKey: .legacyRCDecay) ?? false
        self.integralRCClamp = try container.decodeIfPresent(Bool.self, forKey: .integralRCClamp) ?? false
        self.disableIRCVelocityCeiling = try container.decodeIfPresent(Bool.self, forKey: .disableIRCVelocityCeiling) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        if self == .loop1 {
            var container = encoder.singleValueContainer()
            try container.encode(Self.loop1PresetName)
            return
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(legacyBasalIOB, forKey: .legacyBasalIOB)
        try container.encode(legacyRCDecay, forKey: .legacyRCDecay)
        try container.encode(integralRCClamp, forKey: .integralRCClamp)
        try container.encode(disableIRCVelocityCeiling, forKey: .disableIRCVelocityCeiling)
    }
}
