//
//  InsulinDoseTests.swift
//  LoopAlgorithm
//
//  Created by Pete Schwamb on 9/24/24.
//


import XCTest
@testable import LoopAlgorithm

class InsulinDoseTests: XCTestCase {

    func testAnnotatedWithSingleBasalSchedule() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600) // 1 hour

        let dose = TestInsulinDose(
            deliveryType: .basal,
            startDate: startDate,
            endDate: endDate,
            volume: 1.0
        )

        let basalHistory = [
            AbsoluteScheduleValue(startDate: startDate, endDate: endDate, value: 1.0)
        ]

        let annotatedDoses = dose.annotated(with: basalHistory)

        XCTAssertEqual(annotatedDoses.count, 1)
        XCTAssertEqual(annotatedDoses[0].type, .basal(scheduledRate: 1.0))
        XCTAssertEqual(annotatedDoses[0].startDate, startDate)
        XCTAssertEqual(annotatedDoses[0].endDate, endDate)
        XCTAssertEqual(annotatedDoses[0].volume, 1.0)
    }

    func testAnnotatedWithBasalEndingBeforeDose() {
        let startDate = Date()
        let middleDate = startDate.addingTimeInterval(1800) // 30 minutes
        let endDate = startDate.addingTimeInterval(3600) // 1 hour

        let dose = TestInsulinDose(
            deliveryType: .basal,
            startDate: startDate,
            endDate: endDate,
            volume: 1.0
        )

        let basalHistory = [
            AbsoluteScheduleValue(startDate: startDate, endDate: middleDate, value: 1.0)
        ]

        let annotatedDoses = dose.annotated(with: basalHistory)

        XCTAssertEqual(annotatedDoses.count, 1)
        XCTAssertEqual(annotatedDoses[0].type, .basal(scheduledRate: 1.0))
        XCTAssertEqual(annotatedDoses[0].startDate, startDate)
        XCTAssertEqual(annotatedDoses[0].endDate, endDate)
        XCTAssertEqual(annotatedDoses[0].volume, 1.0)
    }


    func testAnnotatedWithMultipleBasalSchedules() {
        let startDate = Date()
        let middleDate = startDate.addingTimeInterval(1800) // 30 minutes
        let endDate = startDate.addingTimeInterval(3600) // 1 hour

        let dose = TestInsulinDose(
            deliveryType: .basal,
            startDate: startDate,
            endDate: endDate,
            volume: 2.0
        )

        let basalHistory = [
            AbsoluteScheduleValue(startDate: startDate, endDate: middleDate, value: 1.0),
            AbsoluteScheduleValue(startDate: middleDate, endDate: endDate, value: 2.0)
        ]

        let annotatedDoses = dose.annotated(with: basalHistory)

        XCTAssertEqual(annotatedDoses.count, 2)

        XCTAssertEqual(annotatedDoses[0].type, .basal(scheduledRate: 1.0))
        XCTAssertEqual(annotatedDoses[0].startDate, startDate)
        XCTAssertEqual(annotatedDoses[0].endDate, middleDate)
        XCTAssertEqual(annotatedDoses[0].volume, 1.0)

        XCTAssertEqual(annotatedDoses[1].type, .basal(scheduledRate: 2.0))
        XCTAssertEqual(annotatedDoses[1].startDate, middleDate)
        XCTAssertEqual(annotatedDoses[1].endDate, endDate)
        XCTAssertEqual(annotatedDoses[1].volume, 1.0)
    }

    func testAnnotatedWithOverlappingBasalSchedules() {
        let startDate = Date()
        let middleDate1 = startDate.addingTimeInterval(1200) // 20 minutes
        let middleDate2 = startDate.addingTimeInterval(2400) // 40 minutes
        let endDate = startDate.addingTimeInterval(3600) // 1 hour

        let dose = TestInsulinDose(
            deliveryType: .basal,
            startDate: startDate,
            endDate: endDate,
            volume: 3.0
        )

        let basalHistory = [
            AbsoluteScheduleValue(startDate: startDate, endDate: middleDate1, value: 1.0),
            AbsoluteScheduleValue(startDate: middleDate1, endDate: middleDate2, value: 1.5),
            AbsoluteScheduleValue(startDate: middleDate2, endDate: endDate, value: 2.0)
        ]

        let annotatedDoses = dose.annotated(with: basalHistory)

        XCTAssertEqual(annotatedDoses.count, 3)

        XCTAssertEqual(annotatedDoses[0].type, .basal(scheduledRate: 1.0))
        XCTAssertEqual(annotatedDoses[0].startDate, startDate)
        XCTAssertEqual(annotatedDoses[0].endDate, middleDate1)
        XCTAssertEqual(annotatedDoses[0].volume, 1.0)

        XCTAssertEqual(annotatedDoses[1].type, .basal(scheduledRate: 1.5))
        XCTAssertEqual(annotatedDoses[1].startDate, middleDate1)
        XCTAssertEqual(annotatedDoses[1].endDate, middleDate2)
        XCTAssertEqual(annotatedDoses[1].volume, 1.0)

        XCTAssertEqual(annotatedDoses[2].type, .basal(scheduledRate: 2.0))
        XCTAssertEqual(annotatedDoses[2].startDate, middleDate2)
        XCTAssertEqual(annotatedDoses[2].endDate, endDate)
        XCTAssertEqual(annotatedDoses[2].volume, 1.0)
    }

    func testAnnotatedWithZeroDuration() {
        let startDate = Date()

        let dose = TestInsulinDose(
            deliveryType: .basal,
            startDate: startDate,
            endDate: startDate,
            volume: 0.0
        )

        let basalHistory = [
            AbsoluteScheduleValue(startDate: startDate, endDate: startDate.addingTimeInterval(3600), value: 1.0)
        ]

        let annotatedDoses = dose.annotated(with: basalHistory)

        XCTAssertEqual(annotatedDoses.count, 1)
        XCTAssertEqual(annotatedDoses[0].type, .basal(scheduledRate: 1.0))
        XCTAssertEqual(annotatedDoses[0].startDate, startDate)
        XCTAssertEqual(annotatedDoses[0].endDate, startDate)
        XCTAssertEqual(annotatedDoses[0].volume, 0.0)
    }
}

// Helper struct for testing
struct TestInsulinDose: InsulinDose {
    var insulinModel: InsulinModel {
        return ExponentialInsulinModelPreset.rapidActingAdult.model
    }
    var deliveryType: InsulinDeliveryType
    var startDate: Date
    var endDate: Date
    var volume: Double
}
