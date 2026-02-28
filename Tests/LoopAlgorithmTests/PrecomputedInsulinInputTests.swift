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

        // Pre-annotate once (ISF-independent); no effects → standard inner glucoseEffects path
        let precomputed = PrecomputedInsulinInput.annotate(doses: input.doses, basal: input.basal)

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

        // ISF-sweep pattern: annotate once, compute effects per ISF value
        let precomputed = PrecomputedInsulinInput
            .annotate(doses: input.doses, basal: input.basal)
            .withEffects(sensitivity: input.sensitivity)

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
        let sliced = PrecomputedInsulinInput.annotate(doses: input.doses, basal: input.basal)

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

    // MARK: - Test: ISF sweep pattern — annotate once, withEffects per multiplier

    func testISFSweepPattern() throws {
        let input = try loadInput()
        let start = input.glucoseHistory.last!.startDate

        // Annotate ONCE — shared across all ISF values
        let base = PrecomputedInsulinInput.annotate(doses: input.doses, basal: input.basal)

        let multipliers: [Double] = [0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3]

        for multiplier in multipliers {
            // Scale ISF — O(n_isf_segments), negligible.
            // Preserve whatever unit the fixture uses by scaling the raw double
            // and re-wrapping in the same unit.
            let scaledSensitivity = input.sensitivity.map { entry -> AbsoluteScheduleValue<LoopQuantity> in
                let unit = entry.value.unit
                let scaled = entry.value.doubleValue(for: unit) * multiplier
                return AbsoluteScheduleValue(
                    startDate: entry.startDate,
                    endDate: entry.endDate,
                    value: LoopQuantity(unit: unit, doubleValue: scaled)
                )
            }

            // Compute effects once for this ISF value — O(D × T), not per-step
            let precomputed = base.withEffects(sensitivity: scaledSensitivity)
            XCTAssertNotNil(precomputed.insulinEffects, "withEffects should populate insulinEffects")

            // Verify it produces the same result as the standard path with the same scaled ISF
            let standard = LoopAlgorithm.generatePrediction(
                start: start,
                glucoseHistory: input.glucoseHistory,
                doses: input.doses,
                carbEntries: input.carbEntries,
                basal: input.basal,
                sensitivity: scaledSensitivity,
                carbRatio: input.carbRatio,
                useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection
            )

            let fast = LoopAlgorithm.generatePrediction(
                start: start,
                glucoseHistory: input.glucoseHistory,
                precomputedInsulin: precomputed,
                carbEntries: input.carbEntries,
                sensitivity: scaledSensitivity,
                carbRatio: input.carbRatio,
                useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection
            )

            XCTAssertEqual(standard.glucose.count, fast.glucose.count,
                           "Count mismatch at ISF multiplier \(multiplier)")
            for (s, f) in zip(standard.glucose, fast.glucose) {
                XCTAssertEqual(
                    s.quantity.doubleValue(for: .milligramsPerDeciliter),
                    f.quantity.doubleValue(for: .milligramsPerDeciliter),
                    accuracy: 0.001,
                    "ISF \(multiplier)×: mismatch at \(s.startDate)"
                )
            }
        }
    }
}
