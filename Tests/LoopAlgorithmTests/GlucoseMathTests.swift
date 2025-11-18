//
//  GlucoseMathTests.swift
//  LoopAlgorithm
//
//  Created by Pete Schwamb on 11/12/25.
//

import XCTest
@testable import LoopAlgorithm

extension XCTestCase {
    public func loadFixture<T>(_ resourceName: String) -> T {
        let url = Bundle.module.url(forResource: resourceName, withExtension: "json", subdirectory: "Fixtures")!
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: url), options: []) as! T
    }
}

public struct GlucoseFixtureValue: GlucoseSampleValue {
    public let startDate: Date
    public let quantity: LoopQuantity
    public let isDisplayOnly: Bool
    public let wasUserEntered: Bool
    public let provenanceIdentifier: String
    public let condition: GlucoseCondition?
    public let trendRate: LoopQuantity?
    public var syncIdentifier: String?

    public init(startDate: Date, quantity: LoopQuantity, isDisplayOnly: Bool, wasUserEntered: Bool, provenanceIdentifier: String?, condition: GlucoseCondition?, trendRate: LoopQuantity?) {
        self.startDate = startDate
        self.quantity = quantity
        self.isDisplayOnly = isDisplayOnly
        self.wasUserEntered = wasUserEntered
        self.provenanceIdentifier = provenanceIdentifier ?? "com.loopkit.LoopKitTests"
        self.condition = condition
        self.trendRate = trendRate
    }
}

extension GlucoseFixtureValue: Comparable {
    public static func <(lhs: GlucoseFixtureValue, rhs: GlucoseFixtureValue) -> Bool {
        return lhs.startDate < rhs.startDate
    }
}

final class GlucoseMathTests: XCTestCase {

    // MARK: - Helper to create a mock GlucoseSampleValue

    private struct MockGlucoseSample: GlucoseSampleValue {
        var startDate: Date
        var quantity: LoopQuantity
        var provenanceIdentifier: String
        var isDisplayOnly: Bool
        var wasUserEntered: Bool
        var condition: GlucoseCondition?
        var trendRate: LoopQuantity?
    }

