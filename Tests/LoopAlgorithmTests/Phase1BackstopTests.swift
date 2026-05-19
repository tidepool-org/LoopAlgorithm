//
//  Phase1BackstopTests.swift
//  LoopAlgorithm
//
//  Backstop tests for the upcoming "active-insulin vs EGP decomposition"
//  refactor. The refactor will split `BasalRelativeDose.glucoseEffect` so
//  that the active-insulin component (positive `netBasalUnits`) and the
//  EGP-credit component (negative `netBasalUnits`) can be scaled
//  independently by insulin-sensitivity multipliers / overrides.
//
//  These tests pin down today's BEHAVIOR — at the default schedule (no
//  override / mult = 1.0) the decomposed version must continue to produce
//  identical output. The asserts cover:
//
//   - Sign convention of `glucoseEffect`: positive netBasalUnits → negative
//     BG-effect rate (insulin lowers BG); negative netBasalUnits → positive
//     BG-effect rate (EGP credit from suspending).
//   - Magnitude: `effect_at_asymptote ≈ netBasalUnits × -ISF` once the dose
//     has fully decayed.
//   - Net-zero dose: a temp basal that exactly matches scheduled basal
//     produces zero glucose effect (no spurious EGP credit or active-
//     insulin effect).
//   - Sign symmetry: a +U bolus and a -U bolus (same magnitude) produce
//     mirror-image effects.
//   - Linearity: the effect of a mixed-sign dose history equals the sum of
//     the per-dose effects (no cross-talk).
//   - `glucoseEffects` and `glucoseEffectsMidAbsorptionISF` agree when the
//     sensitivity schedule is constant across the absorption window.
//   - `insulinCorrection` reads the FULL sensitivity schedule across its
//     forecast horizon (so the post-refactor decomposed call doesn't
//     accidentally collapse to the at-t value).
//

import XCTest
@testable import LoopAlgorithm

final class Phase1BackstopTests: XCTestCase {

    private let unit = LoopUnit.milligramsPerDeciliter
    private let dia = InsulinMath.defaultInsulinActivityDuration  // 6h

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private func date(_ s: String) -> Date { dateFormatter.date(from: s)! }

