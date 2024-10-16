//
//  ManualBolusRecommendationTests.swift
//
//
//  Created by Pete Schwamb on 2/21/24.
//

import Foundation

import XCTest
@testable import LoopAlgorithm

final class ManualBolusRecommendationTests: XCTestCase {

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()


    func testRecommendationWithoutNoticeCodable() throws {
        let recommendation = ManualBolusRecommendation(amount: 1.0, notice: nil)
        let encoded = try encoder.encode(recommendation)
        XCTAssertEqual(
            """
            {
              "amount" : 1
            }
            """,
            String(data: encoded , encoding: .utf8)!)

        let decoded = try decoder.decode(ManualBolusRecommendation.self, from: encoded)
        XCTAssertEqual(decoded, recommendation)
    }

    func testAllGlucoseBelowTargetCodable() throws {
        let startDate = dateFormatter.date(from: "2015-07-13T12:02:37")!
        let recommendation = ManualBolusRecommendation(amount: 0, notice: .allGlucoseBelowTarget(minGlucose: .init(startDate: startDate, quantity: .glucose(55))))
        let encoded = try encoder.encode(recommendation)
        XCTAssertEqual(
            """
            {
              "amount" : 0,
              "notice" : {
                "allGlucoseBelowTarget" : {
                  "minGlucose" : {
                    "quantity" : 55,
                    "quantityUnit" : "mg/dL",
                    "startDate" : "2015-07-13T12:02:37Z"
                  }
                }
              }
            }
            """,
            String(data: encoded , encoding: .utf8)!)

        let decoded = try decoder.decode(ManualBolusRecommendation.self, from: encoded)
        XCTAssertEqual(decoded, recommendation)
    }

    func testCurrentGlucoseBelowTargetCodable() throws {
        let startDate = dateFormatter.date(from: "2015-07-13T12:02:37")!
        let recommendation = ManualBolusRecommendation(amount: 0, notice: .currentGlucoseBelowTarget(glucose: .init(startDate: startDate, quantity: .glucose(65))))
        let encoded = try encoder.encode(recommendation)
        XCTAssertEqual(
            """
            {
              "amount" : 0,
              "notice" : {
                "currentGlucoseBelowTarget" : {
                  "glucose" : {
                    "quantity" : 65,
                    "quantityUnit" : "mg/dL",
                    "startDate" : "2015-07-13T12:02:37Z"
                  }
                }
              }
            }
            """,
            String(data: encoded , encoding: .utf8)!)

        let decoded = try decoder.decode(ManualBolusRecommendation.self, from: encoded)
        XCTAssertEqual(decoded, recommendation)
    }

    func testPredictedGlucoseBelowTargetCodable() throws {
        let startDate = dateFormatter.date(from: "2015-07-13T12:02:37")!
        let recommendation = ManualBolusRecommendation(amount: 0, notice: .predictedGlucoseBelowTarget(minGlucose: .init(startDate: startDate, quantity: .glucose(65))))
        let encoded = try encoder.encode(recommendation)
        XCTAssertEqual(
            """
            {
              "amount" : 0,
              "notice" : {
                "predictedGlucoseBelowTarget" : {
                  "minGlucose" : {
                    "quantity" : 65,
                    "quantityUnit" : "mg/dL",
                    "startDate" : "2015-07-13T12:02:37Z"
                  }
                }
              }
            }
            """,
            String(data: encoded , encoding: .utf8)!)

        let decoded = try decoder.decode(ManualBolusRecommendation.self, from: encoded)
        XCTAssertEqual(decoded, recommendation)
    }

    func testPredictedGlucoseInRangeCodable() throws {
        let recommendation = ManualBolusRecommendation(amount: 0, notice: .predictedGlucoseInRange)
        let encoded = try encoder.encode(recommendation)
        XCTAssertEqual(
            """
            {
              "amount" : 0,
              "notice" : "predictedGlucoseInRange"
            }
            """,
            String(data: encoded , encoding: .utf8)!)

        let decoded = try decoder.decode(ManualBolusRecommendation.self, from: encoded)
        XCTAssertEqual(decoded, recommendation)
    }

    func testGlucoseBelowSuspendThresholdCodable() throws {
        let startDate = dateFormatter.date(from: "2015-07-13T12:02:37")!
        let recommendation = ManualBolusRecommendation(amount: 0, notice: .glucoseBelowSuspendThreshold(minGlucose: .init(startDate: startDate, quantity: .glucose(55))))
        let encoded = try encoder.encode(recommendation)
        XCTAssertEqual(
            """
            {
              "amount" : 0,
              "notice" : {
                "glucoseBelowSuspendThreshold" : {
                  "minGlucose" : {
                    "quantity" : 55,
                    "quantityUnit" : "mg/dL",
                    "startDate" : "2015-07-13T12:02:37Z"
                  }
                }
              }
            }
            """,
            String(data: encoded , encoding: .utf8)!)

        let decoded = try decoder.decode(ManualBolusRecommendation.self, from: encoded)
        XCTAssertEqual(decoded, recommendation)
    }
}

