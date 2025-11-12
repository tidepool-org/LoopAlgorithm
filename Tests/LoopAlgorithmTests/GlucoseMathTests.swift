//
//  GlucoseMathTests.swift
//  LoopAlgorithm
//
//  Created by Pete Schwamb on 11/12/25.
//

import XCTest
@testable import LoopAlgorithm

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

        // GlucoseValue conformance
        var endDate: Date { startDate }
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
}
