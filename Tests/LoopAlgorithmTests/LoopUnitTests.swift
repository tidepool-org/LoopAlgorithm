//
//  LoopUnitTests.swift
//  LoopAlgorithm
//
//  Created by Cameron Ingham on 11/12/24.
//

import XCTest
@testable import LoopAlgorithm
import HealthKit

class LoopUnitTests: XCTestCase {
    
    func testGram() {
        let unit = LoopUnit.gram
        let hkUnit = HKUnit.gram()
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testGramsPerUnit() {
        let unit = LoopUnit.gramsPerUnit
        let hkUnit = HKUnit.gram().unitDivided(by: .internationalUnit())
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testInternationalUnit() {
        let unit = LoopUnit.internationalUnit
        let hkUnit = HKUnit.internationalUnit()
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testInternationalUnitsPerHour() {
        let unit = LoopUnit.internationalUnitsPerHour
        let hkUnit = HKUnit.internationalUnit().unitDivided(by: .hour())
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testMilligramsPerDeciliter() {
        let unit = LoopUnit.milligramsPerDeciliter
        let hkUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testMilligramsPerDeciliterPerSecond() {
        let unit = LoopUnit.milligramsPerDeciliterPerSecond
        let hkUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci)).unitDivided(by: .second())
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testMilligramsPerDeciliterPerMinute() {
        let unit = LoopUnit.milligramsPerDeciliterPerMinute
        let hkUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci)).unitDivided(by: .minute())
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testMilligramsPerDeciliterPerInternationalUnit() {
        let unit = LoopUnit.milligramsPerDeciliterPerInternationalUnit
        let hkUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci)).unitDivided(by: .internationalUnit())
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testMillimolesPerLiter() {
        let unit = LoopUnit.millimolesPerLiter
        let hkUnit = HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter())
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testMillimolesPerLiterPerSecond() {
        let unit = LoopUnit.millimolesPerLiterPerSecond
        let hkUnit = HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter()).unitDivided(by: .second())
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testMillimolesPerLiterPerMinute() {
        let unit = LoopUnit.millimolesPerLiterPerMinute
        let hkUnit = HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter()).unitDivided(by: .minute())
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testMillimolesPerLiterPerInternationalUnit() {
        let unit = LoopUnit.millimolesPerLiterPerInternationalUnit
        let hkUnit = HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter()).unitDivided(by: .internationalUnit())
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testPercent() {
        let unit = LoopUnit.percent
        let hkUnit = HKUnit.percent()
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testHour() {
        let unit = LoopUnit.hour
        let hkUnit = HKUnit.hour()
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testMinute() {
        let unit = LoopUnit.minute
        let hkUnit = HKUnit.minute()
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testSecond() {
        let unit = LoopUnit.second
        let hkUnit = HKUnit.second()
        
        testUnitString(unit: unit, hkUnit: hkUnit)
        testUnitStringConversion(unit: unit, hkUnit: hkUnit)
    }
    
    func testTimeConversion() {
        var unit1 = LoopUnit.second
        var unit2 = LoopUnit.minute
        XCTAssertEqual(unit1.conversionFactor(from: unit2), 60)
        XCTAssertEqual(unit2.conversionFactor(from: unit1), 1/60)
        
        unit1 = LoopUnit.milligramsPerDeciliterPerSecond
        unit2 = LoopUnit.milligramsPerDeciliterPerMinute
        XCTAssertEqual(unit1.conversionFactor(from: unit2), 60)
        XCTAssertEqual(unit2.conversionFactor(from: unit1), 1/60)
        
        unit1 = LoopUnit.millimolesPerLiterPerSecond
        unit2 = LoopUnit.millimolesPerLiterPerMinute
        XCTAssertEqual(unit1.conversionFactor(from: unit2), 60)
        XCTAssertEqual(unit2.conversionFactor(from: unit1), 1/60)
        
        unit1 = LoopUnit.minute
        unit2 = LoopUnit.hour
        XCTAssertEqual(unit1.conversionFactor(from: unit2), 60)
        XCTAssertEqual(unit2.conversionFactor(from: unit1), 1/60)
        
        unit1 = LoopUnit.second
        unit2 = LoopUnit.hour
        XCTAssertEqual(unit1.conversionFactor(from: unit2), 3600)
        XCTAssertEqual(unit2.conversionFactor(from: unit1), 1/3600)
    }
    
    func testGlucoseConversion() {
        var unit1 = LoopUnit.milligramsPerDeciliter
        var unit2 = LoopUnit.millimolesPerLiter
        XCTAssertEqual(unit1.conversionFactor(from: unit2), 0.0555)
        XCTAssertEqual(unit2.conversionFactor(from: unit1), 0.0555 * 60)
        
        unit1 = LoopUnit.milligramsPerDeciliterPerSecond
        unit2 = LoopUnit.millimolesPerLiterPerSecond
        XCTAssertEqual(unit1.conversionFactor(from: unit2), 0.0555)
        XCTAssertEqual(unit2.conversionFactor(from: unit1), 0.0555 * 60)
        
        unit1 = LoopUnit.milligramsPerDeciliterPerMinute
        unit2 = LoopUnit.millimolesPerLiterPerMinute
        XCTAssertEqual(unit1.conversionFactor(from: unit2), 0.0555)
        XCTAssertEqual(unit2.conversionFactor(from: unit1), 0.0555 * 60)
        
        unit1 = LoopUnit.milligramsPerDeciliterPerInternationalUnit
        unit2 = LoopUnit.millimolesPerLiterPerInternationalUnit
        XCTAssertEqual(unit1.conversionFactor(from: unit2), 0.0555)
        XCTAssertEqual(unit2.conversionFactor(from: unit1), 0.0555 * 60)
        
        unit1 = LoopUnit.milligramsPerDeciliterPerMinute
        unit2 = LoopUnit.millimolesPerLiterPerSecond
        XCTAssertEqual(unit1.conversionFactor(from: unit2), 0.0555 / 60)
        XCTAssertEqual(unit2.conversionFactor(from: unit1), 18.018)
        
        unit1 = LoopUnit.milligramsPerDeciliterPerSecond
        unit2 = LoopUnit.millimolesPerLiterPerMinute
        XCTAssertEqual(unit1.conversionFactor(from: unit2), 18.018)
        XCTAssertEqual(unit2.conversionFactor(from: unit1), 0.0555 / 60)
    }
}

extension LoopUnitTests {
    private func testUnitString(unit: LoopUnit, hkUnit: HKUnit) {
        XCTAssertEqual(unit.unitString, hkUnit.unitString)
    }
    
    private func testUnitStringConversion(unit: LoopUnit, hkUnit: HKUnit) {
        let hkUnitFromLoopUnit = HKUnit(from: unit.unitString)
        XCTAssertEqual(hkUnitFromLoopUnit, hkUnit)
        
        let loopUnitFromHKUnit = LoopUnit(from: hkUnit.unitString)
        XCTAssertEqual(loopUnitFromHKUnit, unit)
    }
}
