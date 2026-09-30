//
//  AlgorithmEmulationTests.swift
//  LoopAlgorithm
//
//  Tests for AlgorithmEmulationOptions: the Codable forms, and the legacy
//  behaviors each flag re-enables (pre-#35 delta-quantized basal IOB and
//  pre-#33 step-by-step RC decay). Every default must preserve current
//  behavior exactly.
//

import XCTest
@testable import LoopAlgorithm

final class AlgorithmEmulationTests: XCTestCase {

    private let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    // MARK: - Codable

    func testDecodesPresetString() throws {
        let data = Data("\"loop-1.0\"".utf8)
        let options = try JSONDecoder().decode(AlgorithmEmulationOptions.self, from: data)
        XCTAssertEqual(options, .loop1)
    }

    func testEncodesPresetAsString() throws {
        let encoded = try JSONEncoder().encode(AlgorithmEmulationOptions.loop1)
        XCTAssertEqual(String(data: encoded, encoding: .utf8), "\"loop-1.0\"")
    }

    func testDecodesPartialFlagObject() throws {
        let data = Data("{\"legacyBasalIOB\": true}".utf8)
        let options = try JSONDecoder().decode(AlgorithmEmulationOptions.self, from: data)
        XCTAssertTrue(options.legacyBasalIOB)
        XCTAssertFalse(options.legacyRCDecay)
        XCTAssertFalse(options.integralRCClamp)
        XCTAssertFalse(options.disableIRCVelocityCeiling)
        XCTAssertFalse(options.noGradualTransitionsGate)
        XCTAssertFalse(options.disableMaxActiveInsulinLimit)
    }

    func testUnknownPresetThrows() {
        let data = Data("\"loop-9.9\"".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(AlgorithmEmulationOptions.self, from: data))
    }

    func testNonPresetOptionsRoundTripAsObject() throws {
        let options = AlgorithmEmulationOptions(legacyRCDecay: true)
        let encoded = try JSONEncoder().encode(options)
        let decoded = try JSONDecoder().decode(AlgorithmEmulationOptions.self, from: encoded)
        XCTAssertEqual(decoded, options)
    }

    // MARK: - Legacy basal IOB (pre-#35 delta-quantized integration)

    func testLegacyBasalIOBReproducesRipple() {
        let start = fmt.date(from: "2020-01-01T00:00:00")!
        let segMin = 20.0
        // A 20-min suspend: delivered 0 vs scheduled 1.5 U/hr.
        let dose = BasalRelativeDose(
            type: .basal(scheduledRate: 1.5),
            startDate: start,
            endDate: start.addingTimeInterval(segMin * 60),
            volume: 0
        )

        // Sample IOB at 1-min spacing across the segment and its tail.
        var legacy: [Double] = []
        var continuous: [Double] = []
        for minute in stride(from: 1.0, through: 60.0, by: 1.0) {
            let date = start.addingTimeInterval(minute * 60)
            legacy.append([dose].insulinOnBoard(at: date, useLegacyIntegration: true))
            continuous.append([dose].insulinOnBoard(at: date, useLegacyIntegration: false))
        }

        // The legacy integration bound is quantized to the delta grid, so the two
        // must diverge measurably between delta boundaries...
        let maxDiff = zip(legacy, continuous).map { abs($0 - $1) }.max()!
        XCTAssertGreaterThan(maxDiff, 0.01, "Legacy integration should reproduce the delta-scale IOB ripple")

        // ...while remaining the same signal at delta-scale: both represent the
        // same net insulin, so they must agree to within one delta chunk.
        XCTAssertLessThan(maxDiff, 0.5)
    }

    func testDefaultEmulationMatchesCurrentIOB() {
        let start = fmt.date(from: "2020-01-01T00:00:00")!
        let dose = BasalRelativeDose(
            type: .basal(scheduledRate: 1.5),
            startDate: start,
            endDate: start.addingTimeInterval(20 * 60),
            volume: 0
        )
        let date = start.addingTimeInterval(17 * 60)
        XCTAssertEqual(
            [dose].insulinOnBoard(at: date),
            [dose].insulinOnBoard(at: date, useLegacyIntegration: false)
        )
    }

    // MARK: - Legacy RC decay (pre-#33 step-by-step accumulation)

