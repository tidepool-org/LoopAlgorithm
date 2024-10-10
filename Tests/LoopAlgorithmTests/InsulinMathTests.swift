//
//  InsulinMathTests.swift
//  InsulinMathTests
//
//  Created by Nathan Racklyeft on 1/27/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopAlgorithm

class InsulinMathTests: XCTestCase {

    private let fixtureTimeZone = TimeZone(secondsFromGMT: -0 * 60 * 60)!

    private func printGlucoseEffect(_ insulinValues: [GlucoseEffect]) {
        print("\n\n")
        print(String(data: try! JSONSerialization.data(
            withJSONObject: insulinValues.map({ (value) -> [String: Any] in
                return [
                    "date": ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone).string(from: value.startDate),
                    "amount": value.quantity.doubleValue(for: .milligramsPerDeciliter),
                    "unit": "mg/dL"
                ]
            }),
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]), encoding: .utf8)!)
        print("\n\n")
    }


    public func loadFixture<T>(_ resourceName: String) -> T {
        let url = Bundle.module.url(forResource: resourceName, withExtension: "json", subdirectory: "Fixtures")!
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: url), options: []) as! T
    }

    func loadGlucoseEffectFixture(_ resourceName: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone)

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    func loadDoseFixtures(_ name: String) -> [FixtureInsulinDose] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
        return try! decoder.decode([FixtureInsulinDose].self, from: try! Data(contentsOf: url))
    }


    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    func testGlucoseEffectFromBolus() {

        let startDate = dateFormatter.date(from: "2015-07-13T12:02:37")!

        let input: [BasalRelativeDose] = [
            BasalRelativeDose(
                type: .bolus,
                startDate: startDate,
                endDate: startDate,
                volume: 1.5
            )
        ]

        let output = loadGlucoseEffectFixture("effect_from_bolus_output")

        let sensitivity: [AbsoluteScheduleValue<HKQuantity>] = [
            AbsoluteScheduleValue(
                startDate: startDate,
                endDate: startDate.addingTimeInterval(InsulinMath.longestInsulinActivityDuration),
                value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 40)
            )
        ]

        measure {
            _ = input.glucoseEffects(insulinSensitivityHistory: sensitivity)
        }

        let effects = input.glucoseEffects(insulinSensitivityHistory: sensitivity)

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: 1.0)
        }
    }

    func testGlucoseEffectsHistory() {
        let startDate = dateFormatter.date(from: "2015-10-15T00:00:00")!
        func t(_ offset: TimeInterval) -> Date { return startDate.addingTimeInterval(offset) }

        let doses: [BasalRelativeDose] = [
            BasalRelativeDose(type: .bolus, startDate: t(.hours(1)), endDate: t(.hours(1.1)), volume: 5),
            BasalRelativeDose(type: .bolus, startDate: t(.hours(2)), endDate: t(.hours(2.1)), volume: 5)
        ]

        let sensitivity: [AbsoluteScheduleValue<HKQuantity>] = [
            AbsoluteScheduleValue(startDate: t(.hours(1)), endDate: t(.hours(8)), value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 50))
        ]

        let effects = doses.glucoseEffects(insulinSensitivityHistory: sensitivity)

        XCTAssertEqual(effects.count, 89)
        XCTAssertEqual(effects.last!.quantity.doubleValue(for: .milligramsPerDeciliter), -500)
    }

    func testGlucoseEffectsMidAbsorptionISFTimeline() {
        let startDate = dateFormatter.date(from: "2015-10-15T00:00:00")!
        func t(_ offset: TimeInterval) -> Date { return startDate.addingTimeInterval(offset) }

        let doses: [BasalRelativeDose] = [
            BasalRelativeDose(type: .bolus, startDate: t(.hours(1)), endDate: t(.hours(1.1)), volume: 5),
            BasalRelativeDose(type: .bolus, startDate: t(.hours(2)), endDate: t(.hours(2.1)), volume: 5)
        ]

        let sensitivity: [AbsoluteScheduleValue<HKQuantity>] = [
            AbsoluteScheduleValue(startDate: t(.hours(1)), endDate: t(.hours(9)), value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 50))
        ]

        let effects = doses.glucoseEffectsMidAbsorptionISF(insulinSensitivityHistory: sensitivity)

        XCTAssertEqual(effects.count, 89)
        XCTAssertEqual(effects.last!.quantity.doubleValue(for: .milligramsPerDeciliter), -500, accuracy: 0.5)
    }

    func testGlucoseEffectFromShortTempBasal() {
        let startDate = dateFormatter.date(from: "2015-07-13T12:02:37")!
        let endDate = dateFormatter.date(from: "2015-07-13T12:07:37")!

        let input: [BasalRelativeDose] = [
            BasalRelativeDose(
                type: .basal(scheduledRate: 0.0),
                startDate: startDate,
                endDate: endDate,
                volume: 18.0 * TimeInterval.minutes(5).hours
            )
        ]

        let output = loadGlucoseEffectFixture("effect_from_bolus_output")

        let sensitivity: [AbsoluteScheduleValue<HKQuantity>] = [
            AbsoluteScheduleValue(
                startDate: startDate,
                endDate: startDate.addingTimeInterval(InsulinMath.longestInsulinActivityDuration),
                value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 40)
            )
        ]

        measure {
            _ = input.glucoseEffects(insulinSensitivityHistory: sensitivity)
        }

        let effects = input.glucoseEffects(insulinSensitivityHistory: sensitivity)

        XCTAssertEqual(output.count+1, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(
                expected.quantity.doubleValue(for: .milligramsPerDeciliter),
                calculated.quantity.doubleValue(for: .milligramsPerDeciliter),
                accuracy: 0.01)
        }
    }

    func testGlucoseEffectFromTempBasal() {
        let startDate = dateFormatter.date(from: "2015-07-13T12:00:00")!
        let endDate = dateFormatter.date(from: "2015-07-13T13:00:00")!

        let input: [BasalRelativeDose] = [
            BasalRelativeDose(
                type: .basal(scheduledRate: 1.0),
                startDate: startDate,
                endDate: endDate,
                volume: 2.0
            )
        ]

        let output = loadGlucoseEffectFixture("effect_from_basal_output")

        let sensitivity: [AbsoluteScheduleValue<HKQuantity>] = [
            AbsoluteScheduleValue(
                startDate: startDate,
                endDate: startDate.addingTimeInterval(InsulinMath.longestInsulinActivityDuration),
                value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 40)
            )
        ]

        measure {
            _ = input.glucoseEffects(insulinSensitivityHistory: sensitivity)
        }

        let effects = input.glucoseEffects(insulinSensitivityHistory: sensitivity)

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: 1.0, String(describing: expected.startDate))
        }
    }

    func testGlucoseEffectFromNoDoses() {
        let input: [BasalRelativeDose] = []

        let startDate = dateFormatter.date(from: "2015-07-13T12:00:00")!

        let sensitivity: [AbsoluteScheduleValue<HKQuantity>] = [
            AbsoluteScheduleValue(
                startDate: startDate,
                endDate: startDate.addingTimeInterval(InsulinMath.longestInsulinActivityDuration),
                value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 40)
            )
        ]

        let effects = input.glucoseEffects(insulinSensitivityHistory: sensitivity)

        XCTAssertEqual(0, effects.count)
    }

    func testGlucoseEffectFromHistory() {
        let input = loadDoseFixtures("dose_history")
        let output = loadGlucoseEffectFixture("effect_from_history_output")

        let startDate = input.last!.startDate
        let endDate = input.first!.endDate

        let sensitivity: [AbsoluteScheduleValue<HKQuantity>] = [
            AbsoluteScheduleValue(
                startDate: startDate,
                endDate: endDate.addingTimeInterval(InsulinMath.longestInsulinActivityDuration),
                value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 40)
            )
        ]

        let basal = [
            AbsoluteScheduleValue(
                startDate: startDate,
                endDate: dateFormatter.date(from: "2015-10-15T20:30:00")!,
                value: 1.0),
            AbsoluteScheduleValue(
                startDate: dateFormatter.date(from: "2015-10-15T20:30:00")!,
                endDate: dateFormatter.date(from: "2015-10-15T21:00:00")!,
                value: 0.8),
            AbsoluteScheduleValue(
                startDate: dateFormatter.date(from: "2015-10-15T21:00:00")!,
                endDate: dateFormatter.date(from: "2015-10-15T18:30:00")!,
                value: 1.0),
            AbsoluteScheduleValue(
                startDate: dateFormatter.date(from: "2015-10-15T18:30:00")!,
                endDate: dateFormatter.date(from: "2015-10-15T19:00:00")!,
                value: 0.8),
            AbsoluteScheduleValue(
                startDate: dateFormatter.date(from: "2015-10-15T19:00:00")!,
                endDate: endDate,
                value: 1.0),
        ]

        let basalRelativeDoses = input.annotated(with: basal)

        measure {
            _ = basalRelativeDoses.glucoseEffects(
                insulinSensitivityHistory: sensitivity
            )
        }

        let effects = basalRelativeDoses.glucoseEffects(
            insulinSensitivityHistory: sensitivity
        )

        printGlucoseEffect(effects)

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: 3.0)
        }
    }

    func testBasalAnnotating() {
        let startDate = dateFormatter.date(from: "2015-10-15T00:00:00")!
        func t(_ offset: TimeInterval) -> Date { return startDate.addingTimeInterval(offset) }

        let basal = [
            AbsoluteScheduleValue(
                startDate: t(.hours(0)),
                endDate: t(.hours(6)),
                value: 1.0),
            AbsoluteScheduleValue(
                startDate: t(.hours(6)),
                endDate: t(.hours(12)),
                value: 0.8)
        ]
        let doses = [
            FixtureInsulinDose(
                deliveryType: .basal,
                startDate: t(.hours(3)),
                endDate: t(.hours(3.5)),
                volume: 3 // 6 U/hr
            ),
            FixtureInsulinDose(
                deliveryType: .bolus,
                startDate: t(.hours(4.2)),
                endDate: t(.hours(4.3)),
                volume: 3
            )
        ]

        let annotated = doses.annotated(with: basal, fillBasalGaps: true)

        let expected = [
            BasalRelativeDose(
                type: .basal(
                    scheduledRate: 1.0
                ),
                startDate: t(.hours(0)),
                endDate: t(.hours(3)),
                volume: 3
            ),
            BasalRelativeDose(
                type: .basal(
                    scheduledRate: 1.0
                ),
                startDate: t(.hours(3)),
                endDate: t(.hours(3.5)),
                volume: 3
            ),
            BasalRelativeDose(
                type: .bolus,
                startDate: t(.hours(4.2)),
                endDate: t(.hours(4.3)),
                volume: 3
            ),
            BasalRelativeDose(
                type: .basal(
                    scheduledRate: 1.0
                ),
                startDate: t(.hours(3.5)),
                endDate: t(.hours(6)),
                volume: 2.5
            ),
            BasalRelativeDose(
                type: .basal(
                    scheduledRate: 0.8
                ),
                startDate: t(.hours(6)),
                endDate: t(.hours(12)),
                volume: 4.8
            )
        ]

        XCTAssertEqual(expected.count, annotated.count)

        for (expectedDose, computedDose) in zip(expected, annotated) {
            XCTAssertEqual(expectedDose.startDate, computedDose.startDate)
            XCTAssertEqual(expectedDose.endDate, computedDose.endDate)
            XCTAssertEqual(expectedDose.volume, computedDose.volume, accuracy: 0.01)
            XCTAssertEqual(expectedDose.type, computedDose.type)
        }
    }

    func testBasalAnnotatingWithNoDoses() {
        let startDate = dateFormatter.date(from: "2015-10-15T00:00:00")!
        func t(_ offset: TimeInterval) -> Date { return startDate.addingTimeInterval(offset) }

        let basal = [
            AbsoluteScheduleValue(
                startDate: t(.hours(0)),
                endDate: t(.hours(6)),
                value: 1.0),
            AbsoluteScheduleValue(
                startDate: t(.hours(6)),
                endDate: t(.hours(12)),
                value: 0.8)
        ]
        let doses: [FixtureInsulinDose] = []

        let annotated = doses.annotated(with: basal, fillBasalGaps: true)

        let expected = [
            BasalRelativeDose(
                type: .basal(
                    scheduledRate: 1.0
                ),
                startDate: t(.hours(0)),
                endDate: t(.hours(6)),
                volume: 6
            ),
            BasalRelativeDose(
                type: .basal(
                    scheduledRate: 0.8
                ),
                startDate: t(.hours(6)),
                endDate: t(.hours(12)),
                volume: 4.8
            )
        ]

        XCTAssertEqual(expected.count, annotated.count)

        for (expectedDose, computedDose) in zip(expected, annotated) {
            XCTAssertEqual(expectedDose.startDate, computedDose.startDate)
            XCTAssertEqual(expectedDose.endDate, computedDose.endDate)
            XCTAssertEqual(expectedDose.volume, computedDose.volume, accuracy: 0.01)
            XCTAssertEqual(expectedDose.type, computedDose.type)
        }
    }


    func testInsulinOnBoardTimeline() {
        let start = dateFormatter.date(from: "2015-10-15T19:00:00")!
        let doses = [
            BasalRelativeDose(type: .bolus, startDate: start, endDate: start.addingTimeInterval(.minutes(1)), volume: 2)
        ]
        let timeline = doses.insulinOnBoardTimeline()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let url = Bundle.module.url(forResource: "iob_timeline", withExtension: "json", subdirectory: "Fixtures")!
        let expectedValues = try! decoder.decode([InsulinValue].self, from: try! Data(contentsOf: url))

        XCTAssertEqual(timeline, expectedValues)
    }

}
