//
//  IntegralRetrospectiveCorrectionTests.swift
//  
//
//  Created by Pete Schwamb on 2/21/24.
//

import XCTest
@testable import LoopAlgorithm

final class IntegralRetrospectiveCorrectionTests: XCTestCase {

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()


    func testIntegralRestrospectiveCorrection() {
        let startDate = dateFormatter.date(from: "2015-07-13T12:02:37")!

        func d(_ interval: TimeInterval) -> Date {
            return startDate.addingTimeInterval(interval)
        }

        let startingGlucose = SimpleGlucoseValue(startDate: startDate, quantity: .glucose(100))

        // +10 mg/dL over 30 minutes
        let retrospectiveGlucoseDiscrepanciesSummed = [
            GlucoseChange(startDate: d(.minutes(-30)), endDate: startDate, quantity: .glucose(10))
        ]

        let irc = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)

        let effect = irc.computeEffect(
            startingAt: startingGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: retrospectiveGlucoseDiscrepanciesSummed,
            recencyInterval:  TimeInterval(minutes: 15),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval
        )

        XCTAssertEqual(effect.last?.quantity.doubleValue(for: .milligramsPerDeciliter), 110)
        XCTAssertEqual(effect.last?.startDate, dateFormatter.date(from: "2015-07-13T13:00:00")!)
    }
}
