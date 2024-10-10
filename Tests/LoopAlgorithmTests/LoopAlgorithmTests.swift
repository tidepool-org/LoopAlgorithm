//
//  LoopAlgorithmTests.swift
//  LoopAlgorithmTests
//
//  Created by Pete Schwamb on 10/18/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopAlgorithm

final class LoopAlgorithmTests: XCTestCase {

    func loadScenario(_ name: String) -> (input: AlgorithmInputFixture, recommendation: LoopAlgorithmDoseRecommendation) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var url = Bundle.module.url(forResource: name + "_scenario", withExtension: "json", subdirectory: "Fixtures")!
        let input = try! decoder.decode(AlgorithmInputFixture.self, from: try! Data(contentsOf: url))

        url = Bundle.module.url(forResource: name + "_recommendation", withExtension: "json", subdirectory: "Fixtures")!
        let recommendation = try! decoder.decode(LoopAlgorithmDoseRecommendation.self, from: try! Data(contentsOf: url))

        return (input: input, recommendation: recommendation)
    }

    func testSuspend() throws {

        let (input, recommendation) = loadScenario("suspend")

        let output = LoopAlgorithm.run(input: input)

        XCTAssertEqual(output.recommendation, recommendation)
    }

    func loadPredictedGlucoseFixture(_ name: String) -> [PredictedGlucoseValue] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
        return try! decoder.decode([PredictedGlucoseValue].self, from: try! Data(contentsOf: url))
    }

    func testCarbsWithSensitivityChange() throws {

        // This test computes a dose with a future carb entry
        // Between the time of dose and the startTime of the carb
        // There is a significant ISF change (from 35 mg/dL/U to 60 mg/dL/U)

        let (input, recommendation) = loadScenario("carbs_with_isf_change")

        let output = LoopAlgorithm.run(input: input)

        XCTAssertEqual(output.recommendation, recommendation)
    }

    func testAlgorithmWithLongAbsorbingCarbs() throws {
        let now = ISO8601DateFormatter().date(from: "2024-01-03T12:00:00+0000")!
        var input = AlgorithmInputFixture.mock(for: now)
        input.recommendationType = .manualBolus
        input.carbEntries.append(FixtureCarbEntry(absorptionTime: .hours(6), startDate: now, quantity: .carbs(value: 50)))

        let output = LoopAlgorithm.run(input: input)

        XCTAssertEqual(output.activeCarbs, 50)
        XCTAssertEqual(output.recommendation!.manual!.amount, 5.83, accuracy: 0.01)
    }


    func testAlgorithmShouldBeDateIndependent() throws {
        let now = Date()
        var a = AlgorithmInputFixture.mock(for: now)
        var b = AlgorithmInputFixture.mock(for: now.addingTimeInterval(.minutes(-2.5)))

        a.carbEntries.append(
            FixtureCarbEntry(
                startDate: a.predictionStart.addingTimeInterval(-.minutes(30)),
                quantity: .carbs(value: 10)
            )
        )

        b.carbEntries.append(
            FixtureCarbEntry(
                startDate: b.predictionStart.addingTimeInterval(-.minutes(30)),
                quantity: .carbs(value: 10)
            )
        )


        let outputA = LoopAlgorithm.run(input: a)
        let outputB = LoopAlgorithm.run(input: b)

        XCTAssertEqual(outputA.activeCarbs, outputB.activeCarbs)
        XCTAssertEqual(outputA.activeInsulin, outputB.activeInsulin)

        XCTAssertEqual(outputA.effects.carbs.last?.quantity.doubleValue(for: .milligramsPerDeciliter), 55.0)
        XCTAssertEqual(outputB.effects.carbs.last?.quantity.doubleValue(for: .milligramsPerDeciliter), 55.0)

        XCTAssertEqual(outputA.effects.insulin.last?.quantity.doubleValue(for: .milligramsPerDeciliter), 0.0)
        XCTAssertEqual(outputB.effects.insulin.last?.quantity.doubleValue(for: .milligramsPerDeciliter), 0.0)

        XCTAssertEqual(outputA.effects.retrospectiveCorrection.last?.quantity.doubleValue(for: .milligramsPerDeciliter), 165)
        XCTAssertEqual(outputB.effects.retrospectiveCorrection.last?.quantity.doubleValue(for: .milligramsPerDeciliter), 165)

        // Even though all the input data is the same (just shifted in time), momentum effect varies in relation to how offset
        // the glucose samples are from the simulation timeline (at exact 5 minute intervals from the top of the hour)
//        XCTAssertEqual(outputA.effects.momentum.last?.quantity.doubleValue(for: .milligramsPerDeciliter), 0.0)
//        XCTAssertEqual(outputB.effects.momentum.last?.quantity.doubleValue(for: .milligramsPerDeciliter), 0.0)
//
//        XCTAssertEqual(outputA.predictedGlucose.last!.quantity.doubleValue(for: .milligramsPerDeciliter), 283.7, accuracy: 0.01)
//        XCTAssertEqual(outputB.predictedGlucose.last!.quantity.doubleValue(for: .milligramsPerDeciliter), 283.7, accuracy: 0.01)
    }


    func testObservedProgressForCarbStatus() throws {
        let date = ISO8601DateFormatter().date(from: "2024-01-03T12:00:00+0000")!
        var input = AlgorithmInputFixture.mock(for: date)

        let now = input.predictionStart

        // Add carbs (20g should be 2U at 10g/U)
        input.carbEntries.append(
            FixtureCarbEntry(
                startDate: now.addingTimeInterval(-.minutes(30)),
                quantity: .carbs(value: 20)
            )
        )

        // Rising BG from carb absorption
        input.glucoseHistory = [
            FixtureGlucoseSample(startDate: now.addingTimeInterval(.minutes(-18)), quantity: .glucose(value: 105)),
            FixtureGlucoseSample(startDate: now.addingTimeInterval(.minutes(-13)), quantity: .glucose(value: 115)),
            FixtureGlucoseSample(startDate: now.addingTimeInterval(.minutes(-8)), quantity: .glucose(value: 120)),
            FixtureGlucoseSample(startDate: now.addingTimeInterval(.minutes(-3)), quantity: .glucose(value: 145)),
        ]

        let output = LoopAlgorithm.run(input: input)

        let carbStatus = output.effects.carbStatus.first!
        XCTAssertEqual(carbStatus.absorption!.observedProgress.doubleValue(for: .percent()), 0.36, accuracy: 0.01)

        XCTAssert(carbStatus.absorption!.isActive)

        let basalAdjustment = output.recommendation!.automatic!.basalAdjustment

        XCTAssertEqual(basalAdjustment!.unitsPerHour, 5.83, accuracy: 0.01)
    }

    func testLiveCapture() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let url = Bundle.module.url(forResource: "live_capture_input", withExtension: "json", subdirectory: "Fixtures")!
        let input = try! decoder.decode(LoopPredictionInput.self, from: try! Data(contentsOf: url))

        let prediction = LoopAlgorithm.generatePrediction(
            start: input.glucoseHistory.last?.startDate ?? Date(),
            glucoseHistory: input.glucoseHistory,
            doses: input.doses,
            carbEntries: input.carbEntries,
            basal: input.basal,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection
        )

        let expectedPredictedGlucose = loadPredictedGlucoseFixture("live_capture_predicted_glucose")

        XCTAssertEqual(expectedPredictedGlucose.count, prediction.glucose.count)

        let defaultAccuracy = 1.0 / 40.0

        for (expected, calculated) in zip(expectedPredictedGlucose, prediction.glucose) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }
    }

    func testMidAborptionISFFlag() {
        let now = ISO8601DateFormatter().date(from: "2024-01-03T00:00:00+0000")!
        var input = AlgorithmInputFixture.mock(for: now)

        input.doses = [
            FixtureInsulinDose(deliveryType: .bolus, startDate: now, endDate: now.addingTimeInterval(20), volume: 1)
        ]

        let isfStart = now.addingTimeInterval(.hours(-10))
        let isfMid = now.addingTimeInterval(.hours(1.5))
        let isfEnd = now.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration).dateCeiledToTimeInterval(GlucoseMath.defaultDelta)

        // ISF Changing mid-aborption
        input.sensitivity = [
            AbsoluteScheduleValue(startDate: isfStart, endDate: isfMid, value: .glucose(value: 50)),
            AbsoluteScheduleValue(startDate: isfMid, endDate: isfEnd, value: .glucose(value: 100))
        ]

        // With Mid-absorption ISF flag = false
        var output = LoopAlgorithm.run(input: input)
        XCTAssertEqual(output.effects.insulin.last!.quantity.doubleValue(for: .milligramsPerDeciliter), -50)

        // With Mid-absorption ISF flag = true
        input.useMidAbsorptionISF = true
        output = LoopAlgorithm.run(input: input)
        XCTAssertEqual(output.effects.insulin.last!.quantity.doubleValue(for: .milligramsPerDeciliter), -83, accuracy: 0.5)
    }

    func testAutoBolusMaxIOBClamping() async {
        let now = ISO8601DateFormatter().date(from: "2020-03-11T12:13:14-0700")!

        var input = AlgorithmInputFixture.mock(for: now)
        input.recommendationType = .automaticBolus

        // 8U bolus on board, and 100g carbs; CR = 10, so that should be 10U to cover the carbs
        input.doses = [FixtureInsulinDose(
            deliveryType: .bolus,
            startDate: now.addingTimeInterval(-.minutes(5)),
            endDate: now.addingTimeInterval(-.minutes(4)),
            volume: 8
        )]
        input.carbEntries = [
            FixtureCarbEntry(startDate: now.addingTimeInterval(.minutes(-5)), quantity: .carbs(value: 100))
        ]

        // Max activeInsulin = 2 x maxBolus = 16U
        input.maxBolus = 8
        var output = LoopAlgorithm.run(input: input)
        var recommendedBolus = output.recommendation!.automatic?.bolusUnits
        var activeInsulin = output.activeInsulin!
        XCTAssertEqual(activeInsulin, 8.0)
        XCTAssertEqual(recommendedBolus!, 1.66, accuracy: 0.01)

        // Now try with maxBolus of 4; should not recommend any more insulin, as we're at our max iob
        input.maxBolus = 4
        output = LoopAlgorithm.run(input: input)
        recommendedBolus = output.recommendation!.automatic?.bolusUnits
        activeInsulin = output.activeInsulin!
        XCTAssertEqual(activeInsulin, 8.0)
        XCTAssertEqual(recommendedBolus!, 0, accuracy: 0.01)
    }

    func testTempBasalMaxIOBClamping() {
        let now = ISO8601DateFormatter().date(from: "2020-03-11T12:13:14-0700")!

        var input = AlgorithmInputFixture.mock(for: now)
        input.recommendationType = .tempBasal

        // 8U bolus on board, and 100g carbs; CR = 10, so that should be 10U to cover the carbs
        input.doses = [FixtureInsulinDose(
            deliveryType: .bolus,
            startDate: now.addingTimeInterval(-.minutes(5)),
            endDate: now.addingTimeInterval(-.minutes(4)),
            volume: 8
        )]

        input.carbEntries = [
            FixtureCarbEntry(startDate: now.addingTimeInterval(.minutes(-5)), quantity: .carbs(value: 100))
        ]

        // Max activeInsulin = 2 x maxBolus = 16U
        input.maxBolus = 8
        var output = LoopAlgorithm.run(input: input)
        var recommendedRate = output.recommendation!.automatic!.basalAdjustment!.unitsPerHour
        var activeInsulin = output.activeInsulin!
        XCTAssertEqual(activeInsulin, 8.0)
        XCTAssertEqual(recommendedRate, 8.0, accuracy: 0.01)

        // Now try with maxBolus of 4; should only recommend scheduled basal (1U/hr), as we're at our max iob
        input.maxBolus = 4
        output = LoopAlgorithm.run(input: input)
        recommendedRate = output.recommendation!.automatic!.basalAdjustment!.unitsPerHour
        activeInsulin = output.activeInsulin!
        XCTAssertEqual(activeInsulin, 8.0)
        XCTAssertEqual(recommendedRate, 1.0, accuracy: 0.01)
    }

}
