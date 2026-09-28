//
//  InsulinType.swift
//  LoopAlgorithm
//
//  Created by Anna Quinlan on 12/8/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public enum FixtureInsulinType: String, Codable, CaseIterable {
    case novolog
    case humalog
    case apidra
    case fiasp
    case lyumjev
    case afrezza

    // Model-preset selections rather than brands. Tidepool Loop 1.0 had no
    // per-brand insulin types: users chose between the rapid-acting adult and
    // rapid-acting child models, so emulating it requires selecting those
    // presets directly (see AlgorithmEmulationOptions.loop1).
    case rapidActingAdult
    case rapidActingChild

    var insulinModel: InsulinModel {
        switch self {
        case .fiasp:
            return ExponentialInsulinModelPreset.fiasp
        case .lyumjev:
            return ExponentialInsulinModelPreset.lyumjev
        case .afrezza:
            return ExponentialInsulinModelPreset.afrezza
        case .rapidActingChild:
            return ExponentialInsulinModelPreset.rapidActingChild
        default:
            return ExponentialInsulinModelPreset.rapidActingAdult
        }
    }
}


