//
//  FilterDateRangeTests.swift
//  LoopAlgorithm
//
//  Tests for the binary-search filterDateRange overload on
//  RandomAccessCollection<TimelineValue> — must produce identical output
//  to the Sequence-based linear-filter version.
//

import XCTest
@testable import LoopAlgorithm

final class FilterDateRangeTests: XCTestCase {

    /// Minimal TimelineValue with a date range.
    private struct Sample: TimelineValue, Equatable, CustomStringConvertible {
        let startDate: Date
        let endDate: Date
        let id: Int
        var description: String { "Sample(id=\(id), start=\(startDate.timeIntervalSinceReferenceDate.rounded()), end=\(endDate.timeIntervalSinceReferenceDate.rounded()))" }
    }

    /// Linear-scan reference implementation (the Sequence-based version that
    /// the binary-search overload must match).
    private func linearFilter(_ items: [Sample], _ start: Date?, _ end: Date?) -> [Sample] {
        return items.filter { value in
            if let start, value.endDate < start { return false }
            if let end, value.startDate > end { return false }
            return true
        }
    }

    private func contiguousSamples(count: Int, segmentSeconds: TimeInterval = 300,
                                   startingAt: Date = Date(timeIntervalSince1970: 1700000000)) -> [Sample] {
        return (0..<count).map { i in
            Sample(
                startDate: startingAt.addingTimeInterval(TimeInterval(i) * segmentSeconds),
                endDate: startingAt.addingTimeInterval(TimeInterval(i + 1) * segmentSeconds),
                id: i
            )
        }
    }

    // MARK: - Equivalence

    func testEmptyCollection() {
        let empty: [Sample] = []
        XCTAssertEqual(empty.filterDateRange(Date(), Date().addingTimeInterval(60)), [])
    }

    func testBothBoundsNil() {
        let samples = contiguousSamples(count: 20)
        XCTAssertEqual(samples.filterDateRange(nil, nil), samples)
    }

    func testOnlyStartDate() {
        let samples = contiguousSamples(count: 20)
        let start = samples[5].startDate
        XCTAssertEqual(samples.filterDateRange(start, nil),
                       linearFilter(samples, start, nil))
    }

    func testOnlyEndDate() {
        let samples = contiguousSamples(count: 20)
        let end = samples[15].endDate
        XCTAssertEqual(samples.filterDateRange(nil, end),
                       linearFilter(samples, nil, end))
    }

    func testBothBoundsInMiddle() {
        let samples = contiguousSamples(count: 20)
        let start = samples[5].startDate
        let end = samples[15].endDate
        XCTAssertEqual(samples.filterDateRange(start, end),
                       linearFilter(samples, start, end))
    }

    func testStartBeforeAll() {
        let samples = contiguousSamples(count: 20)
        let start = samples[0].startDate.addingTimeInterval(-3600)
        XCTAssertEqual(samples.filterDateRange(start, nil),
                       linearFilter(samples, start, nil))
    }

    func testEndAfterAll() {
        let samples = contiguousSamples(count: 20)
        let end = samples.last!.endDate.addingTimeInterval(3600)
        XCTAssertEqual(samples.filterDateRange(nil, end),
                       linearFilter(samples, nil, end))
    }

    func testRangeFullyOutsideAllSamples() {
        let samples = contiguousSamples(count: 20)
        let start = samples.last!.endDate.addingTimeInterval(60)
        let end = samples.last!.endDate.addingTimeInterval(3600)
        XCTAssertEqual(samples.filterDateRange(start, end), [])
    }

    func testRangeBeforeAllSamples() {
        let samples = contiguousSamples(count: 20)
        let start = samples[0].startDate.addingTimeInterval(-3600)
        let end = samples[0].startDate.addingTimeInterval(-60)
        XCTAssertEqual(samples.filterDateRange(start, end), [])
    }

    func testRangeExactlyMatchesOneSegment() {
        let samples = contiguousSamples(count: 20)
        let s = samples[7]
        XCTAssertEqual(samples.filterDateRange(s.startDate, s.endDate),
                       linearFilter(samples, s.startDate, s.endDate))
    }

    func testRandomizedFuzz() {
        // 100 random queries on a 200-element schedule.
        let samples = contiguousSamples(count: 200)
        let baseT = samples[0].startDate.timeIntervalSinceReferenceDate
        let totalSpan = samples.last!.endDate.timeIntervalSince(samples[0].startDate)
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<100 {
            let startOffset = Double.random(in: -1000...(totalSpan + 1000), using: &rng)
            let endOffset = startOffset + Double.random(in: 0...(totalSpan + 1000), using: &rng)
            let start = Date(timeIntervalSinceReferenceDate: baseT + startOffset)
            let end = Date(timeIntervalSinceReferenceDate: baseT + endOffset)
            XCTAssertEqual(samples.filterDateRange(start, end),
                           linearFilter(samples, start, end),
                           "binary-search and linear filter must agree for [\(start), \(end)]")
        }
    }

    func testSingleSampleCollection() {
        let samples = contiguousSamples(count: 1)
        let s = samples[0]
        XCTAssertEqual(samples.filterDateRange(s.startDate, s.endDate), samples)
        XCTAssertEqual(samples.filterDateRange(nil, nil), samples)
        XCTAssertEqual(samples.filterDateRange(s.endDate.addingTimeInterval(60), nil), [])
        XCTAssertEqual(samples.filterDateRange(nil, s.startDate.addingTimeInterval(-60)), [])
    }
}
