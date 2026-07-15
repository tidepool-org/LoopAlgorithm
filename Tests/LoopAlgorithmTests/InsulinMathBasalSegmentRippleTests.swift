//
//  InsulinMathBasalSegmentRippleTests.swift
//
//  Regression test for the delta-scale IOB ripple that `insulinOnBoard` produced
//  for basal segments longer than one `delta` (i.e. essentially every real temp
//  basal / suspend). `continuousDeliveryInsulinOnBoard` previously quantized its
//  integration bound to the delta grid, stepping IOB at each delta boundary. It
//  now integrates continuously up to `time`, so a single long segment yields the
//  same smooth IOB as the equivalent finely-subdivided delivery.
//

import XCTest
@testable import LoopAlgorithm

final class InsulinMathBasalSegmentRippleTests: XCTestCase {

    private let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private func curvatureRMS(_ a: [Double]) -> Double {
        guard a.count >= 3 else { return 0 }
        var d2: [Double] = []
        for i in 2..<a.count {
            let v = a[i] - 2.0 * a[i - 1] + a[i - 2]
            d2.append(v)
        }
        var sum = 0.0
        for v in d2 { sum += v }
        let mean = sum / Double(d2.count)
        var ss = 0.0
        for v in d2 { ss += (v - mean) * (v - mean) }
        return (ss / Double(d2.count)).squareRoot()
    }

    private func maxAbsDiff(_ a: [Double], _ b: [Double]) -> Double {
        let n = Swift.min(a.count, b.count)
        var m = 0.0
        for i in 0..<n { m = Swift.max(m, Swift.abs(a[i] - b[i])) }
        return m
    }

    /// One 20-min suspend (delivered 0 vs scheduled 1.5 U/hr ⇒ net −0.5 U),
    /// modeled as a single 20-min segment vs an equivalent 1-min-subdivided
    /// delivery. After the fix the single segment's IOB is smooth and matches
    /// the fine subdivision (previously it rippled with maxΔ ~0.35 U).
    func testLongBasalSegmentIOBIsSmooth() {
        let start = fmt.date(from: "2020-01-01T00:00:00")!
        let schedRate = 1.5, deliveredRate = 0.0, segMin = 20.0

        func basal(_ a: Date, _ b: Date) -> BasalRelativeDose {
            let hrs = b.timeIntervalSince(a) / 3600
            return BasalRelativeDose(type: .basal(scheduledRate: schedRate),
                                     startDate: a, endDate: b, volume: deliveredRate * hrs)
        }
        let single = [basal(start, start.addingTimeInterval(segMin * 60))]
        let fine = (0..<Int(segMin)).map { k in
            basal(start.addingTimeInterval(Double(k) * 60), start.addingTimeInterval(Double(k + 1) * 60))
        }

        let end = start.addingTimeInterval(6 * 3600)
        func iob(_ doses: [BasalRelativeDose]) -> [Double] {
            doses.insulinOnBoardTimeline(from: start, to: end).map { $0.value }
        }
        let iobSingle = iob(single)
        let iobFine = iob(fine)

        let maxDiff = maxAbsDiff(iobSingle, iobFine)
        let curvSingle = curvatureRMS(iobSingle)
        let curvFine = curvatureRMS(iobFine)
        print(String(format: "\n[ripple-fix] single-vs-fine maxΔ=%.4f U   curvature single=%.5f fine=%.5f\n",
                     maxDiff, curvSingle, curvFine))

        // The single long segment is now as smooth as the finely-subdivided
        // delivery (no delta-scale ripple). Pre-fix curvature was ~0.18 (>20×).
        XCTAssertLessThan(curvSingle, 3 * curvFine + 0.005,
                          "long-segment IOB should be ~as smooth as the fine subdivision")
        // And close to the finely-subdivided equivalent delivery.
        XCTAssertLessThan(maxDiff, 0.05, "long-segment IOB should match the fine subdivision")
    }
}
