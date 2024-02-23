//
//  InsulinDose.swift
//
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit


public protocol InsulinDose: TimelineValue {
    var deliveryType: InsulinDeliveryType { get }
    var startDate: Date { get }
    var endDate: Date { get }
    var volume: Double { get }
    var insulinModel: InsulinModel { get }
}

extension InsulinDose {
    public var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }

    var unitsPerHour: Double {
        return volume / duration.hours
    }

}
