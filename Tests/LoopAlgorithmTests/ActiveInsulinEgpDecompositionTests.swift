//
//  ActiveInsulinEgpDecompositionTests.swift
//  LoopAlgorithm
//
//  Tests for Phase 1 of the active-insulin vs EGP decomposition: the
//  glucose-effect computation now accepts SEPARATE sensitivity schedules
//  for the active-insulin (positive `netBasalUnits`) component and the
//  EGP-credit (negative `netBasalUnits`) component. At a single ISF (the
//  default — no `egpSensitivityHistory` argument) the output is bit-
//  identical to the prior behavior.
//

import XCTest
@testable import LoopAlgorithm

final class ActiveInsulinEgpDecompositionTests: XCTestCase {

    private let unit = LoopUnit.milligramsPerDeciliter
    private let dia = InsulinMath.defaultInsulinActivityDuration

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private func date(_ s: String) -> Date { dateFormatter.date(from: s)! }

    private func constantISF(_ mgdlPerU: Double, around t: Date,
                              span: TimeInterval = .hours(24)) -> [AbsoluteScheduleValue<LoopQuantity>] {
        return [AbsoluteScheduleValue(
            startDate: t.addingTimeInterval(-span),
            endDate:   t.addingTimeInterval(span),
            value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: mgdlPerU)
        )]
    }

    // MARK: - Per-dose API

    /// When the same value is passed for both active and egp sensitivities,
    /// the decomposed call must match the single-ISF call exactly.
    func testDecomposedMatchesSingleISFWhenSchedulesEqual() {
        let start = date("2025-01-01T12:00:00")
        let doses: [BasalRelativeDose] = [
            BasalRelativeDose(type: .bolus, startDate: start, endDate: start, volume: 1.5),
            BasalRelativeDose(
                type: .basal(scheduledRate: 1.0),
                startDate: start.addingTimeInterval(.hours(1)),
                endDate:   start.addingTimeInterval(.hours(2)),
                volume: 0.0
            ),
        ]
        for dose in doses {
            for tau in [TimeInterval(.minutes(15)), .minutes(60), .minutes(180), dia, dia + .hours(2)] {
                let t = start.addingTimeInterval(tau)
                let single = dose.glucoseEffect(at: t, insulinSensitivity: 50.0, delta: .minutes(5))
                let decomp = dose.glucoseEffect(at: t,
                                                activeSensitivity: 50.0,
                                                egpSensitivity: 50.0,
                                                delta: .minutes(5))
                XCTAssertEqual(single, decomp, accuracy: 1e-12,
                    "Single-ISF and decomposed-with-equal-ISFs must produce identical results")
            }
        }
    }

    /// Boosting active-sensitivity scales the BOLUS effect but NOT the
    /// EGP-credit effect (which comes from negative-net doses).
    func testActiveSensitivityBoostScalesOnlyBolusEffect() {
        let start = date("2025-01-01T12:00:00")
        let bolus = BasalRelativeDose(type: .bolus, startDate: start, endDate: start, volume: 1.0)
        let evalT = start.addingTimeInterval(dia)
        let baseline = bolus.glucoseEffect(at: evalT, activeSensitivity: 50, egpSensitivity: 50, delta: .minutes(5))
        let activeDoubled = bolus.glucoseEffect(at: evalT, activeSensitivity: 100, egpSensitivity: 50, delta: .minutes(5))
        XCTAssertEqual(activeDoubled, 2.0 * baseline, accuracy: 1e-9,
            "Doubling active sensitivity must double a bolus's effect")
    }

    func testEgpSensitivityDoesNotAffectBolus() {
        let start = date("2025-01-01T12:00:00")
        let bolus = BasalRelativeDose(type: .bolus, startDate: start, endDate: start, volume: 1.0)
        let evalT = start.addingTimeInterval(dia)
        let base = bolus.glucoseEffect(at: evalT, activeSensitivity: 50, egpSensitivity: 50, delta: .minutes(5))
        let egpDoubled = bolus.glucoseEffect(at: evalT, activeSensitivity: 50, egpSensitivity: 100, delta: .minutes(5))
        XCTAssertEqual(base, egpDoubled, accuracy: 1e-12,
            "EGP sensitivity must NOT affect a bolus (netBasalUnits > 0)")
    }

    func testEgpSensitivityScalesOnlySuspendEffect() {
        let start = date("2025-01-01T12:00:00")
        let suspend = BasalRelativeDose(
            type: .basal(scheduledRate: 1.0),
            startDate: start, endDate: start.addingTimeInterval(.hours(1)),
            volume: 0.0
        )
        let evalT = start.addingTimeInterval(dia + .hours(1))
        let base = suspend.glucoseEffect(at: evalT, activeSensitivity: 50, egpSensitivity: 50, delta: .minutes(5))
        let activeDoubled = suspend.glucoseEffect(at: evalT, activeSensitivity: 100, egpSensitivity: 50, delta: .minutes(5))
        XCTAssertEqual(base, activeDoubled, accuracy: 1e-12,
            "Active sensitivity must NOT affect a suspended-temp (netBasalUnits < 0)")

        let egpDoubled = suspend.glucoseEffect(at: evalT, activeSensitivity: 50, egpSensitivity: 100, delta: .minutes(5))
        XCTAssertEqual(egpDoubled, 2.0 * base, accuracy: 1e-9,
            "Doubling EGP sensitivity must double a suspended-temp's effect")
    }

    func testNetZeroDoseUnaffectedByEitherSensitivity() {
        let start = date("2025-01-01T12:00:00")
        let neutral = BasalRelativeDose(
            type: .basal(scheduledRate: 1.0),
            startDate: start, endDate: start.addingTimeInterval(.hours(1)),
            volume: 1.0  // matches scheduled → net = 0
        )
        let evalT = start.addingTimeInterval(dia)
        for active in [10.0, 50.0, 100.0] {
            for egp in [10.0, 50.0, 100.0] {
                let v = neutral.glucoseEffect(at: evalT,
                                              activeSensitivity: active,
                                              egpSensitivity: egp,
                                              delta: .minutes(5))
                XCTAssertEqual(v, 0.0, accuracy: 1e-12,
                    "Net-zero dose must produce zero effect for any sensitivity pair (active=\(active), egp=\(egp))")
            }
        }
    }

    // MARK: - Collection-level glucoseEffects

    func testCollectionLevelDecomposedMatchesSingleWhenSchedulesEqual() {
        let start = date("2025-01-01T12:00:00")
        let doses: [BasalRelativeDose] = [
            BasalRelativeDose(type: .bolus, startDate: start, endDate: start, volume: 2.0),
            BasalRelativeDose(
                type: .basal(scheduledRate: 1.0),
                startDate: start.addingTimeInterval(.hours(2)),
                endDate:   start.addingTimeInterval(.hours(3)),
                volume: 0.0
            ),
        ]
        let isf = constantISF(50.0, around: start)
        let single = doses.glucoseEffects(insulinSensitivityHistory: isf)
        let decompNilEgp = doses.glucoseEffects(insulinSensitivityHistory: isf, egpSensitivityHistory: nil)
        let decompMatching = doses.glucoseEffects(insulinSensitivityHistory: isf, egpSensitivityHistory: isf)
        XCTAssertEqual(single.count, decompNilEgp.count)
        XCTAssertEqual(single.count, decompMatching.count)
        for i in 0..<single.count {
            let s = single[i].quantity.doubleValue(for: unit)
            let d1 = decompNilEgp[i].quantity.doubleValue(for: unit)
            let d2 = decompMatching[i].quantity.doubleValue(for: unit)
            XCTAssertEqual(s, d1, accuracy: 1e-9)
            XCTAssertEqual(s, d2, accuracy: 1e-9)
        }
    }

    func testCollectionLevelOverrideBoostsOnlyActiveComponent() {
        // Set up a dose history with both a bolus AND a suspended temp.
        // Apply an active-side boost (insulinSensitivity × 2) but leave EGP
        // schedule at scheduled (× 1). The combined effect should equal:
        //   2 × bolus_effect + 1 × suspend_effect (= -200 + 50 at asymptote for these values)
        // vs the SINGLE-schedule × 2 result which would over-amplify both:
        //   2 × bolus_effect + 2 × suspend_effect (= -200 + 100)
        let start = date("2025-01-01T12:00:00")
        let bolus = BasalRelativeDose(type: .bolus, startDate: start, endDate: start, volume: 2.0)
        let suspend = BasalRelativeDose(
            type: .basal(scheduledRate: 1.0),
            startDate: start.addingTimeInterval(.hours(2)),
            endDate:   start.addingTimeInterval(.hours(3)),
            volume: 0.0  // net = -1
        )

        let baseISF = constantISF(50.0, around: start)
        let boostedISF = constantISF(100.0, around: start)
        let endTime = start.addingTimeInterval(dia + .hours(4))

        // Asymptotic single-schedule × 1 = -2 × 50 + (-1) × -50 = -100 + 50 = -50
        let single = [bolus, suspend].glucoseEffects(
            insulinSensitivityHistory: baseISF,
            from: start, to: endTime
        )
        XCTAssertEqual(single.last!.quantity.doubleValue(for: unit), -50.0, accuracy: 0.5,
            "Asymptote single-schedule = -100 + 50 = -50")

        // Asymptotic single-schedule × 2 (WRONG WAY — over-amplifies EGP) = -200 + 100 = -100
        let singleBoosted = [bolus, suspend].glucoseEffects(
            insulinSensitivityHistory: boostedISF,
            from: start, to: endTime
        )
        XCTAssertEqual(singleBoosted.last!.quantity.doubleValue(for: unit), -100.0, accuracy: 0.5,
            "Asymptote single-schedule-doubled = -200 + 100 = -100 (the OLD over-amplifying behavior)")

        // Asymptotic active-doubled, egp-unchanged (the FIX) = -200 + 50 = -150
        let decomposed = [bolus, suspend].glucoseEffects(
            insulinSensitivityHistory: boostedISF,
            egpSensitivityHistory: baseISF,
            from: start, to: endTime
        )
        XCTAssertEqual(decomposed.last!.quantity.doubleValue(for: unit), -150.0, accuracy: 0.5,
            "Asymptote with active×2, egp×1: -2 × 100 + (-1) × -50 = -150")

        // The decomposed result must differ from BOTH single-schedule cases.
        XCTAssertNotEqual(decomposed.last!.quantity.doubleValue(for: unit),
                          single.last!.quantity.doubleValue(for: unit))
        XCTAssertNotEqual(decomposed.last!.quantity.doubleValue(for: unit),
                          singleBoosted.last!.quantity.doubleValue(for: unit))
    }

    // MARK: - Mid-absorption variant

    func testMidAbsorptionDecomposedMatchesSingleWhenSchedulesEqual() {
        let start = date("2025-01-01T12:00:00")
        let doses: [BasalRelativeDose] = [
            BasalRelativeDose(type: .bolus, startDate: start, endDate: start, volume: 1.0),
            BasalRelativeDose(
                type: .basal(scheduledRate: 0.8),
                startDate: start.addingTimeInterval(.hours(1)),
                endDate:   start.addingTimeInterval(.hours(2)),
                volume: 0.0
            ),
        ]
        let isf = constantISF(45.0, around: start)
        let single = doses.glucoseEffectsMidAbsorptionISF(insulinSensitivityHistory: isf)
        let decomp = doses.glucoseEffectsMidAbsorptionISF(insulinSensitivityHistory: isf, egpSensitivityHistory: isf)
        let decompNil = doses.glucoseEffectsMidAbsorptionISF(insulinSensitivityHistory: isf, egpSensitivityHistory: nil)
        XCTAssertEqual(single.count, decomp.count)
        for i in 0..<single.count {
            XCTAssertEqual(
                single[i].quantity.doubleValue(for: unit),
                decomp[i].quantity.doubleValue(for: unit),
                accuracy: 1e-9)
            XCTAssertEqual(
                single[i].quantity.doubleValue(for: unit),
                decompNil[i].quantity.doubleValue(for: unit),
                accuracy: 1e-9)
        }
    }

    // MARK: - End-to-end through LoopAlgorithm.generatePrediction

    /// `generatePrediction(..., egpSensitivity: nil)` must produce a
    /// prediction bit-identical to the prior single-schedule API.
    func testGeneratePredictionNilEgpMatchesSingleSchedule() {
        let start = date("2025-01-01T12:00:00")
        let dose = BasalRelativeDose(type: .bolus, startDate: start, endDate: start, volume: 1.0)
        let glucose: [GlucoseFixtureValue] = (0..<7).map { i in
            GlucoseFixtureValue(
                startDate: start.addingTimeInterval(TimeInterval(-30 + 5 * i) * 60),
                quantity: LoopQuantity(unit: unit, doubleValue: 150),
                isDisplayOnly: false, wasUserEntered: false,
                provenanceIdentifier: "test", condition: nil, trendRate: nil
            )
        }
        let basal: [AbsoluteScheduleValue<Double>] = [AbsoluteScheduleValue(
            startDate: start.addingTimeInterval(-.hours(6)),
            endDate: start.addingTimeInterval(.hours(12)),
            value: 1.0
        )]
        let sensitivity = constantISF(50.0, around: start)
        let carbRatio: [AbsoluteScheduleValue<Double>] = [AbsoluteScheduleValue(
            startDate: start.addingTimeInterval(-.hours(6)),
            endDate: start.addingTimeInterval(.hours(12)),
            value: 10.0
        )]

        let predA = LoopAlgorithm.generatePrediction(
            start: start, glucoseHistory: glucose, doses: [dose],
            carbEntries: [FixtureCarbEntry](),  // dummy stand-in for CarbEntry collection? Better: empty CarbEntry array
            basal: basal, sensitivity: sensitivity, carbRatio: carbRatio,
            useMidAbsorptionISF: true,
            egpSensitivity: nil
        )
        let predB = LoopAlgorithm.generatePrediction(
            start: start, glucoseHistory: glucose, doses: [dose],
            carbEntries: [FixtureCarbEntry](),
            basal: basal, sensitivity: sensitivity, carbRatio: carbRatio,
            useMidAbsorptionISF: true,
            egpSensitivity: sensitivity  // same as insulin → must match nil-case
        )
        XCTAssertEqual(predA.glucose.count, predB.glucose.count)
        for i in 0..<predA.glucose.count {
            XCTAssertEqual(
                predA.glucose[i].quantity.doubleValue(for: unit),
                predB.glucose[i].quantity.doubleValue(for: unit),
                accuracy: 1e-9)
        }
    }

    func testMidAbsorptionOverrideBoostsOnlyActiveComponent() {
        // Mirror of testCollectionLevelOverrideBoostsOnlyActiveComponent but
        // using mid-absorption ISF (which integrates ISF per absorption sub-interval).
        let start = date("2025-01-01T12:00:00")
        let bolus = BasalRelativeDose(type: .bolus, startDate: start, endDate: start, volume: 2.0)
        let suspend = BasalRelativeDose(
            type: .basal(scheduledRate: 1.0),
            startDate: start.addingTimeInterval(.hours(2)),
            endDate:   start.addingTimeInterval(.hours(3)),
            volume: 0.0
        )
        let baseISF = constantISF(50.0, around: start)
        let boostedISF = constantISF(100.0, around: start)

        let decomp = [bolus, suspend].glucoseEffectsMidAbsorptionISF(
            insulinSensitivityHistory: boostedISF,
            egpSensitivityHistory: baseISF
        )
        XCTAssertEqual(decomp.last!.quantity.doubleValue(for: unit), -150.0, accuracy: 0.5,
            "Mid-abs decomposed asymptote with active×2, egp×1: -150")
    }
}
