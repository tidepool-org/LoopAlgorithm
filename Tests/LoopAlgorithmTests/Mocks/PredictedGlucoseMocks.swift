//
//  File.swift
//  
//
//  Created by Pete Schwamb on 1/11/24.
//

import XCTest
import HealthKit
@testable import LoopAlgorithm

class PredictedGlucoseMocks {

    static let testDate = ISO8601DateFormatter().date(from: "2024-01-03T12:00:00+0000")!

    var testDate: Date {
        return PredictedGlucoseMocks.testDate
    }

    static func noChangePrediction() -> [PredictedGlucoseValue] {
        return [
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0)), quantity: .glucose(100)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(6.2)), quantity: .glucose(100))
        ]
    }

    static func startHighEndInRangePrediction() -> [PredictedGlucoseValue] {
        return [
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.0)), quantity: .glucose(200)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.5)), quantity: .glucose(180)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(1.0)), quantity: .glucose(150)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(1.5)), quantity: .glucose(120)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(6.2)), quantity: .glucose(100))
        ]
    }

    static func startLowEndInRangePrediction() -> [PredictedGlucoseValue] {
        return [
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.0)), quantity: .glucose(60)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.5)), quantity: .glucose(70)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(1.0)), quantity: .glucose(80)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(1.5)), quantity: .glucose(90)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(6.2)), quantity: .glucose(100))
        ]
    }

    static func correctLowAtMin() -> [PredictedGlucoseValue] {
        return [
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.0)), quantity: .glucose(100)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.5)), quantity: .glucose(90)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(1.0)), quantity: .glucose(85)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(1.5)), quantity: .glucose(90)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(6.2)), quantity: .glucose(100))
        ]
    }

    static func startHighEndLow() -> [PredictedGlucoseValue] {
        return [
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.0)), quantity: .glucose(200)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.5)), quantity: .glucose(160)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(1.0)), quantity: .glucose(120)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(1.5)), quantity: .glucose(80)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(6.2)), quantity: .glucose(60))
        ]
    }

    static func startLowEndHigh() -> [PredictedGlucoseValue] {
        return [
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.0)), quantity: .glucose(60)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.5)), quantity: .glucose(80)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(1.0)), quantity: .glucose(120)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(1.5)), quantity: .glucose(160)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(6.2)), quantity: .glucose(200))
        ]
    }

    static func flatAndHigh() -> [PredictedGlucoseValue] {
        return [
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.0)), quantity: .glucose(200)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(6.2)), quantity: .glucose(200))
        ]
    }

    static func highAndFalling() -> [PredictedGlucoseValue] {
        return [
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.0)), quantity: .glucose(240)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(1.0)), quantity: .glucose(220)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(2.0)), quantity: .glucose(200)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(3.0)), quantity: .glucose(160)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(6.2)), quantity: .glucose(124))
        ]
    }

    static func inRangeAndRising() ->  [PredictedGlucoseValue] {
        return [
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.0)), quantity: .glucose(90)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(1.0)), quantity: .glucose(100)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(2.0)), quantity: .glucose(110)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(3.0)), quantity: .glucose(120)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(6.2)), quantity: .glucose(125))
        ]
    }

    static func highAndRising() ->  [PredictedGlucoseValue] {
        return [
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.0)), quantity: .glucose(140)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(1.0)), quantity: .glucose(150)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(2.0)), quantity: .glucose(160)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(3.0)), quantity: .glucose(170)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(6.2)), quantity: .glucose(180))
        ]
    }

    static func veryLowAndRising() ->  [PredictedGlucoseValue] {
        return [
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(0.0)), quantity: .glucose(60)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(1.0)), quantity: .glucose(50)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(2.0)), quantity: .glucose(60)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(3.0)), quantity: .glucose(70)),
            PredictedGlucoseValue(startDate: testDate.addingTimeInterval(.hours(6.2)), quantity: .glucose(100))
        ]
    }

}
