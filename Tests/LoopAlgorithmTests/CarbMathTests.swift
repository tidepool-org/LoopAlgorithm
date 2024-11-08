//
//  CarbMathTests.swift
//  CarbKitTests
//
//  Created by Nathan Racklyeft on 1/18/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopAlgorithm

public typealias JSONDictionary = [String: Any]

class CarbMathTests: XCTestCase {

    public func loadFixture<T>(_ resourceName: String) -> T {
        let url = Bundle.module.url(forResource: resourceName, withExtension: "json", subdirectory: "Fixtures")!
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: url), options: []) as! T
    }

    private func loadEffectOutputFixture(_ name: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(name)
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: TimeZone(secondsFromGMT: 0)!)

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: LoopQuantity(unit: LoopUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    private func loadCOBOutputFixture(_ name: String) -> [CarbValue] {
        let fixture: [JSONDictionary] = loadFixture(name)
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: TimeZone(secondsFromGMT: 0)!)

        return fixture.map {
            return CarbValue(startDate: dateFormatter.date(from: $0["date"] as! String)!, value: $0["amount"] as! Double)
        }
    }

    private func loadHistoryFixture(_ name: String) -> [FixtureCarbEntry] {
        let fixture: [JSONDictionary] = loadFixture(name)
        return carbEntriesFromFixture(fixture)
    }

    private func loadCarbEntryFixture() -> [FixtureCarbEntry] {
        let fixture: [JSONDictionary] = loadFixture("carb_entry_input")
        return carbEntriesFromFixture(fixture)
    }

    private func carbEntriesFromFixture(_ fixture: [JSONDictionary]) -> [FixtureCarbEntry] {
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: TimeZone(secondsFromGMT: 0)!)

        return fixture.map {
            let absorptionTime: TimeInterval?
            if let absorptionTimeMinutes = $0["absorption_time"] as? Double {
                absorptionTime = TimeInterval(minutes: absorptionTimeMinutes)
            } else {
                absorptionTime = nil
            }
            let startAt = dateFormatter.date(from: $0["start_at"] as! String)!
            return FixtureCarbEntry(
                absorptionTime: absorptionTime,
                startDate: startAt,
                quantity: LoopQuantity(unit: LoopUnit(from: $0["unit"] as! String), doubleValue: $0["amount"] as! Double)
            )
        }
    }


    private func loadICEInputFixture(_ name: String) -> [GlucoseEffectVelocity] {
        let fixture: [JSONDictionary] = loadFixture(name)
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: TimeZone(secondsFromGMT: 0)!)

        let unit = LoopUnit.milligramsPerDeciliterPerMinute

        return fixture.map {
            let quantity = LoopQuantity(unit: unit, doubleValue: $0["velocity"] as! Double)
            return GlucoseEffectVelocity(
                startDate: dateFormatter.date(from: $0["start_at"] as! String)!,
                endDate: dateFormatter.date(from: $0["end_at"] as! String)!,
                quantity: quantity)
        }
    }

    func testCarbEffectWithZeroEntry() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        let startDate = inputICE[0].startDate // "2015-10-15T21:30:12"
        let endDate = inputICE.last!.startDate
        let carbEntry = FixtureCarbEntry(
            absorptionTime: .minutes(120),
            startDate: startDate,
            quantity: LoopQuantity(unit: LoopUnit.gram, doubleValue: 0)
        )

        let carbRatio = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 8.0)]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let statuses = [carbEntry].map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf,
            absorptionModel: LinearAbsorption()
        )

        XCTAssertEqual(statuses.count, 1)
        XCTAssertEqual(statuses[0].absorption?.estimatedTimeRemaining, 0)
    }

    func testDynamicGlucoseEffectAbsorptionNoneObserved() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadEffectOutputFixture("dynamic_glucose_effect_none_observed_output")

        let startDate = inputICE[0].startDate // "2015-10-15T21:30:12"
        let endDate = inputICE.last!.startDate

        let carbRatio = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 9.0)]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let futureCarbEntry = carbEntries[2]

        let statuses = [futureCarbEntry].map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf,
            initialAbsorptionTimeOverrun: 2.0,
            absorptionModel: LinearAbsorption()
        )

        XCTAssertEqual(statuses.count, 1)

        // Full absorption remains
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, TimeInterval(hours: 4), accuracy: 1)

        let effects = statuses.dynamicGlucoseEffects(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            carbRatios: carbRatio,
            insulinSensitivities: isf,
            absorptionModel: LinearAbsorption(),
            delay: 0
        )

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testDynamicAbsorptionNoneObserved() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_35_min_none_output")

        let startDate = inputICE[0].startDate // "2015-10-15T21:30:12"
        let endDate = inputICE.last!.startDate

        let carbRatio = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 8.0)]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let futureCarbEntry = carbEntries[2]

        let statuses = [futureCarbEntry].map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf,
            initialAbsorptionTimeOverrun: 2.0,
            absorptionModel: LinearAbsorption()
        )

        XCTAssertEqual(statuses.count, 1)

        // Full absorption remains
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, TimeInterval(hours: 4), accuracy: 1)

        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            absorptionModel: LinearAbsorption())

        let unit = LoopUnit.gram

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: LoopUnit.gram), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard.first!.quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard.last!.quantity.doubleValue(for: unit), 0, accuracy: 1)
    }

    func testDynamicAbsorptionPartiallyObserved() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_35_min_partial_output")

        let startDate = inputICE[0].startDate // "2015-10-15T21:30:12"
        let endDate = inputICE.last!.startDate

        let carbRatio = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 8.0)]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let statuses = [carbEntries[0]].map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf,
            initialAbsorptionTimeOverrun: 2.0,
            absorptionModel: LinearAbsorption()
        )

        XCTAssertEqual(statuses.count, 1)

        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 8509, accuracy: 1)

        let absorption = statuses[0].absorption!
        let unit = LoopUnit.gram

        XCTAssertEqual(absorption.observed.doubleValue(for: unit), 18, accuracy: Double(Float.ulpOfOne))

        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            absorptionModel: LinearAbsorption()
        )

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard.first!.quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[2].quantity.doubleValue(for: unit), 44, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[25].quantity.doubleValue(for: unit), 9, accuracy: 1)
        XCTAssertEqual(carbsOnBoard.last!.quantity.doubleValue(for: unit), 0, accuracy: 1)
    }

    func testDynamicGlucoseEffectAbsorptionPartiallyObserved() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadEffectOutputFixture("dynamic_glucose_effect_partially_observed_output")

        let startDate = inputICE[0].startDate // "2015-10-15T21:30:12"
        let endDate = inputICE.last!.startDate

        let carbRatio = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 8.0)]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let statuses = [carbEntries[0]].map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf,
            initialAbsorptionTimeOverrun: 2.0,
            absorptionModel: LinearAbsorption()
        )

        XCTAssertEqual(statuses.count, 1)

        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 8509, accuracy: 1)

        let absorption = statuses[0].absorption!
        let unit = LoopUnit.gram

        XCTAssertEqual(absorption.observed.doubleValue(for: unit), 18, accuracy: Double(Float.ulpOfOne))

        let effects = statuses.dynamicGlucoseEffects(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            carbRatios: carbRatio,
            insulinSensitivities: isf,
            absorptionModel: LinearAbsorption()
        )

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: Double(Float.ulpOfOne))
        }
    }


    func testDynamicAbsorptionFullyObserved() {
        let inputICE = loadICEInputFixture("ice_1_hour_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_1_hour_output")

        let startDate = inputICE[0].startDate // "2015-10-15T21:30:12"
        let endDate = inputICE.last!.startDate

        let carbRatio = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 8.0)]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let statuses = [carbEntries[0]].map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf,
            absorptionTimeOverrun: 2.0,
            initialAbsorptionTimeOverrun: 2.0,
            absorptionModel: LinearAbsorption()
        )

        XCTAssertEqual(statuses.count, 1)
        XCTAssertNotNil(statuses[0].absorption)

        // No remaining absorption
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 0, accuracy: 1)

        let absorption = statuses[0].absorption!
        let unit = LoopUnit.gram

        // All should be absorbed
        XCTAssertEqual(absorption.observed.doubleValue(for: unit), 44, accuracy: 1)

        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            absorptionModel: LinearAbsorption()
        )

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard[0].quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[1].quantity.doubleValue(for: unit), 44, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[2].quantity.doubleValue(for: unit), 44, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[10].quantity.doubleValue(for: unit), 21, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[17].quantity.doubleValue(for: unit), 7, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[18].quantity.doubleValue(for: unit), 4, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[30].quantity.doubleValue(for: unit), 0, accuracy: 1)
    }

    func testDynamicGlucoseEffectsAbsorptionFullyObserved() {
        let inputICE = loadICEInputFixture("ice_1_hour_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadEffectOutputFixture("dynamic_glucose_effect_fully_observed_output")

        let startDate = inputICE[0].startDate // "2015-10-15T21:30:12"
        let endDate = inputICE.last!.startDate

        let carbRatio = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 8.0)]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let statuses = [carbEntries[0]].map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf,
            absorptionModel: LinearAbsorption()
        )

        XCTAssertEqual(statuses.count, 1)
        XCTAssertNotNil(statuses[0].absorption)

        // No remaining absorption
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 0, accuracy: 1)

        let absorption = statuses[0].absorption!
        let unit = LoopUnit.gram

        // All should be absorbed
        XCTAssertEqual(absorption.observed.doubleValue(for: unit), 44, accuracy: 1)

        let effects = statuses.dynamicGlucoseEffects(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            carbRatios: carbRatio,
            insulinSensitivities: isf,
            absorptionModel: LinearAbsorption()
        )

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testDynamicAbsorptionNeverFullyObserved() {
        let inputICE = loadICEInputFixture("ice_slow_absorption")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_slow_absorption_output")

        let startDate = inputICE[0].startDate // "2015-10-15T21:30:12"
        let endDate = inputICE.last!.startDate

        let carbRatio = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 8.0)]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let statuses = [carbEntries[1]].map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf,
            absorptionTimeOverrun: 2.0,
            delay: 0,
            initialAbsorptionTimeOverrun: 2.0,
            absorptionModel: LinearAbsorption()
        )

        XCTAssertEqual(statuses.count, 1)
        XCTAssertNotNil(statuses[0].absorption)

        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 10488, accuracy: 1)

        // Check 12 hours later
        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 18)),
            absorptionModel: LinearAbsorption()
        )

        let unit = LoopUnit.gram

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard.first!.quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[5].quantity.doubleValue(for: unit), 30, accuracy: 1)
        XCTAssertEqual(carbsOnBoard.last!.quantity.doubleValue(for: unit), 0, accuracy: 1)
    }

    func testDynamicGlucoseEffectsAbsorptionNeverFullyObserved() {
        let inputICE = loadICEInputFixture("ice_slow_absorption")
        let carbEntries = loadCarbEntryFixture()
        let output = loadEffectOutputFixture("dynamic_glucose_effect_never_fully_observed_output")

        let startDate = inputICE[0].startDate // "2015-10-15T21:30:12"
        let endDate = inputICE.last!.startDate

        let carbRatio = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 8.0)]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let statuses = [carbEntries[1]].map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf,
            absorptionTimeOverrun: 2.0,
            delay: 0,
            initialAbsorptionTimeOverrun: 2.0,
            absorptionModel: LinearAbsorption()
        )

        XCTAssertEqual(statuses.count, 1)
        XCTAssertNotNil(statuses[0].absorption)

        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 10488, accuracy: 1)

        // Check 12 hours later
        let effects = statuses.dynamicGlucoseEffects(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 18)),
            carbRatios: carbRatio,
            insulinSensitivities: isf,
            absorptionModel: LinearAbsorption()
        )

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: Double(Float.ulpOfOne))
        }
    }

    // Aditional tests for nonlinear and adaptive-rate carb absorption models

    func testDynamicAbsorptionPiecewiseLinearNoneObserved() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_35_min_none_piecewiselinear_output")

        let startDate = inputICE[0].startDate // "2015-10-15T21:30:12"
        let endDate = inputICE.last!.startDate

        let carbRatio = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 8.0)]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let futureCarbEntry = carbEntries[2]

        let statuses = [futureCarbEntry].map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf
        )

        XCTAssertEqual(statuses.count, 1)

        // Full absorption remains
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, TimeInterval(hours: 3), accuracy: 1)

        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            absorptionModel: PiecewiseLinearAbsorption()
        )

        let unit = LoopUnit.gram

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard.first!.quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard.last!.quantity.doubleValue(for: unit), 0, accuracy: 1)
    }

    func testDynamicAbsorptionPiecewiseLinearPartiallyObserved() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_35_min_partial_piecewiselinear_output")

        let startDate = inputICE[0].startDate // "2015-10-15T21:30:12"
        let endDate = inputICE.last!.startDate

        let carbRatio = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 8.0)]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let statuses = [carbEntries[0]].map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf
        )

        XCTAssertEqual(statuses.count, 1)

        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 7008, accuracy: 1)

        let absorption = statuses[0].absorption!
        let unit = LoopUnit.gram

        XCTAssertEqual(absorption.observed.doubleValue(for: unit), 18, accuracy: Double(Float.ulpOfOne))

        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            absorptionModel: PiecewiseLinearAbsorption()
        )

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard.first!.quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[2].quantity.doubleValue(for: unit), 44, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[20].quantity.doubleValue(for: unit), 5, accuracy: 1)
        XCTAssertEqual(carbsOnBoard.last!.quantity.doubleValue(for: unit), 0, accuracy: 1)
    }

    func testDynamicAbsorptionPiecewiseLinearFullyObserved() {
        let inputICE = loadICEInputFixture("ice_1_hour_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_1_hour_output")

        let startDate = inputICE[0].startDate // "2015-10-15T21:30:12"
        let endDate = inputICE.last!.startDate

        let carbRatio = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 8.0)]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let statuses = [carbEntries[0]].map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf
        )

        XCTAssertEqual(statuses.count, 1)
        XCTAssertNotNil(statuses[0].absorption)

        // No remaining absorption
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 0, accuracy: 1)

        let absorption = statuses[0].absorption!
        let unit = LoopUnit.gram

        // All should be absorbed
        XCTAssertEqual(absorption.observed.doubleValue(for: unit), 44, accuracy: 1)

        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            absorptionModel: PiecewiseLinearAbsorption()
        )

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard[0].quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[1].quantity.doubleValue(for: unit), 44, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[2].quantity.doubleValue(for: unit), 44, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[10].quantity.doubleValue(for: unit), 21, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[17].quantity.doubleValue(for: unit), 7, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[18].quantity.doubleValue(for: unit), 4, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[30].quantity.doubleValue(for: unit), 0, accuracy: 1)
    }

    func testDynamicAbsorptionPiecewiseLinearNeverFullyObserved() {
        let inputICE = loadICEInputFixture("ice_slow_absorption")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_slow_absorption_piecewiselinear_output")

        let startDate = inputICE[0].startDate // "2015-10-15T21:30:12"
        let endDate = inputICE.last!.startDate

        let carbRatio = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 8.0)]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let statuses = [carbEntries[1]].map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf,
            delay: 0
        )

        XCTAssertEqual(statuses.count, 1)
        XCTAssertNotNil(statuses[0].absorption)

        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 6888, accuracy: 1)

        // Check 12 hours later
        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 18)),
            absorptionModel: PiecewiseLinearAbsorption()
        )

        let unit = LoopUnit.gram

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard.first!.quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[5].quantity.doubleValue(for: unit), 30, accuracy: 1)
        XCTAssertEqual(carbsOnBoard.last!.quantity.doubleValue(for: unit), 0, accuracy: 1)
    }

    func testDynamicAbsorptionPiecewiseLinearAdaptiveRatePartiallyObserved() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_35_min_partial_piecewiselinear_adaptiverate_output")

        let startDate = inputICE[0].startDate // "2015-10-15T21:30:12"
        let endDate = inputICE.last!.startDate

        let carbRatio = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 8.0)]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let statuses = [carbEntries[0]].map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf,
            delay: TimeInterval(minutes: 0),
            initialAbsorptionTimeOverrun: 1.0,
            adaptiveAbsorptionRateEnabled: true
        )

        XCTAssertEqual(statuses.count, 1)

        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 3326, accuracy: 1)

        let absorption = statuses[0].absorption!
        let unit = LoopUnit.gram

        XCTAssertEqual(absorption.observed.doubleValue(for: unit), 18, accuracy: Double(Float.ulpOfOne))

        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            absorptionModel: PiecewiseLinearAbsorption()
        )

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard.first!.quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[2].quantity.doubleValue(for: unit), 44, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[10].quantity.doubleValue(for: unit), 15, accuracy: 1)
        XCTAssertEqual(carbsOnBoard.last!.quantity.doubleValue(for: unit), 0, accuracy: 1)
    }

    func testDynamicAbsorptionMultipleEntries() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        let carbEntries = loadCarbEntryFixture()

        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: TimeZone(secondsFromGMT: 0)!)
        let startDate = inputICE[0].startDate
        let changeDate = dateFormatter.date(from: "2015-10-16T04:30:00")!
        let endDate = dateFormatter.date(from: "2015-10-16T06:00:00")!

        let carbRatio = [
            AbsoluteScheduleValue(startDate: startDate, endDate: changeDate, value: 8.0),
            AbsoluteScheduleValue(startDate: changeDate, endDate: endDate, value: 9.0)
        ]
        let isf = [AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40))]

        let statuses = carbEntries.map(
            to: inputICE,
            carbRatio: carbRatio,
            insulinSensitivity: isf,
            absorptionTimeOverrun: 2.0,
            delay: TimeInterval(minutes: 0),
            initialAbsorptionTimeOverrun: 2.0,
            absorptionModel: LinearAbsorption()
        )

        // Tuple structure: (observed absorption, estimated time remaining)
        let expected = [(16.193665456944906, 9100.254941363484), (1.806334543055097, 13532.959419333554) , (0, 14400)]
        XCTAssertEqual(expected.count, statuses.count)

        for (expected, calculated) in zip(expected, statuses) {
            XCTAssertEqual(expected.0, calculated.absorption!.observed.doubleValue(for: LoopUnit.gram), accuracy: Double(Float.ulpOfOne))
            XCTAssertEqual(expected.1, calculated.absorption!.estimatedTimeRemaining, accuracy: Double(Float.ulpOfOne))
        }
    }
}