    /// Build a constant ISF schedule that covers the dose effect window.
    private func constantISF(_ mgdlPerU: Double, around t: Date,
                              span: TimeInterval = .hours(24)) -> [AbsoluteScheduleValue<LoopQuantity>] {
        return [AbsoluteScheduleValue(
            startDate: t.addingTimeInterval(-span),
            endDate:   t.addingTimeInterval(span),
            value: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: mgdlPerU)
        )]
    }

    // MARK: - Per-dose glucoseEffect: sign convention

    func testBolusProducesNegativeBgEffect() {
        // Positive netBasalUnits → BG-effect should be NEGATIVE (BG lowering).
        let start = date("2025-01-01T12:00:00")
        let dose = BasalRelativeDose(type: .bolus, startDate: start, endDate: start, volume: 1.0)
        XCTAssertEqual(dose.netBasalUnits, 1.0, accuracy: 1e-9)
        // Evaluate well past peak (at DIA, effect is fully delivered).
        let v = dose.glucoseEffect(
            at: start.addingTimeInterval(dia),
            insulinSensitivity: 50.0,
            delta: .minutes(5)
        )
        XCTAssertLessThan(v, 0, "+1 U bolus must produce negative BG effect")
        XCTAssertEqual(v, 1.0 * -50.0, accuracy: 0.001,
            "At asymptote (>= DIA), effect = netUnits × -ISF: \(v) vs \(1.0 * -50.0)")
    }

    func testNegativeNetUnitsProducesPositiveBgEffect() {
        // Suspended temp basal: deliver 0 U/hr for 1 hour while scheduled is
        // 1.0 U/hr → netBasalUnits = 0 - 1.0×1.0 = -1.0.
        // → BG-effect should be POSITIVE (EGP credit).
        let start = date("2025-01-01T12:00:00")
        let dose = BasalRelativeDose(
            type: .basal(scheduledRate: 1.0),
            startDate: start,
            endDate: start.addingTimeInterval(.hours(1)),
            volume: 0.0  // suspended
        )
        XCTAssertEqual(dose.netBasalUnits, -1.0, accuracy: 1e-9)
        // For temp basal segments, evaluate after the segment+activity window
        // so the effect is fully integrated.
        let v = dose.glucoseEffect(
            at: start.addingTimeInterval(dia + .hours(1)),
            insulinSensitivity: 50.0,
            delta: .minutes(5)
        )
        XCTAssertGreaterThan(v, 0, "Suspending below scheduled basal must produce positive BG effect (EGP credit)")
        XCTAssertEqual(v, -1.0 * -50.0, accuracy: 0.001,
            "At asymptote: effect = netUnits × -ISF = (-1.0) × (-50.0) = +50.0; got \(v)")
    }

    func testNetZeroDoseProducesZeroEffect() {
        // Temp basal that matches scheduled basal: deliver 1.0 U/hr for 1 hr
        // while scheduled is 1.0 U/hr → netBasalUnits = 0.
        let start = date("2025-01-01T12:00:00")
        let dose = BasalRelativeDose(
            type: .basal(scheduledRate: 1.0),
            startDate: start,
            endDate: start.addingTimeInterval(.hours(1)),
            volume: 1.0  // matches scheduled
        )
        XCTAssertEqual(dose.netBasalUnits, 0.0, accuracy: 1e-9)
        // Effect must be exactly zero — no spurious active-insulin or EGP-credit.
        for tau in [TimeInterval(.minutes(15)), .minutes(60), .minutes(180), dia] {
            let v = dose.glucoseEffect(
                at: start.addingTimeInterval(tau),
                insulinSensitivity: 50.0,
                delta: .minutes(5)
            )
            XCTAssertEqual(v, 0.0, accuracy: 1e-12,
                "Net-zero dose should produce zero effect at all times; at \(tau) got \(v)")
        }
    }

    // MARK: - Sign symmetry and linearity

    func testSignSymmetryBolus() {
        // +1 U bolus and -1 U "anti-bolus" (constructed via suspended-vs-
        // scheduled subtraction conceptually — but here we use direct
        // negative-volume as a stand-in) produce mirror-image effects.
        // BasalRelativeDose doesn't allow negative bolus volume; use a temp
        // basal with double-rate vs scheduled to get a +1 net, and a temp
        // basal with zero rate to get a -1 net, both over the same 1 hr.
        let start = date("2025-01-01T12:00:00")
        let plusOne = BasalRelativeDose(
            type: .basal(scheduledRate: 1.0),
            startDate: start, endDate: start.addingTimeInterval(.hours(1)),
            volume: 2.0  // double scheduled → net = +1
        )
        let minusOne = BasalRelativeDose(
            type: .basal(scheduledRate: 1.0),
            startDate: start, endDate: start.addingTimeInterval(.hours(1)),
            volume: 0.0  // suspended → net = -1
        )
        XCTAssertEqual(plusOne.netBasalUnits, 1.0, accuracy: 1e-9)
        XCTAssertEqual(minusOne.netBasalUnits, -1.0, accuracy: 1e-9)
        let times: [TimeInterval] = [.minutes(30), .minutes(60), .minutes(180), .minutes(360), .minutes(420)]
        for tau in times {
            let evalT = start.addingTimeInterval(tau)
            let p = plusOne.glucoseEffect(at: evalT, insulinSensitivity: 50.0, delta: .minutes(5))
            let m = minusOne.glucoseEffect(at: evalT, insulinSensitivity: 50.0, delta: .minutes(5))
            XCTAssertEqual(p, -m, accuracy: 1e-9,
                "+1 and -1 net should be mirror images at tau=\(tau): p=\(p), m=\(m)")
        }
    }

    func testLinearityOfMixedSignHistory() {
        // Effect of [bolus + suspend] = effect_of(bolus) + effect_of(suspend),
        // verified after both doses have fully decayed (asymptotic values).
        let start = date("2025-01-01T12:00:00")
        let bolus = BasalRelativeDose(type: .bolus, startDate: start, endDate: start, volume: 1.0)
        let suspend = BasalRelativeDose(
            type: .basal(scheduledRate: 1.0),
            startDate: start.addingTimeInterval(.hours(2)),
            endDate: start.addingTimeInterval(.hours(3)),
            volume: 0.0
        )
        let isf = constantISF(50.0, around: start)
        // Both doses' activity ends by start + 3h + DIA = start + 9h. Check
        // a few points after that.
        let suspendEnd = start.addingTimeInterval(.hours(3))
        let asymTimes = [suspendEnd.addingTimeInterval(dia + .minutes(30)),
                         suspendEnd.addingTimeInterval(dia + .hours(1))]
        let effectsBoth = [bolus, suspend].glucoseEffects(
            insulinSensitivityHistory: isf,
            from: start,
            to: asymTimes.last!
        )
        let effectsBolus = [bolus].glucoseEffects(
            insulinSensitivityHistory: isf,
            from: start,
            to: asymTimes.last!
        )
        let effectsSuspend = [suspend].glucoseEffects(
            insulinSensitivityHistory: isf,
            from: start,
            to: asymTimes.last!
        )
        XCTAssertFalse(effectsBoth.isEmpty)
        XCTAssertEqual(effectsBoth.count, effectsBolus.count)
        XCTAssertEqual(effectsBoth.count, effectsSuspend.count)
        var maxAbsErr = 0.0
        for i in 0..<effectsBoth.count {
            let combined = effectsBoth[i].quantity.doubleValue(for: unit)
            let bolusVal = effectsBolus[i].quantity.doubleValue(for: unit)
            let suspVal  = effectsSuspend[i].quantity.doubleValue(for: unit)
            maxAbsErr = max(maxAbsErr, abs(combined - (bolusVal + suspVal)))
        }
        XCTAssertLessThan(maxAbsErr, 0.01,
            "Combined effect should equal sum of components across the full timeline; max |err| = \(maxAbsErr)")
        // And specifically at the asymptote: combined ≈ bolus_asym + suspend_asym = -50 + 50 = 0
        let lastBoth = effectsBoth.last!.quantity.doubleValue(for: unit)
        XCTAssertEqual(lastBoth, 0, accuracy: 0.5,
            "Asymptotic combined effect of +1 U bolus + -1 U net suspend ≈ 0; got \(lastBoth)")
    }

    // MARK: - glucoseEffects ↔ glucoseEffectsMidAbsorptionISF agreement (constant ISF)

    func testGlucoseEffectsMidAbsorptionEqualsStandardWhenISFConstant() {
        // When sensitivity is constant across the absorption window, the
        // mid-absorption variant must produce equal output to the standard one.
        let start = date("2025-01-01T12:00:00")
        let doses: [BasalRelativeDose] = [
            BasalRelativeDose(type: .bolus, startDate: start, endDate: start, volume: 2.0),
            BasalRelativeDose(
                type: .basal(scheduledRate: 1.0),
                startDate: start.addingTimeInterval(.hours(1)),
                endDate:   start.addingTimeInterval(.hours(3)),
                volume: 0.0
            ),
            BasalRelativeDose(type: .bolus,
                              startDate: start.addingTimeInterval(.hours(2)),
                              endDate:   start.addingTimeInterval(.hours(2)),
                              volume: 0.5),
        ]
        let isf = constantISF(45.0, around: start)
        let standard = doses.glucoseEffects(insulinSensitivityHistory: isf)
        let midAbs = doses.glucoseEffectsMidAbsorptionISF(insulinSensitivityHistory: isf)
        XCTAssertEqual(standard.count, midAbs.count)
        for (s, m) in zip(standard, midAbs) {
            XCTAssertEqual(s.startDate, m.startDate)
            XCTAssertEqual(
                s.quantity.doubleValue(for: unit),
                m.quantity.doubleValue(for: unit),
                accuracy: 0.01,
                "standard and mid-abs ISF must agree when ISF is constant")
        }
    }

    // MARK: - insulinCorrection reads the full schedule across forecast horizon

    func testInsulinCorrectionUsesFullSensitivitySchedule() {
        // Construct a prediction that drops uniformly across the forecast
        // horizon, and a sensitivity SCHEDULE with TWO different values:
        // 50 mg/dL/U for the first half-horizon, 100 mg/dL/U for the second.
        // The correction units required to bring BG to target should reflect
        // the integrated sensitivity over the prediction's absorption window,
        // NOT just the value at delivery time.
        let model = ExponentialInsulinModelPreset.rapidActingAdult.model
        let deliveryDate = date("2025-01-01T12:00:00")
        let halfHorizon: TimeInterval = model.effectDuration / 2

        // Prediction: a constant BG of 200 mg/dL across the full horizon.
        var prediction: [PredictedGlucoseValue] = []
        var t = deliveryDate
        while t <= deliveryDate.addingTimeInterval(model.effectDuration + .minutes(5)) {
            prediction.append(PredictedGlucoseValue(
                startDate: t,
                quantity: LoopQuantity(unit: unit, doubleValue: 200.0)
            ))
            t = t.addingTimeInterval(.minutes(5))
        }

        // Target = 100 mg/dL constant.
        let target: [AbsoluteScheduleValue<ClosedRange<LoopQuantity>>] = [
            AbsoluteScheduleValue(
                startDate: deliveryDate.addingTimeInterval(-.hours(1)),
                endDate:   deliveryDate.addingTimeInterval(.hours(24)),
                value: LoopQuantity(unit: unit, doubleValue: 100.0)...LoopQuantity(unit: unit, doubleValue: 100.0)
            )
        ]

        // Schedule A: constant 50 mg/dL/U across the horizon.
        let isfConstant: [AbsoluteScheduleValue<LoopQuantity>] = [
            AbsoluteScheduleValue(
                startDate: deliveryDate.addingTimeInterval(-.hours(1)),
                endDate:   deliveryDate.addingTimeInterval(.hours(24)),
                value: LoopQuantity(unit: unit, doubleValue: 50.0)
            )
        ]
        // Schedule B: 50 mg/dL/U first half, 100 mg/dL/U second half — higher
        // average sensitivity → fewer units needed for the same drop.
        let isfStepped: [AbsoluteScheduleValue<LoopQuantity>] = [
            AbsoluteScheduleValue(
                startDate: deliveryDate.addingTimeInterval(-.hours(1)),
                endDate:   deliveryDate.addingTimeInterval(halfHorizon),
                value: LoopQuantity(unit: unit, doubleValue: 50.0)
            ),
            AbsoluteScheduleValue(
                startDate: deliveryDate.addingTimeInterval(halfHorizon),
                endDate:   deliveryDate.addingTimeInterval(.hours(24)),
                value: LoopQuantity(unit: unit, doubleValue: 100.0)
            )
        ]

        let suspend = LoopQuantity(unit: unit, doubleValue: 70.0)

        let corrA = prediction.insulinCorrection(
            to: target,
            at: deliveryDate,
            suspendThreshold: suspend,
            insulinSensitivity: isfConstant,
            model: model
        )
        let corrB = prediction.insulinCorrection(
            to: target,
            at: deliveryDate,
            suspendThreshold: suspend,
            insulinSensitivity: isfStepped,
            model: model
        )

        // Extract the recommended units. Both should be in the .aboveRange case.
        let unitsA: Double
        let unitsB: Double
        if case let .aboveRange(_, _, _, units) = corrA {
            unitsA = units
        } else {
            XCTFail("corrA should be aboveRange"); return
        }
        if case let .aboveRange(_, _, _, units) = corrB {
            unitsB = units
        } else {
            XCTFail("corrB should be aboveRange"); return
        }
        // The stepped schedule has higher integrated sensitivity (50→100 vs constant 50)
        // → less insulin needed → unitsB < unitsA.
        XCTAssertLessThan(unitsB, unitsA,
            "Schedule with higher-sensitivity 2nd half should require fewer units; "
            + "constant=\(unitsA), stepped=\(unitsB)")
        // And specifically: a meaningful difference (not just numerical noise)
        XCTAssertGreaterThan(unitsA - unitsB, 0.05 * unitsA,
            "Difference should be material (>5% of constant-schedule recommendation)")
    }

    // MARK: - IOB sign behavior (today's convention)

    func testIOBSumsNetBasalUnitsAcrossMixedSignDoses() {
        // BasalRelativeDose's insulinOnBoard convolves netBasalUnits with the
        // insulin model. A bolus contributes positive IOB; a suspend
        // (negative net) contributes NEGATIVE IOB. Verify today's behavior at
        // a point shortly after both doses (so neither has decayed much).
        let start = date("2025-01-01T12:00:00")
        let bolus = BasalRelativeDose(type: .bolus, startDate: start, endDate: start, volume: 1.0)
        let suspend = BasalRelativeDose(
            type: .basal(scheduledRate: 1.0),
            startDate: start.addingTimeInterval(.hours(1)),
            endDate:   start.addingTimeInterval(.hours(2)),
            volume: 0.0  // net = -1
        )
        let iobBolus = [bolus].insulinOnBoard(at: start.addingTimeInterval(.minutes(30)))
        let iobSuspend = [suspend].insulinOnBoard(at: start.addingTimeInterval(.hours(1) + .minutes(30)))
        let iobBoth = [bolus, suspend].insulinOnBoard(at: start.addingTimeInterval(.hours(1) + .minutes(30)))

        XCTAssertGreaterThan(iobBolus, 0, "bolus IOB positive")
        XCTAssertLessThan(iobSuspend, 0, "suspended-temp IOB negative under current netUnits convention")
        // Linearity: combined IOB ≈ sum of component IOBs at same eval time.
        let iobBolusAt = [bolus].insulinOnBoard(at: start.addingTimeInterval(.hours(1) + .minutes(30)))
        XCTAssertEqual(iobBoth, iobBolusAt + iobSuspend, accuracy: 1e-6,
            "Combined IOB should equal sum of component IOBs (current netUnits convention)")
    }
}
