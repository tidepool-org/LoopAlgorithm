//
//  LoopMathTests.swift
//  LoopAlgorithm
//

import XCTest
@testable import LoopAlgorithm

class LoopMathTests: XCTestCase {

    /// `decayEffect` previously accumulated the decay step-by-step starting from
    /// the simulation-grid boundary (the sample's `startDate` floored to `delta`),
    /// so two samples sitting on opposite sides of a 5-minute boundary produced
    /// different effect values at the same future absolute timestamp. With the
    /// continuous formulation, a sub-`delta` shift in the input timestamp only
    /// shifts the output series by one slot and leaves shared-timestamp values
    /// effectively unchanged.
    func testDecayEffectIsContinuousAcrossSimulationBoundary() {
        let calendar = Calendar(identifier: .gregorian)
        let alignedDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 10, minute: 15, second: 0))!
        let shiftedDate = alignedDate.addingTimeInterval(-1e-6)

        let rate = LoopQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: -0.5)

        let alignedSample = FixtureGlucoseSample(startDate: alignedDate, quantity: .glucose(100))
        let shiftedSample = FixtureGlucoseSample(startDate: shiftedDate, quantity: .glucose(100))

        let alignedEffects = alignedSample.decayEffect(atRate: rate, for: .minutes(30))
        let shiftedEffects = shiftedSample.decayEffect(atRate: rate, for: .minutes(30))

        // The shifted sample's floored start lands one `delta` earlier, so its
        // series has one extra leading entry equal to the sample's value.
        XCTAssertEqual(shiftedEffects.count, alignedEffects.count + 1)
        XCTAssertEqual(shiftedEffects[0].quantity.doubleValue(for: .milligramsPerDeciliter), 100, accuracy: 1e-9)

        // Shared timestamps should produce shared values.
        let mgdl = LoopUnit.milligramsPerDeciliter
        for (index, aligned) in alignedEffects.enumerated() {
            let shifted = shiftedEffects[index + 1]
            XCTAssertEqual(aligned.startDate, shifted.startDate)
            XCTAssertEqual(
                aligned.quantity.doubleValue(for: mgdl),
                shifted.quantity.doubleValue(for: mgdl),
                accuracy: 1e-6
            )
        }
    }
}
