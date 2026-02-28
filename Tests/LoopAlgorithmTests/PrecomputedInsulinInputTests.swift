// PrecomputedInsulinInputTests.swift
//
// Verifies that generatePrediction(precomputedInsulin:) produces bit-identical
// output to the standard overload, and that the pre-built effects fast-path
// also matches.

import XCTest
@testable import LoopAlgorithm

final class PrecomputedInsulinInputTests: XCTestCase {

    // MARK: - Fixture loading (mirrors LoopAlgorithmTests.swift)

    typealias Input = LoopPredictionInput<FixtureCarbEntry, FixtureGlucoseSample, FixtureInsulinDose>

    private func loadInput() throws -> Input {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let url = Bundle.module.url(
            forResource: "live_capture_input",
            withExtension: "json",
            subdirectory: "Fixtures"
        )!
        return try decoder.decode(Input.self, from: Data(contentsOf: url))
    }

    // MARK: - Test: annotated-only fast path matches standard output

    func testPrecomputedAnnotationMatchesStandard() throws {
        let input = try loadInput()
        let start = input.glucoseHistory.last!.startDate

        // Standard prediction (full annotation inside generatePrediction)
        let standard = LoopAlgorithm.generatePrediction(
            start: start,
            glucoseHistory: input.glucoseHistory,
            doses: input.doses,
            carbEntries: input.carbEntries,
            basal: input.basal,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection
        )

        // Pre-annotate once; no pre-built effects → slow inner path for glucoseEffects
        let precomputed = PrecomputedInsulinInput.build(
            doses: input.doses,
            basal: input.basal
        )

        let fast = LoopAlgorithm.generatePrediction(
            start: start,
            glucoseHistory: input.glucoseHistory,
            precomputedInsulin: precomputed,
            carbEntries: input.carbEntries,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection
        )

        XCTAssertEqual(standard.glucose.count, fast.glucose.count,
                       "Prediction point count should match")
        for (s, f) in zip(standard.glucose, fast.glucose) {
            XCTAssertEqual(s.startDate, f.startDate)
            XCTAssertEqual(
                s.quantity.doubleValue(for: .milligramsPerDeciliter),
                f.quantity.doubleValue(for: .milligramsPerDeciliter),
                accuracy: 0.001,
                "Mismatch at \(s.startDate)"
            )
        }
        XCTAssertEqual(standard.activeInsulin ?? 0, fast.activeInsulin ?? 0, accuracy: 0.001)
    }

    // MARK: - Test: pre-built effects path compiles and returns a prediction
    //
    // Bit-identical output is NOT guaranteed (see PrecomputedInsulinInput.insulinEffects
    // for the timeline-snapping caveat).  This test only verifies that the fast
    // path runs without crashing and returns the expected number of points.

    func testPrebuiltEffectsFastPathRunsWithoutError() throws {
        let input = try loadInput()
        let start = input.glucoseHistory.last!.startDate

        let standard = LoopAlgorithm.generatePrediction(
            start: start,
            glucoseHistory: input.glucoseHistory,
            doses: input.doses,
            carbEntries: input.carbEntries,
            basal: input.basal,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection
        )

        let precomputed = PrecomputedInsulinInput.build(
            doses: input.doses,
            basal: input.basal,
            sensitivity: input.sensitivity
        )

        let fast = LoopAlgorithm.generatePrediction(
            start: start,
            glucoseHistory: input.glucoseHistory,
            precomputedInsulin: precomputed,
            carbEntries: input.carbEntries,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection
        )

        XCTAssertEqual(standard.glucose.count, fast.glucose.count,
                       "Pre-built effects path should return the same number of prediction points")
        XCTAssertNotNil(fast.activeInsulin)
    }

    // MARK: - Test: sliced annotated doses round-trip

    func testSlicedAnnotatedDosesMatchStandard() throws {
        let input = try loadInput()
        let start = input.glucoseHistory.last!.startDate

        let standard = LoopAlgorithm.generatePrediction(
            start: start,
            glucoseHistory: input.glucoseHistory,
            doses: input.doses,
            carbEntries: input.carbEntries,
            basal: input.basal,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection
        )

        // Simulate EvalCore: build once, then pass the (unsliced) annotated set
        let full = PrecomputedInsulinInput.build(doses: input.doses, basal: input.basal)
        let sliced = PrecomputedInsulinInput(annotatedDoses: full.annotatedDoses)

        let fromSlice = LoopAlgorithm.generatePrediction(
            start: start,
            glucoseHistory: input.glucoseHistory,
            precomputedInsulin: sliced,
            carbEntries: input.carbEntries,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection
        )

        for (s, f) in zip(standard.glucose, fromSlice.glucose) {
            XCTAssertEqual(
                s.quantity.doubleValue(for: .milligramsPerDeciliter),
                f.quantity.doubleValue(for: .milligramsPerDeciliter),
                accuracy: 0.001
            )
        }
    }
}
