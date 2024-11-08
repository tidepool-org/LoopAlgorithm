//
//  GlucoseEffect.swift
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public struct GlucoseEffect: GlucoseValue, Equatable {
    public let startDate: Date
    public let quantity: LoopQuantity

    public init(startDate: Date, quantity: LoopQuantity) {
        self.startDate = startDate
        self.quantity = quantity
    }
}

extension GlucoseEffect: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(startDate: try container.decode(Date.self, forKey: .startDate),
                  quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: try container.decode(Double.self, forKey: .quantity)))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(quantity.doubleValue(for: .milligramsPerDeciliter), forKey: .quantity)
    }

    private enum CodingKeys: String, CodingKey {
        case startDate
        case quantity
    }
}


extension GlucoseEffect: Comparable {
    public static func <(lhs: GlucoseEffect, rhs: GlucoseEffect) -> Bool {
        return lhs.startDate < rhs.startDate
    }
}