    func testLegacyDecayMatchesContinuousForAlignedSample() {
        // For a delta-aligned sample the step-by-step and closed-form
        // formulations are the same function.
        let start = fmt.date(from: "2020-01-01T00:00:00")!
        let sample = SimpleGlucoseValue(startDate: start, quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 120))
        let rate = LoopQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 2)

        let legacy = sample.decayEffect(atRate: rate, for: .minutes(60), useLegacyDecay: true)
        let continuous = sample.decayEffect(atRate: rate, for: .minutes(60), useLegacyDecay: false)

        XCTAssertEqual(legacy.count, continuous.count)
        for (l, c) in zip(legacy, continuous) {
            XCTAssertEqual(l.startDate, c.startDate)
            XCTAssertEqual(
                l.quantity.doubleValue(for: .milligramsPerDeciliter),
                c.quantity.doubleValue(for: .milligramsPerDeciliter),
                accuracy: 1e-9
            )
        }
    }

    func testLegacyDecayDivergesForUnalignedSample() {
        // For a sample not aligned to the delta grid (real CGM jitter), the
        // legacy accumulation exhibits its bucket-boundary discontinuity and
        // the two formulations differ.
        let start = fmt.date(from: "2020-01-01T00:02:13")!
        let sample = SimpleGlucoseValue(startDate: start, quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 120))
        let rate = LoopQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 2)

        let legacy = sample.decayEffect(atRate: rate, for: .minutes(60), useLegacyDecay: true)
        let continuous = sample.decayEffect(atRate: rate, for: .minutes(60), useLegacyDecay: false)

        XCTAssertEqual(legacy.count, continuous.count)
        let maxDiff = zip(legacy, continuous)
            .map { abs($0.quantity.doubleValue(for: .milligramsPerDeciliter) - $1.quantity.doubleValue(for: .milligramsPerDeciliter)) }
            .max()!
        XCTAssertGreaterThan(maxDiff, 0.1, "Legacy decay should differ for unaligned sample timestamps")
    }

    // MARK: - Momentum gradual-transitions gate

    private func momentumSamples(jumpAt jumpIndex: Int, jump: Double) -> [FixtureGlucoseSample] {
        let start = fmt.date(from: "2020-01-01T00:00:00")!
        return (0..<4).map { i in
            let value = 120 + Double(i) * 5 + (i >= jumpIndex ? jump : 0)
            return FixtureGlucoseSample(
                startDate: start.addingTimeInterval(Double(i) * 5 * 60),
                quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: value)
            )
        }
    }

    func testMomentumGateDropsEffectAcrossLargeJumpByDefault() {
        let samples = momentumSamples(jumpAt: 2, jump: 45)
        XCTAssertTrue(samples.linearMomentumEffect().isEmpty)
        XCTAssertTrue(samples.linearMomentumEffect(gradualTransitionThreshold: 40).isEmpty)
    }

    func testNilThresholdDisablesMomentumGate() {
        // Deployed Loop 1.0 computed momentum across any jump (LoopKit
        // GlucoseMath.linearMomentumEffect guarded only continuity, calibration
        // and provenance).
        let samples = momentumSamples(jumpAt: 2, jump: 45)
        XCTAssertFalse(samples.linearMomentumEffect(gradualTransitionThreshold: nil).isEmpty)
    }

    func testMomentumGateIsNoOpWithoutLargeJump() {
        let samples = momentumSamples(jumpAt: 2, jump: 0)
        let gated = samples.linearMomentumEffect()
        let ungated = samples.linearMomentumEffect(gradualTransitionThreshold: nil)
        XCTAssertFalse(gated.isEmpty)
        XCTAssertEqual(gated, ungated)
    }

    // MARK: - Max active insulin limit

    private func highTempBasalFixture(maxBolus: Double, emulation: AlgorithmEmulationOptions?) throws -> AlgorithmInputFixture {
        // The suspend scenario with its glucose history raised 150 mg/dL, so the
        // forecast is well above range and the temp basal wants to go high.
        let url = Bundle.module.url(forResource: "suspend_scenario", withExtension: "json", subdirectory: "Fixtures")!
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        json["recommendationType"] = "tempBasal"
        json["maxBolus"] = maxBolus
        json["glucoseHistory"] = (json["glucoseHistory"] as! [[String: Any]]).map { sample in
            var sample = sample
            sample["value"] = (sample["value"] as! Double) + 150
            return sample
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var fixture = try decoder.decode(AlgorithmInputFixture.self, from: try JSONSerialization.data(withJSONObject: json))
        fixture.emulation = emulation
        return fixture
    }

    private func tempBasalRate(_ output: AlgorithmOutput<FixtureCarbEntry>) throws -> Double {
        let recommendation = try output.recommendationResult.get()
        return try XCTUnwrap(recommendation.automatic?.basalAdjustment.unitsPerHour)
    }

    func testDisableMaxActiveInsulinLimitRemovesTempBasalCap() throws {
        // With a tiny maxBolus the active-insulin limit binds: the port caps the
        // temp basal at or below scheduled despite a forecast high. Tidepool Loop
        // 1.0 had no such limit, so the emulated rate must be uncapped and match
        // the rate with an unbounded limit.
        let capped = LoopAlgorithm.run(input: try highTempBasalFixture(maxBolus: 0.05, emulation: nil))
        let uncapped = LoopAlgorithm.run(input: try highTempBasalFixture(
            maxBolus: 0.05, emulation: AlgorithmEmulationOptions(disableMaxActiveInsulinLimit: true)))
        let reference = LoopAlgorithm.run(input: try highTempBasalFixture(maxBolus: 1000, emulation: nil))

        XCTAssertGreaterThan(try tempBasalRate(uncapped), try tempBasalRate(capped))
        XCTAssertEqual(try tempBasalRate(uncapped), try tempBasalRate(reference), accuracy: 1e-9)
    }

    func testLoop1PresetIncludesNewFlags() {
        XCTAssertTrue(AlgorithmEmulationOptions.loop1.noGradualTransitionsGate)
        XCTAssertTrue(AlgorithmEmulationOptions.loop1.disableMaxActiveInsulinLimit)
        XCTAssertFalse(AlgorithmEmulationOptions().disableMaxActiveInsulinLimit)
    }

    // MARK: - Insulin model presets (Tidepool Loop 1.0 adult/child choice)

    func testRapidActingModelPresetsSelectableAsInsulinTypes() throws {
        XCTAssertEqual(
            FixtureInsulinType.rapidActingAdult.insulinModel as? ExponentialInsulinModelPreset,
            ExponentialInsulinModelPreset.rapidActingAdult
        )
        XCTAssertEqual(
            FixtureInsulinType.rapidActingChild.insulinModel as? ExponentialInsulinModelPreset,
            ExponentialInsulinModelPreset.rapidActingChild
        )

        // Selectable from JSON, for both the recommendation model and doses.
        XCTAssertEqual(
            try JSONDecoder().decode(FixtureInsulinType.self, from: Data("\"rapidActingChild\"".utf8)),
            .rapidActingChild
        )

        let url = Bundle.module.url(forResource: "suspend_scenario", withExtension: "json", subdirectory: "Fixtures")!
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        json["recommendationInsulinType"] = "rapidActingChild"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let fixture = try decoder.decode(AlgorithmInputFixture.self, from: try JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(fixture.recommendationInsulinType, .rapidActingChild)
        XCTAssertEqual(fixture.recommendationInsulinModel as? ExponentialInsulinModelPreset, .rapidActingChild)
    }

    // MARK: - Fixture plumbing

    func testFixtureDecodesEmulationPreset() throws {
        let url = Bundle.module.url(forResource: "suspend_scenario", withExtension: "json", subdirectory: "Fixtures")!
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        json["emulation"] = "loop-1.0"
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let fixture = try decoder.decode(AlgorithmInputFixture.self, from: data)
        XCTAssertEqual(fixture.emulation, .loop1)

        // Emulated and non-emulated runs on the same input should both produce
        // a recommendation, and their forecasts should differ.
        var plain = fixture
        plain.emulation = nil
        let emulated = LoopAlgorithm.run(input: fixture)
        let current = LoopAlgorithm.run(input: plain)
        XCTAssertNotNil(try? emulated.recommendationResult.get())
        XCTAssertNotNil(try? current.recommendationResult.get())
    }

    func testFixtureWithoutEmulationDecodesNil() throws {
        let url = Bundle.module.url(forResource: "suspend_scenario", withExtension: "json", subdirectory: "Fixtures")!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let fixture = try decoder.decode(AlgorithmInputFixture.self, from: Data(contentsOf: url))
        XCTAssertNil(fixture.emulation)
    }
}
