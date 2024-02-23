//
//  CorrectionDosingTests.swift
//  
//
//  Created by Nathan Racklyeft on 3/8/16.
//  Copyright © 2016 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopAlgorithm

class CorrectionDosingTests: XCTestCase {

    var testDate: Date {
        return PredictedGlucoseMocks.testDate
    }

    let suspendThreshold: HKQuantity = .glucose(value: 55)
    let maxBasalRate = 3.0

    var target: GlucoseRangeTimeline!
    var sensitivity: [AbsoluteScheduleValue<HKQuantity>]!
    let basalRate = 1.0
    let insulinModel = ExponentialInsulinModelPreset.rapidActingAdult

    override func setUp() {
        let lowerBound: HKQuantity = .glucose(value: 90)
        let upperBound: HKQuantity = .glucose(value: 120)

        target = [AbsoluteScheduleValue(
            startDate: testDate.addingTimeInterval(.hours(-24)),
            endDate: testDate.addingTimeInterval(.hours(24)),
            value: lowerBound...upperBound
        )]

        sensitivity = [AbsoluteScheduleValue(
            startDate: testDate.addingTimeInterval(.hours(-24)),
            endDate: testDate.addingTimeInterval(.hours(24)),
            value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 60)
        )]
    }



    func testNoChange() {
        let correction = LoopAlgorithm.insulinCorrection(
            prediction: PredictedGlucoseMocks.noChangePrediction(),
            at: testDate,
            target: target,
            suspendThreshold: suspendThreshold,
            sensitivity: sensitivity,
            insulinModel: insulinModel
        )

        let recommendation = LoopAlgorithm.recommendTempBasal(
            for: correction,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(recommendation?.unitsPerHour, basalRate)
        XCTAssertEqual(recommendation?.duration, .minutes(30))

        let automaticDose = LoopAlgorithm.recommendAutomaticDose(
            for: correction,
            applicationFactor: 0.5,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(automaticDose?.bolusUnits, 0)
        XCTAssertEqual(automaticDose?.basalAdjustment?.unitsPerHour, basalRate)

        let manualDose = LoopAlgorithm.recommendManualBolus(
            for: correction,
            maxBolus: 6,
            currentGlucose: FixtureGlucoseSample(startDate: PredictedGlucoseMocks.testDate, quantity: .glucose(value: 120)),
            target: target
        )

        XCTAssertEqual(manualDose.amount, 0)
        XCTAssertEqual(manualDose.notice, .predictedGlucoseInRange)
    }

    func testStartHighEndInRange() {
        let correction = LoopAlgorithm.insulinCorrection(
            prediction: PredictedGlucoseMocks.startHighEndInRangePrediction(),
            at: testDate,
            target: target,
            suspendThreshold: suspendThreshold,
            sensitivity: sensitivity,
            insulinModel: insulinModel
        )

        let recommendation = LoopAlgorithm.recommendTempBasal(
            for: correction,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(recommendation?.unitsPerHour, basalRate)
        XCTAssertEqual(recommendation?.duration, .minutes(30))

        let automaticDose = LoopAlgorithm.recommendAutomaticDose(
            for: correction,
            applicationFactor: 0.5,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(automaticDose?.bolusUnits, 0)
        XCTAssertEqual(automaticDose?.basalAdjustment?.unitsPerHour, basalRate)

        let manualDose = LoopAlgorithm.recommendManualBolus(
            for: correction,
            maxBolus: 6,
            currentGlucose: FixtureGlucoseSample(startDate: PredictedGlucoseMocks.testDate, quantity: .glucose(value: 120)),
            target: target
        )

        XCTAssertEqual(manualDose.amount, 0)
        XCTAssertEqual(manualDose.notice, .predictedGlucoseInRange)
    }

    func testStartLowEndInRange() {
        let correction = LoopAlgorithm.insulinCorrection(
            prediction: PredictedGlucoseMocks.startLowEndInRangePrediction(),
            at: testDate,
            target: target,
            suspendThreshold: suspendThreshold,
            sensitivity: sensitivity,
            insulinModel: insulinModel
        )

        let recommendation = LoopAlgorithm.recommendTempBasal(
            for: correction,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(recommendation?.unitsPerHour, 1)
        XCTAssertEqual(recommendation?.duration, .minutes(30))

        let automaticDose = LoopAlgorithm.recommendAutomaticDose(
            for: correction,
            applicationFactor: 0.4,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(automaticDose?.bolusUnits, 0)
        XCTAssertEqual(automaticDose?.basalAdjustment?.unitsPerHour, basalRate)
        XCTAssertEqual(automaticDose?.basalAdjustment?.duration, .minutes(30))

        let manualDose = LoopAlgorithm.recommendManualBolus(
            for: correction,
            maxBolus: 6,
            currentGlucose: FixtureGlucoseSample(startDate: PredictedGlucoseMocks.testDate, quantity: .glucose(value: 120)),
            target: target
        )

        XCTAssertEqual(manualDose.amount, 0)
        XCTAssertEqual(manualDose.notice, .predictedGlucoseInRange)
    }

    func testCorrectLowAtMin() {
        let correction = LoopAlgorithm.insulinCorrection(
            prediction: PredictedGlucoseMocks.correctLowAtMin(),
            at: testDate,
            target: target,
            suspendThreshold: suspendThreshold,
            sensitivity: sensitivity,
            insulinModel: insulinModel
        )

        let recommendation = LoopAlgorithm.recommendTempBasal(
            for: correction,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(recommendation?.unitsPerHour, 1)
        XCTAssertEqual(recommendation?.duration, .minutes(30))

        let automaticDose = LoopAlgorithm.recommendAutomaticDose(
            for: correction,
            applicationFactor: 0.4,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(automaticDose?.bolusUnits, 0)
        XCTAssertEqual(automaticDose?.basalAdjustment?.unitsPerHour, basalRate)
        XCTAssertEqual(automaticDose?.basalAdjustment?.duration, .minutes(30))

        let manualDose = LoopAlgorithm.recommendManualBolus(
            for: correction,
            maxBolus: 6,
            currentGlucose: FixtureGlucoseSample(startDate: PredictedGlucoseMocks.testDate, quantity: .glucose(value: 120)),
            target: target
        )

        XCTAssertEqual(manualDose.amount, 0)
        XCTAssertEqual(manualDose.notice, .predictedGlucoseInRange)
    }


    func testStartHighEndLow() {
        let correction = LoopAlgorithm.insulinCorrection(
            prediction: PredictedGlucoseMocks.startHighEndLow(),
            at: testDate,
            target: target,
            suspendThreshold: suspendThreshold,
            sensitivity: sensitivity,
            insulinModel: insulinModel
        )

        let recommendation = LoopAlgorithm.recommendTempBasal(
            for: correction,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(recommendation?.unitsPerHour, 0)
        XCTAssertEqual(recommendation?.duration, .minutes(30))

        let automaticDose = LoopAlgorithm.recommendAutomaticDose(
            for: correction,
            applicationFactor: 0.4,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(automaticDose?.bolusUnits, 0)
        XCTAssertEqual(automaticDose?.basalAdjustment?.unitsPerHour, 0)
        XCTAssertEqual(automaticDose?.basalAdjustment?.duration, .minutes(30))

        let manualDose = LoopAlgorithm.recommendManualBolus(
            for: correction,
            maxBolus: 6,
            currentGlucose: FixtureGlucoseSample(startDate: PredictedGlucoseMocks.testDate, quantity: .glucose(value: 120)),
            target: target
        )

        XCTAssertEqual(manualDose.amount, 0)
        if case .allGlucoseBelowTarget(minGlucose: let glucose) = manualDose.notice {
            XCTAssertEqual(60, glucose.quantity.doubleValue(for: .milligramsPerDeciliter))
        } else {
            XCTFail("Wrong .notice: \(String(describing: manualDose.notice))")
        }
    }

    func testStartLowEndHigh() {
        let correction = LoopAlgorithm.insulinCorrection(
            prediction: PredictedGlucoseMocks.startLowEndHigh(),
            at: testDate,
            target: target,
            suspendThreshold: suspendThreshold,
            sensitivity: sensitivity,
            insulinModel: insulinModel
        )

        let recommendation = LoopAlgorithm.recommendTempBasal(
            for: correction,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(recommendation?.unitsPerHour, 1.0)
        XCTAssertEqual(recommendation?.duration, .minutes(30))

        let automaticDose = LoopAlgorithm.recommendAutomaticDose(
            for: correction,
            applicationFactor: 0.4,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(automaticDose?.bolusUnits, 0)
        XCTAssertEqual(automaticDose?.basalAdjustment?.unitsPerHour, basalRate)
        XCTAssertEqual(automaticDose?.basalAdjustment?.duration, .minutes(30))

        let manualDose = LoopAlgorithm.recommendManualBolus(
            for: correction,
            maxBolus: 6,
            currentGlucose: FixtureGlucoseSample(startDate: PredictedGlucoseMocks.testDate, quantity: .glucose(value: 120)),
            target: target
        )

        XCTAssertEqual(manualDose.amount, 1.6, accuracy: 0.05)
        if case .predictedGlucoseBelowTarget(minGlucose: let glucose) = manualDose.notice {
            XCTAssertEqual(60, glucose.quantity.doubleValue(for: .milligramsPerDeciliter))
        } else {
            XCTFail("Wrong .notice: \(String(describing: manualDose.notice))")
        }
    }

    func testFlatAndHigh() {
        let correction = LoopAlgorithm.insulinCorrection(
            prediction: PredictedGlucoseMocks.flatAndHigh(),
            at: testDate,
            target: target,
            suspendThreshold: suspendThreshold,
            sensitivity: sensitivity,
            insulinModel: insulinModel
        )

        let recommendation = LoopAlgorithm.recommendTempBasal(
            for: correction,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(recommendation?.unitsPerHour, 3.0)
        XCTAssertEqual(recommendation?.duration, .minutes(30))

        let automaticDose = LoopAlgorithm.recommendAutomaticDose(
            for: correction,
            applicationFactor: 0.4,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(automaticDose!.bolusUnits!, 0.65, accuracy: 0.05)
        XCTAssertEqual(automaticDose?.basalAdjustment?.unitsPerHour, basalRate)
        XCTAssertEqual(automaticDose?.basalAdjustment?.duration, .minutes(30))

        let manualDose = LoopAlgorithm.recommendManualBolus(
            for: correction,
            maxBolus: 6,
            currentGlucose: FixtureGlucoseSample(startDate: PredictedGlucoseMocks.testDate, quantity: .glucose(value: 120)),
            target: target
        )

        XCTAssertEqual(manualDose.amount, 1.6, accuracy: 0.05)
        XCTAssertNil(manualDose.notice)
    }


    func testHighAndFalling() {
        let correction = LoopAlgorithm.insulinCorrection(
            prediction: PredictedGlucoseMocks.highAndFalling(),
            at: testDate,
            target: target,
            suspendThreshold: suspendThreshold,
            sensitivity: sensitivity,
            insulinModel: insulinModel
        )

        let recommendation = LoopAlgorithm.recommendTempBasal(
            for: correction,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(recommendation!.unitsPerHour, 1.63, accuracy: 0.05)
        XCTAssertEqual(recommendation?.duration, .minutes(30))

        let automaticDose = LoopAlgorithm.recommendAutomaticDose(
            for: correction,
            applicationFactor: 0.4,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(automaticDose!.bolusUnits!, 0.10, accuracy: 0.05)
        XCTAssertEqual(automaticDose?.basalAdjustment?.unitsPerHour, basalRate)
        XCTAssertEqual(automaticDose?.basalAdjustment?.duration, .minutes(30))

        let manualDose = LoopAlgorithm.recommendManualBolus(
            for: correction,
            maxBolus: 6,
            currentGlucose: FixtureGlucoseSample(startDate: PredictedGlucoseMocks.testDate, quantity: .glucose(value: 120)),
            target: target
        )

        XCTAssertEqual(manualDose.amount, 0.30, accuracy: 0.05)
        XCTAssertNil(manualDose.notice)
    }

    func testInRangeAndRising() {
        let correction = LoopAlgorithm.insulinCorrection(
            prediction: PredictedGlucoseMocks.inRangeAndRising(),
            at: testDate,
            target: target,
            suspendThreshold: suspendThreshold,
            sensitivity: sensitivity,
            insulinModel: insulinModel
        )

        let recommendation = LoopAlgorithm.recommendTempBasal(
            for: correction,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(recommendation!.unitsPerHour, 1.63, accuracy: 0.05)
        XCTAssertEqual(recommendation?.duration, .minutes(30))

        let automaticDose = LoopAlgorithm.recommendAutomaticDose(
            for: correction,
            applicationFactor: 0.4,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(automaticDose!.bolusUnits!, 0.10, accuracy: 0.05)
        XCTAssertEqual(automaticDose?.basalAdjustment?.unitsPerHour, basalRate)
        XCTAssertEqual(automaticDose?.basalAdjustment?.duration, .minutes(30))

        let manualDose = LoopAlgorithm.recommendManualBolus(
            for: correction,
            maxBolus: 6,
            currentGlucose: FixtureGlucoseSample(startDate: PredictedGlucoseMocks.testDate, quantity: .glucose(value: 120)),
            target: target
        )

        XCTAssertEqual(manualDose.amount, 0.30, accuracy: 0.05)
        XCTAssertNil(manualDose.notice)
    }

    func testHighAndRising() {
        let correction = LoopAlgorithm.insulinCorrection(
            prediction: PredictedGlucoseMocks.highAndRising(),
            at: testDate,
            target: target,
            suspendThreshold: suspendThreshold,
            sensitivity: sensitivity,
            insulinModel: insulinModel
        )

        let recommendation = LoopAlgorithm.recommendTempBasal(
            for: correction,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(recommendation!.unitsPerHour, 3.0, accuracy: 0.05)
        XCTAssertEqual(recommendation?.duration, .minutes(30))

        let automaticDose = LoopAlgorithm.recommendAutomaticDose(
            for: correction,
            applicationFactor: 0.4,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(automaticDose!.bolusUnits!, 0.5, accuracy: 0.05)
        XCTAssertEqual(automaticDose?.basalAdjustment?.unitsPerHour, basalRate)
        XCTAssertEqual(automaticDose?.basalAdjustment?.duration, .minutes(30))

        let manualDose = LoopAlgorithm.recommendManualBolus(
            for: correction,
            maxBolus: 6,
            currentGlucose: FixtureGlucoseSample(startDate: PredictedGlucoseMocks.testDate, quantity: .glucose(value: 120)),
            target: target
        )

        XCTAssertEqual(manualDose.amount, 1.25, accuracy: 0.05)
        XCTAssertNil(manualDose.notice)
    }

    func testVeryLowAndRising() {
        let correction = LoopAlgorithm.insulinCorrection(
            prediction: PredictedGlucoseMocks.veryLowAndRising(),
            at: testDate,
            target: target,
            suspendThreshold: suspendThreshold,
            sensitivity: sensitivity,
            insulinModel: insulinModel
        )

        let recommendation = LoopAlgorithm.recommendTempBasal(
            for: correction,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(recommendation!.unitsPerHour, 0, accuracy: 0.05)
        XCTAssertEqual(recommendation?.duration, .minutes(30))

        let automaticDose = LoopAlgorithm.recommendAutomaticDose(
            for: correction,
            applicationFactor: 0.4,
            neutralBasalRate: basalRate,
            activeInsulin: 0,
            maxBolus: 6,
            maxBasalRate: maxBasalRate
        )

        XCTAssertEqual(automaticDose!.bolusUnits!, 0.0, accuracy: 0.05)
        XCTAssertEqual(automaticDose?.basalAdjustment?.unitsPerHour, 0)
        XCTAssertEqual(automaticDose?.basalAdjustment?.duration, .minutes(30))

        let manualDose = LoopAlgorithm.recommendManualBolus(
            for: correction,
            maxBolus: 6,
            currentGlucose: FixtureGlucoseSample(startDate: PredictedGlucoseMocks.testDate, quantity: .glucose(value: 120)),
            target: target
        )

        XCTAssertEqual(manualDose.amount, 0, accuracy: 0.05)
        if case .glucoseBelowSuspendThreshold(minGlucose: let glucose) = manualDose.notice {
            XCTAssertEqual(50, glucose.quantity.doubleValue(for: .milligramsPerDeciliter))
        } else {
            XCTFail("Wrong .notice: \(String(describing: manualDose.notice))")
        }
    }
}
