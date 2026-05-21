//
//  StandardRetrospectiveCorrectionTests.swift
//  LoopAlgorithm
//
//  Unit tests for StandardRetrospectiveCorrection (the P-only retrospective
//  correction controller). Standard RC takes the most-recent
//  prediction-vs-actual discrepancy and projects it forward as a decaying
//  glucose effect over `effectDuration` (default 60 min).
//

import XCTest
@testable import LoopAlgorithm

final class StandardRetrospectiveCorrectionTests: XCTestCase {

    private let unit = LoopUnit.milligramsPerDeciliter

    // MARK: - Helpers

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private func date(_ s: String) -> Date {
        return dateFormatter.date(from: s)!
    }

    private func change(from start: Date, to end: Date, mgdl: Double) -> GlucoseChange {
        return GlucoseChange(startDate: start, endDate: end, quantity: .glucose(mgdl))
    }

    private func makeRC() -> StandardRetrospectiveCorrection {
        return StandardRetrospectiveCorrection(
            effectDuration: LoopMath.retrospectiveCorrectionEffectDuration
        )
    }

    // MARK: - Recency gating

    func testStaleDiscrepancyClearsEffect() {
        // Discrepancy ends > recencyInterval before the starting glucose date.
        // Effect must be empty + totalGlucoseCorrectionEffect must be nil.
        let glucoseDate = date("2025-01-01T12:00:00")
        let startingGlucose = SimpleGlucoseValue(startDate: glucoseDate, quantity: .glucose(100))
        let discrepancy = change(
            from: glucoseDate.addingTimeInterval(-.minutes(60)),
            to: glucoseDate.addingTimeInterval(-.minutes(30)),
            mgdl: 10
        )
        let rc = makeRC()
        // recencyInterval = 15 min, but discrepancy ends 30 min ago → stale
        let effect = rc.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: [discrepancy],
            recencyInterval: .minutes(15),
            retrospectiveCorrectionGroupingInterval: .minutes(30)
        )
        XCTAssertTrue(effect.isEmpty, "stale discrepancy should produce no effect")
        XCTAssertNil(rc.totalGlucoseCorrectionEffect)
    }

    func testNilDiscrepancyListReturnsEmpty() {
        let glucoseDate = date("2025-01-01T12:00:00")
        let startingGlucose = SimpleGlucoseValue(startDate: glucoseDate, quantity: .glucose(100))
        let rc = makeRC()
        let effect = rc.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: nil,
            recencyInterval: .minutes(15),
            retrospectiveCorrectionGroupingInterval: .minutes(30)
        )
        XCTAssertTrue(effect.isEmpty)
        XCTAssertNil(rc.totalGlucoseCorrectionEffect)
    }

    func testEmptyDiscrepancyListReturnsEmpty() {
        let glucoseDate = date("2025-01-01T12:00:00")
        let startingGlucose = SimpleGlucoseValue(startDate: glucoseDate, quantity: .glucose(100))
        let rc = makeRC()
        let effect = rc.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: [],
            recencyInterval: .minutes(15),
            retrospectiveCorrectionGroupingInterval: .minutes(30)
        )
        XCTAssertTrue(effect.isEmpty)
        XCTAssertNil(rc.totalGlucoseCorrectionEffect)
    }

    // MARK: - Total correction effect

    func testTotalCorrectionEffectEqualsLatestDiscrepancy() {
        // Standard RC: totalGlucoseCorrectionEffect == latest discrepancy magnitude.
        let glucoseDate = date("2025-01-01T12:00:00")
        let startingGlucose = SimpleGlucoseValue(startDate: glucoseDate, quantity: .glucose(120))
        let rc = makeRC()
        _ = rc.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: [
                change(from: glucoseDate.addingTimeInterval(-.minutes(30)),
                       to: glucoseDate, mgdl: 15)
            ],
            recencyInterval: .minutes(15),
            retrospectiveCorrectionGroupingInterval: .minutes(30)
        )
        XCTAssertEqual(rc.totalGlucoseCorrectionEffect?.doubleValue(for: unit), 15.0)
    }

    // MARK: - Effect projection

    func testPositiveDiscrepancyProjectsForward() {
        // +12 mg/dL discrepancy over 30 min → decay over 60-min effectDuration.
        // The integrated effect should ramp from 0 at startingGlucose to ~+12
        // at endDate of effectDuration.
        let glucoseDate = date("2025-01-01T12:00:00")
        let startingGlucose = SimpleGlucoseValue(startDate: glucoseDate, quantity: .glucose(100))
        let rc = makeRC()
        let effect = rc.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: [
                change(from: glucoseDate.addingTimeInterval(-.minutes(30)),
                       to: glucoseDate, mgdl: 12)
            ],
            recencyInterval: .minutes(15),
            retrospectiveCorrectionGroupingInterval: .minutes(30)
        )
        XCTAssertFalse(effect.isEmpty)
        // Last sample should be roughly startingGlucose + 12 (decay applies the
        // proportional correction over the effect window)
        let last = effect.last!.quantity.doubleValue(for: unit)
        XCTAssertEqual(last, 112.0, accuracy: 0.5,
            "last projected glucose ≈ starting + discrepancy")
    }

    func testNegativeDiscrepancyProjectsDownward() {
        let glucoseDate = date("2025-01-01T12:00:00")
        let startingGlucose = SimpleGlucoseValue(startDate: glucoseDate, quantity: .glucose(150))
        let rc = makeRC()
        let effect = rc.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: [
                change(from: glucoseDate.addingTimeInterval(-.minutes(30)),
                       to: glucoseDate, mgdl: -10)
            ],
            recencyInterval: .minutes(15),
            retrospectiveCorrectionGroupingInterval: .minutes(30)
        )
        XCTAssertFalse(effect.isEmpty)
        let last = effect.last!.quantity.doubleValue(for: unit)
        XCTAssertEqual(last, 140.0, accuracy: 0.5,
            "last projected glucose ≈ starting + (negative) discrepancy")
        XCTAssertEqual(rc.totalGlucoseCorrectionEffect?.doubleValue(for: unit), -10.0)
    }

    func testEffectStartsAtStartingGlucoseValue() {
        // First effect sample should equal startingGlucose value (correction
        // has not yet had time to apply).
        let glucoseDate = date("2025-01-01T12:00:00")
        let startingGlucose = SimpleGlucoseValue(startDate: glucoseDate, quantity: .glucose(110))
        let rc = makeRC()
        let effect = rc.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: [
                change(from: glucoseDate.addingTimeInterval(-.minutes(30)),
                       to: glucoseDate, mgdl: 20)
            ],
            recencyInterval: .minutes(15),
            retrospectiveCorrectionGroupingInterval: .minutes(30)
        )
        XCTAssertFalse(effect.isEmpty)
        XCTAssertEqual(effect.first!.quantity.doubleValue(for: unit), 110.0, accuracy: 0.01)
        XCTAssertEqual(effect.first!.startDate, glucoseDate)
    }

    // MARK: - Multiple discrepancies — only LATEST is used

    func testOnlyMostRecentDiscrepancyIsUsed() {
        // Standard RC uses ONLY .last — older entries are ignored even when
        // they would change the answer (this is exactly what IntegralRC fixes).
        let glucoseDate = date("2025-01-01T12:00:00")
        let startingGlucose = SimpleGlucoseValue(startDate: glucoseDate, quantity: .glucose(100))
        let rc = makeRC()
        let effect = rc.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: [
                change(from: glucoseDate.addingTimeInterval(-.minutes(150)),
                       to: glucoseDate.addingTimeInterval(-.minutes(120)), mgdl: 50),  // big older
                change(from: glucoseDate.addingTimeInterval(-.minutes(60)),
                       to: glucoseDate.addingTimeInterval(-.minutes(30)), mgdl: 30),   // medium older
                change(from: glucoseDate.addingTimeInterval(-.minutes(30)),
                       to: glucoseDate, mgdl: 5),                                       // small latest
            ],
            recencyInterval: .minutes(15),
            retrospectiveCorrectionGroupingInterval: .minutes(30)
        )
        // Total effect must reflect ONLY the most recent (+5), not the larger older ones.
        XCTAssertEqual(rc.totalGlucoseCorrectionEffect?.doubleValue(for: unit), 5.0)
        XCTAssertEqual(effect.last!.quantity.doubleValue(for: unit), 105.0, accuracy: 0.5)
    }

    // MARK: - Grouping interval clamps short discrepancies

    func testShortDiscrepancyClampedByGroupingInterval() {
        // If the discrepancy's interval is shorter than retrospectiveCorrection-
        // GroupingInterval, the velocity calc uses groupingInterval as the
        // denominator (not the actual interval). This protects against over-
        // amplified projections from very short discrepancies.
        let glucoseDate = date("2025-01-01T12:00:00")
        let startingGlucose = SimpleGlucoseValue(startDate: glucoseDate, quantity: .glucose(100))
        let rc = makeRC()
        // Discrepancy is +10 over only 5 minutes (very short window). If we
        // used 5 min as the denominator, velocity would be 6× larger.
        let effect = rc.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: [
                change(from: glucoseDate.addingTimeInterval(-.minutes(5)),
                       to: glucoseDate, mgdl: 10)
            ],
            recencyInterval: .minutes(15),
            retrospectiveCorrectionGroupingInterval: .minutes(30)
        )
        XCTAssertFalse(effect.isEmpty)
        // Total effect over the effectDuration should still be ~+10 (the
        // proportional correction), but spread over the full duration not
        // amplified for the short window.
        let last = effect.last!.quantity.doubleValue(for: unit)
        XCTAssertEqual(last, 110.0, accuracy: 0.5)
    }
}
