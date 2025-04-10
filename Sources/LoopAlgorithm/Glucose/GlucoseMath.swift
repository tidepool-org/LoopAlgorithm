//
//  GlucoseMath.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation

public struct GlucoseMath {
    public static let momentumDataInterval: TimeInterval = .minutes(15)
    public static let momentumDuration: TimeInterval = .minutes(15)
    public static let defaultDelta: TimeInterval = .minutes(5)
}

fileprivate extension Collection where Element == (x: Double, y: Double) {
    /**
     Calculates slope and intercept using linear regression

     This implementation is not suited for large datasets.

     - parameter points: An array of tuples containing x and y values

     - returns: A tuple of slope and intercept values
     */
    func linearRegression() -> (slope: Double, intercept: Double) {
        var sumX = 0.0
        var sumY = 0.0
        var sumXY = 0.0
        var sumX² = 0.0
        var sumY² = 0.0
        let count = Double(self.count)

        for point in self {
            sumX += point.x
            sumY += point.y
            sumXY += (point.x * point.y)
            sumX² += (point.x * point.x)
            sumY² += (point.y * point.y)
        }

        let slope = ((count * sumXY) - (sumX * sumY)) / ((count * sumX²) - (sumX * sumX))
        let intercept = (sumY * sumX² - (sumX * sumXY)) / (count * sumX² - (sumX * sumX))

        return (slope: slope, intercept: intercept)
    }
}


extension BidirectionalCollection where Element: GlucoseSampleValue, Index == Int {

    /// Whether the collection contains any calibration entries
    /// Runtime: O(n)
    public func containsCalibrations() -> Bool {
        return filter({ $0.isDisplayOnly }).count > 0
    }

    /// Whether the collection can be considered continuous
    ///
    /// - Parameters:
    ///   - interval: The interval between readings, on average, used to determine if we have a contiguous set of values
    /// - Returns: True if the samples are continuous
    public func isContinuous(within interval: TimeInterval = TimeInterval(5 * 60)) -> Bool {
        if  let first = first,
            let last = last,
            // Ensure that the entries are contiguous
            abs(first.startDate.timeIntervalSince(last.startDate)) < interval * TimeInterval(count)
        {
            return true
        }

        return false
    }

    /// Calculates the short-term predicted momentum effect using linear regression
    ///
    /// - Parameters:
    ///   - duration: The duration of the effects
    ///   - delta: The time differential for the returned values
    ///   - velocityMaximum: The limit on how fast the momentum effect can be. Defaults to 4 mg/dL/min based on physiological rates, if nil passed.
    /// - Returns: An array of glucose effects
    public func linearMomentumEffect(
        duration: TimeInterval = GlucoseMath.momentumDuration,
        delta: TimeInterval = GlucoseMath.defaultDelta,
        velocityMaximum: LoopQuantity? = nil
    ) -> [GlucoseEffect] {

        let velocityMax = velocityMaximum ?? LoopQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 4.0)

        guard
            self.count > 2,  // Linear regression isn't much use without 3 or more entries.
            isContinuous() && !containsCalibrations() && hasSingleProvenance,
            let firstSample = self.first,
            let lastSample = self.last,
            let (startDate, endDate) = LoopMath.simulationDateRangeForSamples([lastSample], duration: duration, delta: delta)
        else {
            return []
        }

        /// Choose a unit to use during raw value calculation
        let unit = LoopUnit.milligramsPerDeciliter

        let (slope: slope, intercept: _) = self.map { (
            x: $0.startDate.timeIntervalSince(firstSample.startDate),
            y: $0.quantity.doubleValue(for: unit)
        ) }.linearRegression()

        guard slope.isFinite else {
            return []
        }

        let limitedSlope = Swift.min(slope, velocityMax.doubleValue(for: .milligramsPerDeciliterPerSecond))

        var date = startDate
        var values = [GlucoseEffect]()

        repeat {
            let value = Swift.max(0, date.timeIntervalSince(lastSample.startDate)) * limitedSlope
            let momentumEffect = GlucoseEffect(startDate: date, quantity: LoopQuantity(unit: unit, doubleValue: value))

            values.append(momentumEffect)
            date = date.addingTimeInterval(delta)
        } while date <= endDate

        return values
    }
}


extension Collection where Element: GlucoseSampleValue, Index == Int {
    /// Whether the collection is all from the same source.
    /// Runtime: O(n)
    var hasSingleProvenance: Bool {
        let firstProvenance = self.first?.provenanceIdentifier

        for sample in self {
            if sample.provenanceIdentifier != firstProvenance {
                return false
            }
        }

        return true
    }

    /// Calculates a timeline of effect velocity (glucose/time) observed in glucose readings that counteract the specified effects.
    ///
    /// - Parameter effects: Glucose effects to be countered, in chronological order
    /// - Returns: An array of velocities describing the change in glucose samples compared to the specified effects
    public func counteractionEffects(to effects: [GlucoseEffect]) -> [GlucoseEffectVelocity] {
        let mgdL = LoopUnit.milligramsPerDeciliter
        let velocityUnit = GlucoseEffectVelocity.perSecondUnit
        var velocities = [GlucoseEffectVelocity]()

        var effectIndex = 0

        guard self.count > 0, effects.count > 0 else {
            return []
        }

        let startGlucoseIdx = self.firstIndex { $0.startDate >= effects.first!.startDate }

        guard var startGlucoseIdx else {
            return []
        }

        var endGlucoseIdx = startGlucoseIdx + 1

        while endGlucoseIdx != self.endIndex {
            // Find a valid change in glucose, requiring identical provenance and no calibration
            let startGlucose = self[startGlucoseIdx]
            let endGlucose = self[endGlucoseIdx]

            let glucoseChange = endGlucose.quantity.doubleValue(for: mgdL) - startGlucose.quantity.doubleValue(for: mgdL)
            let timeInterval = endGlucose.startDate.timeIntervalSince(startGlucose.startDate)

            guard timeInterval > .minutes(4) else {
                endGlucoseIdx += 1
                continue
            }

            defer {
                startGlucoseIdx = endGlucoseIdx
                endGlucoseIdx += 1
            }

            guard startGlucose.provenanceIdentifier == endGlucose.provenanceIdentifier,
                !startGlucose.isDisplayOnly, !endGlucose.isDisplayOnly
            else {
                continue
            }

            // Compare that to a change in insulin effects
            guard effects.count > effectIndex else {
                break
            }

            var startEffect: GlucoseEffect?
            var endEffect: GlucoseEffect?

            for effect in effects[effectIndex..<effects.count] {
                if startEffect == nil && effect.startDate >= startGlucose.startDate {
                    startEffect = effect
                } else if endEffect == nil && effect.startDate >= endGlucose.startDate {
                    endEffect = effect
                    break
                }

                effectIndex += 1
            }

            guard let startEffectValue = startEffect?.quantity.doubleValue(for: mgdL),
                let endEffectValue = endEffect?.quantity.doubleValue(for: mgdL)
            else {
                break
            }

            let effectChange = endEffectValue - startEffectValue
            let discrepancy = glucoseChange - effectChange

            let averageVelocity = LoopQuantity(unit: velocityUnit, doubleValue: discrepancy / timeInterval)
            let effect = GlucoseEffectVelocity(startDate: startGlucose.startDate, endDate: endGlucose.startDate, quantity: averageVelocity)

            velocities.append(effect)
        }

        return velocities
    }
}