    private func sample(at date: Date,
                        glucose mgdL: Double,
                        provenance: String = "test",
                        displayOnly: Bool = false) -> MockGlucoseSample {
        MockGlucoseSample(
            startDate: date,
            quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: mgdL),
            provenanceIdentifier: provenance,
            isDisplayOnly: displayOnly,
            wasUserEntered: false,
            condition: nil,
            trendRate: nil
        )
    }

    func testHasGradualTransitions_SingleSample_ReturnsFalse() {
        let now = Date()
        let samples: [MockGlucoseSample] = [sample(at: now, glucose: 120)]

        XCTAssertFalse(samples.hasGradualTransitions(),
                       "A single sample should be considered a possible spike -> false")
    }

    func testHasGradualTransitions_TwoSamplesWithinThreshold_ReturnsTrue() {
        let base = Date()
        let s1 = sample(at: base, glucose: 100)
        let s2 = sample(at: base.addingTimeInterval(.minutes(5)), glucose: 110) // +10 mg/dL

        let samples = [s1, s2]
        XCTAssertTrue(samples.hasGradualTransitions(),
                      "10 mg/dL change is less than or equal to default 40 mg/dL -> true")
    }

    func testHasGradualTransitions_TwoSamplesExceedingThreshold_ReturnsFalse() {
        let base = Date()
        let s1 = sample(at: base, glucose: 100)
        let s2 = sample(at: base.addingTimeInterval(.minutes(5)), glucose: 150) // +50 mg/dL

        let samples = [s1, s2]
        XCTAssertFalse(samples.hasGradualTransitions(),
                       "50 mg/dL change exceeds default 40 mg/dL -> false")
    }

    func testHasGradualTransitions_MultipleSamplesAllWithinThreshold_ReturnsTrue() {
        let base = Date()
        let samples: [MockGlucoseSample] = [
            sample(at: base,                     glucose: 100),
            sample(at: base + .minutes(5),       glucose: 115),
            sample(at: base + .minutes(10),      glucose: 125),
            sample(at: base + .minutes(15),      glucose: 118)
        ]   // max delta = 15 mg/dL

        XCTAssertTrue(samples.hasGradualTransitions(),
                      "All consecutive changes less than or equal to 40 mg/dL -> true")
    }

    func testHasGradualTransitions_OneJumpExceedsThreshold_ReturnsFalse() {
        let base = Date()
        let samples: [MockGlucoseSample] = [
            sample(at: base,                     glucose: 100),
            sample(at: base + .minutes(5),       glucose: 115),
            sample(at: base + .minutes(10),      glucose: 160) // +45 mg/dL jump
        ]

        XCTAssertFalse(samples.hasGradualTransitions(),
                       "A single jump of 45 mg/dL exceeds 40 mg/dL -> false")
    }

    func testHasGradualTransitions_CustomThreshold() {
        let base = Date()
        let samples: [MockGlucoseSample] = [
            sample(at: base,               glucose: 100),
            sample(at: base + .minutes(5), glucose: 150) // +50 mg/dL
        ]

        // 50 mg/dL is greater than 40, but less than or equal to 55 -> should pass with 55
        XCTAssertTrue(samples.hasGradualTransitions(gradualTransitionThreshold: 55),
                      "Custom threshold of 55 mg/dL allows a 50 mg/dL change")
        XCTAssertFalse(samples.hasGradualTransitions(gradualTransitionThreshold: 45),
                       "Custom threshold of 45 mg/dL rejects a 50 mg/dL change")
    }

    // MARK: - Supporting checks used by other GlucoseMath methods

    func testIsContinuous_EmptyCollection_ReturnsFalse() {
        let samples: [MockGlucoseSample] = []
        XCTAssertFalse(samples.isContinuous(),
                       "Empty collection is not continuous")
    }

    func testIsContinuous_Regular5MinSpacing_ReturnsTrue() {
        let base = Date()
        let samples: [MockGlucoseSample] = (0..<6).map {
            sample(at: base + .minutes(Double($0 * 5)), glucose: 100 + Double($0))
        }

        XCTAssertTrue(samples.isContinuous(within: .minutes(5.5)),
                      "Samples every 5 min are within a 5.5 min tolerance -> true")
    }

    func testIsContinuous_GapLargerThanTolerance_ReturnsFalse() {
        let base = Date()
        let samples: [MockGlucoseSample] = [
            sample(at: base,                 glucose: 100),
            sample(at: base + .minutes(5),   glucose: 105),
            sample(at: base + .minutes(20),  glucose: 110) // 15 min gap
        ]

        XCTAssertFalse(samples.isContinuous(within: .minutes(6)),
                       "A 15 min gap exceeds a 6 min tolerance -> false")
    }

    func testContainsCalibrations_NoCalibrations_ReturnsFalse() {
        let samples = (0..<3).map { sample(at: Date() + .minutes(Double($0*5)), glucose: 100) }
        XCTAssertFalse(samples.containsCalibrations(),
                       "No display-only samples -> false")
    }

    func testContainsCalibrations_HasCalibration_ReturnsTrue() {
        let base = Date()
        let samples: [MockGlucoseSample] = [
            sample(at: base,               glucose: 100),
            sample(at: base + .minutes(5), glucose: 105, displayOnly: true) // calibration
        ]

        XCTAssertTrue(samples.containsCalibrations(),
                      "One display-only sample -> true")
    }

    func testHasSingleProvenance_AllSame_ReturnsTrue() {
        let samples = (0..<4).map { sample(at: Date() + .minutes(Double($0*5)), glucose: 100, provenance: "CGM") }
        XCTAssertTrue(samples.hasSingleProvenance,
                      "All samples share the same provenance -> true")
    }

    func testHasSingleProvenance_DifferentProvenance_ReturnsFalse() {
        let base = Date()
        let samples: [MockGlucoseSample] = [
            sample(at: base,               glucose: 100, provenance: "CGM"),
            sample(at: base + .minutes(5), glucose: 105, provenance: "Manual")
        ]

        XCTAssertFalse(samples.hasSingleProvenance,
                       "Different provenance identifiers -> false")
    }

    func loadInputFixture(_ resourceName: String) -> [GlucoseFixtureValue] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseFixtureValue(
                startDate: dateFormatter.date(from: $0["date"] as! String)!,
                quantity: LoopQuantity(unit: LoopUnit.milligramsPerDeciliter, doubleValue: $0["amount"] as! Double),
                isDisplayOnly: ($0["display_only"] as? Bool) ?? false,
                wasUserEntered: ($0["user_entered"] as? Bool) ?? false,
                provenanceIdentifier: $0["provenance_identifier"] as? String,
                condition: ($0["condition"] as? String).flatMap { GlucoseCondition(rawValue: $0) },
                trendRate: ($0["trend_rate"] as? Double).flatMap { LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: $0) }
            )
        }
    }

    func loadOutputFixture(_ resourceName: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: LoopQuantity(unit: LoopUnit(from: $0["unit"] as! String), doubleValue: $0["amount"] as! Double))
        }
    }

    func loadEffectVelocityFixture(_ resourceName: String) -> [GlucoseEffectVelocity] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseEffectVelocity(startDate: dateFormatter.date(from: $0["startDate"] as! String)!, endDate: dateFormatter.date(from: $0["endDate"] as! String)!, quantity: LoopQuantity(unit: LoopUnit(from: $0["unit"] as! String), doubleValue:$0["value"] as! Double))
        }
    }

    func testMomentumEffectForBouncingGlucose() {
        let input = loadInputFixture("momentum_effect_bouncing_glucose_input")
        let output = loadOutputFixture("momentum_effect_bouncing_glucose_output")

        let effects = input.linearMomentumEffect(duration: .minutes(30))
        let unit = LoopUnit.milligramsPerDeciliter

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testMomentumEffectForRisingGlucose() {
        let input = loadInputFixture("momentum_effect_rising_glucose_input")
        let output = loadOutputFixture("momentum_effect_rising_glucose_output")

        let effects = input.linearMomentumEffect(duration: .minutes(30))
        let unit = LoopUnit.milligramsPerDeciliter

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testMomentumEffectForRisingGlucoseDoubles() {
        let input = loadInputFixture("momentum_effect_rising_glucose_double_entries_input")
        let output = loadOutputFixture("momentum_effect_rising_glucose_output")

        let effects = input.linearMomentumEffect(duration: .minutes(30))
        let unit = LoopUnit.milligramsPerDeciliter

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testMomentumEffectForFallingGlucose() {
        let input = loadInputFixture("momentum_effect_falling_glucose_input")
        let output = loadOutputFixture("momentum_effect_falling_glucose_output")

        let effects = input.linearMomentumEffect(duration: .minutes(30))
        let unit = LoopUnit.milligramsPerDeciliter

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testMomentumEffectForFallingGlucoseDuplicates() {
        var input = loadInputFixture("momentum_effect_falling_glucose_input")
        let output = loadOutputFixture("momentum_effect_falling_glucose_output")
        input.append(contentsOf: input)
        input.sort(by: <)

        let effects = input.linearMomentumEffect(duration: .minutes(30))
        let unit = LoopUnit.milligramsPerDeciliter

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testMomentumEffectForStableGlucose() {
        let input = loadInputFixture("momentum_effect_stable_glucose_input")
        let output = loadOutputFixture("momentum_effect_stable_glucose_output")

        let effects = input.linearMomentumEffect(duration: .minutes(30))
        let unit = LoopUnit.milligramsPerDeciliter

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testMomentumEffectForDuplicateGlucose() {
        let input = loadInputFixture("momentum_effect_duplicate_glucose_input")
        let effects = input.linearMomentumEffect()

        XCTAssertEqual(0, effects.count)
    }

    func testMomentumEffectForEmptyGlucose() {
        let input = [GlucoseFixtureValue]()
        let effects = input.linearMomentumEffect()

        XCTAssertEqual(0, effects.count)
    }

    func testMomentumEffectForSpacedOutGlucose() {
        let input = loadInputFixture("momentum_effect_incomplete_glucose_input")
        let effects = input.linearMomentumEffect()

        XCTAssertEqual(0, effects.count)
    }

    func testMomentumEffectForTooFewGlucose() {
        let input = loadInputFixture("momentum_effect_bouncing_glucose_input")[0...1]
        let effects = input.linearMomentumEffect()

        XCTAssertEqual(0, effects.count)
    }

    func testMomentumEffectForDisplayOnlyGlucose() {
        let input = loadInputFixture("momentum_effect_display_only_glucose_input")
        let effects = input.linearMomentumEffect()

        XCTAssertEqual(0, effects.count)
    }

    func testMomentumEffectForMixedProvenanceGlucose() {
        let input = loadInputFixture("momentum_effect_mixed_provenance_glucose_input")
        let effects = input.linearMomentumEffect()

        XCTAssertEqual(0, effects.count)
    }

    func testCounteractionEffectsForFallingGlucose() {
        let input = loadInputFixture("counteraction_effect_falling_glucose_input")
        let insulinEffect = loadOutputFixture("counteraction_effect_falling_glucose_insulin")
        let output = loadEffectVelocityFixture("counteraction_effect_falling_glucose_output")

        let effects = input.counteractionEffects(to: insulinEffect)
        let unit = LoopUnit.milligramsPerDeciliterPerMinute

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testCounteractionEffectsForFallingGlucoseDuplicates() {
        var input = loadInputFixture("counteraction_effect_falling_glucose_input")
        input.append(contentsOf: input)
        input.sort(by: <)
        let insulinEffect = loadOutputFixture("counteraction_effect_falling_glucose_insulin")
        let output = loadEffectVelocityFixture("counteraction_effect_falling_glucose_output")

        let effects = input.counteractionEffects(to: insulinEffect)
        let unit = LoopUnit.milligramsPerDeciliterPerMinute

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testCounteractionEffectsForFallingGlucoseAlmostDuplicates() {
        let input = loadInputFixture("counteraction_effect_falling_glucose_almost_duplicates_input")
        let insulinEffect = loadOutputFixture("counteraction_effect_falling_glucose_insulin")
        let output = loadEffectVelocityFixture("counteraction_effect_falling_glucose_almost_duplicates_output")

        let effects = input.counteractionEffects(to: insulinEffect)
        let unit = LoopUnit.milligramsPerDeciliterPerMinute

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testCounteractionEffectsForNoGlucose() {
        let input = [GlucoseFixtureValue]()
        let insulinEffect = loadOutputFixture("counteraction_effect_falling_glucose_insulin")
        let output = [GlucoseEffectVelocity]()

        let effects = input.counteractionEffects(to: insulinEffect)

        XCTAssertEqual(output.count, effects.count)
    }
    
}
