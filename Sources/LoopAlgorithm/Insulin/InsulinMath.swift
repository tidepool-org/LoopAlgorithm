//
//  InsulinMath.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/30/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit

public struct InsulinMath {
    public static var defaultInsulinActivityDuration: TimeInterval = TimeInterval(hours: 6) + TimeInterval(minutes: 10)
    public static var longestInsulinActivityDuration: TimeInterval = TimeInterval(hours: 6) + TimeInterval(minutes: 10)
}

extension BasalRelativeDose {
    private func continuousDeliveryInsulinOnBoard(at date: Date, delta: TimeInterval) -> Double {
        let doseDuration = endDate.timeIntervalSince(startDate)  // t1
        let time = date.timeIntervalSince(startDate)
        var iob: Double = 0
        var doseDate = TimeInterval(0)  // i

        repeat {
            let segment: Double

            if doseDuration > 0 {
                segment = max(0, min(doseDate + delta, doseDuration) - doseDate) / doseDuration
            } else {
                segment = 1
            }

            iob += segment * insulinModel.percentEffectRemaining(at: time - doseDate)
            doseDate += delta
        } while doseDate <= min(floor((time + insulinModel.delay) / delta) * delta, doseDuration)

        return iob
    }

    func insulinOnBoard(at date: Date, delta: TimeInterval) -> Double {
        let time = date.timeIntervalSince(startDate)
        guard time >= 0 else {
            return 0
        }

        // Consider doses within the delta time window as momentary
        if endDate.timeIntervalSince(startDate) <= 1.05 * delta {
            return netBasalUnits * insulinModel.percentEffectRemaining(at: time)
        } else {
            return netBasalUnits * continuousDeliveryInsulinOnBoard(at: date, delta: delta)
        }
    }

    private func continuousDeliveryPercentEffect(at date: Date, delta: TimeInterval) -> Double {
        let doseDuration = endDate.timeIntervalSince(startDate)  // t1
        let time = date.timeIntervalSince(startDate)
        var value: Double = 0
        var doseDate = TimeInterval(0)  // i

        repeat {
            let segment: Double

            if doseDuration > 0 {
                segment = max(0, min(doseDate + delta, doseDuration) - doseDate) / doseDuration
            } else {
                segment = 1
            }

            value += segment * (1.0 - insulinModel.percentEffectRemaining(at: time - doseDate))
            doseDate += delta
        } while doseDate <= min(floor((time + insulinModel.delay) / delta) * delta, doseDuration)

        return value
    }

    func glucoseEffect(at date: Date, insulinSensitivity: Double, delta: TimeInterval) -> Double {
        let time = date.timeIntervalSince(startDate)

        guard time >= 0 else {
            return 0
        }

        // Consider doses within the delta time window as momentary
        if endDate.timeIntervalSince(startDate) <= 1.05 * delta {
            return netBasalUnits * -insulinSensitivity * (1.0 - insulinModel.percentEffectRemaining(at: time))
        } else {
            return netBasalUnits * -insulinSensitivity * continuousDeliveryPercentEffect(at: date, delta: delta)
        }
    }

    func glucoseEffect(during interval: DateInterval, insulinSensitivity: Double, delta: TimeInterval) -> Double {
        let start = interval.start.timeIntervalSince(startDate)
        let end = interval.end.timeIntervalSince(startDate)

        guard end-start >= 0 else {
            return 0
        }

        // Consider doses within the delta time window as momentary
        let effect: Double
        if endDate.timeIntervalSince(startDate) <= 1.05 * delta {
            effect = insulinModel.percentEffectRemaining(at: start) - insulinModel.percentEffectRemaining(at: end)
        } else {
            let startPercentRemaining = 1 - continuousDeliveryPercentEffect(at: interval.start, delta: delta)
            let endPercentRemaining = 1 - continuousDeliveryPercentEffect(at: interval.end, delta: delta)
            effect = startPercentRemaining - endPercentRemaining
        }
        return netBasalUnits * -insulinSensitivity * effect
    }
}


extension InsulinDose {

    /// Annotates a dose with the context of a history of scheduled basal rates
    ///
    /// If the dose crosses a schedule boundary, it will be split into multiple doses so each dose has a
    /// single scheduled basal rate.
    ///
    /// - Parameter basalHistory: The history of basal schedule values to apply. Only schedule values overlapping the dose should be included.
    /// - Returns: An array of annotated doses
    func annotated(with basalHistory: [AbsoluteScheduleValue<Double>]) -> [BasalRelativeDose] {

        guard deliveryType == .basal else {
            preconditionFailure("basalDeliveryTotal called on dose that is not a temp basal!")
        }

        var doses: [BasalRelativeDose] = []

        for (index, basalItem) in basalHistory.enumerated() {
            let startDate: Date
            let endDate: Date

            if index == 0 {
                startDate = self.startDate
            } else {
                startDate = basalItem.startDate
            }

            if index == basalHistory.count - 1 {
                endDate = self.endDate
            } else {
                endDate = basalHistory[index + 1].startDate
            }

            let segmentStartDate = max(startDate, self.startDate)
            let segmentEndDate = max(startDate, min(endDate, self.endDate))
            let segmentDuration = segmentEndDate.timeIntervalSince(segmentStartDate)

            let segmentVolume: Double
            if duration > 0 {
                segmentVolume = volume * (segmentDuration / duration)
            } else {
                segmentVolume = 0
            }

            let annotatedDose = BasalRelativeDose(
                type: .basal(scheduledRate: basalItem.value),
                startDate: segmentStartDate,
                endDate: segmentEndDate,
                volume: segmentVolume,
                insulinModel: insulinModel
            )

            doses.append(annotatedDose)
        }

        return doses
    }
}

public extension Array where Element == AbsoluteScheduleValue<Double> {
    func trimmed(from start: Date? = nil, to end: Date? = nil) -> [AbsoluteScheduleValue<Double>] {
        return self.compactMap { (entry) -> AbsoluteScheduleValue<Double>? in
            if let start, entry.endDate < start {
                return nil
            }
            if let end, entry.startDate > end {
                return nil
            }
            return AbsoluteScheduleValue(
                startDate: Swift.max(start ?? entry.startDate, entry.startDate),
                endDate: Swift.min(end ??  entry.endDate, entry.endDate),
                value: entry.value
            )
        }
    }
}


extension Collection where Element: InsulinDose {

    /// Returns an array of BasalRelativeDoses, based on annotating a sequence of dose entries with the given basal history.
    ///
    /// Doses which cross time boundaries in the basal rate schedule are split into multiple entries.
    ///
    /// - Parameter basalSchedule: A history of basal rates covering the timespan of these doses.
    /// - Parameter fillBasalGaps: If true, the returned array will interpolate doses from basal schedule for those parts of the 
    ///                             timeline that this array does not cover.
    /// - Returns: An array of annotated dose entries
    public func annotated(with basalHistory: [AbsoluteScheduleValue<Double>], fillBasalGaps: Bool = false) -> [BasalRelativeDose] {
        var annotatedDoses: [BasalRelativeDose] = []

        let basalAdjustments = self.filter { $0.deliveryType == .basal }

        let date = [basalHistory.first?.startDate, basalAdjustments.first?.startDate].compactMap { $0 }.min()

        if !fillBasalGaps {
            guard self.count > 0 else {
                return []
            }
        }

        guard var date else {
            return []
        }

        func fillGapWithBasal(start: Date, end: Date) -> [BasalRelativeDose] {
            let basals = basalHistory.trimmed(from: start, to: end)
            return basals.map { entry in
                BasalRelativeDose(
                    type: .basal(scheduledRate: entry.value),
                    startDate: entry.startDate,
                    endDate: entry.endDate,
                    volume: entry.value * entry.duration.hours
                )
            }
        }

        for dose in self {
            if dose.deliveryType != .basal {
                annotatedDoses.append(BasalRelativeDose.fromBolus(dose: dose))
                continue
            }

            if date < dose.startDate && fillBasalGaps {
                // Fill date <-> dose.startDate gap with basal
                annotatedDoses.append(contentsOf: fillGapWithBasal(start: date, end: dose.startDate))
            }

            let basalItems = basalHistory.filterDateRange(dose.startDate, dose.endDate)
            annotatedDoses += dose.annotated(with: basalItems)
            date = dose.endDate
        }

        let endDate = [basalHistory.last?.endDate, basalAdjustments.last?.endDate].compactMap { $0 }.max() ?? date

        if date < endDate && fillBasalGaps {
            annotatedDoses.append(contentsOf: fillGapWithBasal(start: date, end: endDate))
        }

        return annotatedDoses
    }

    /// Annotates a sequence of dose entries with the configured basal history
    ///
    /// Doses which cross time boundaries in the basal rate schedule are split into multiple entries.
    ///
    /// - Parameter basalSchedule: A history of basal rates covering the timespan of these doses.
    /// - Returns: An array of annotated dose entries
    public func annotated(with basalHistory: [AbsoluteScheduleValue<Double>]) -> [BasalRelativeDose] {
        var annotatedDoses: [BasalRelativeDose] = []

        for dose in self {
            if dose.deliveryType == .basal {
                let basalItems = basalHistory.filterDateRange(dose.startDate, dose.endDate)
                annotatedDoses += dose.annotated(with: basalItems)
            } else {
                annotatedDoses.append(BasalRelativeDose.fromBolus(dose: dose))
            }
        }

        return annotatedDoses
    }

}

extension Collection where Element == BasalRelativeDose {

    /**
     Calculates the timeline of insulin remaining for a collection of doses

     - parameter longestEffectDuration: The longest duration that a dose could be active.
     - parameter start:                 The date to start the timeline
     - parameter end:                   The date to end the timeline
     - parameter delta:                 The differential between timeline entries, Defaults to 5 minutes.

     - returns: A sequence of insulin amount remaining
     */
    public func insulinOnBoardTimeline(
        longestEffectDuration: TimeInterval = InsulinMath.defaultInsulinActivityDuration,
        from start: Date? = nil,
        to end: Date? = nil,
        delta: TimeInterval = GlucoseMath.defaultDelta
    ) -> [InsulinValue] {
        guard let (start, end) = LoopMath.simulationDateRangeForSamples(self, from: start, to: end, duration: longestEffectDuration, delta: delta) else {
            return []
        }

        var date = start
        var values = [InsulinValue]()

        repeat {
            let value = reduce(0) { (value, dose) -> Double in
                return value + dose.insulinOnBoard(at: date, delta: delta)
            }

            values.append(InsulinValue(startDate: date, value: value))
            date = date.addingTimeInterval(delta)
        } while date <= end

        return values
    }

    /**
     Calculates insulin remaining at a given point in time for a collection of doses

     - parameter date:                  The date at which to calculate remaining insulin.  If nil, current date is used.

     - returns: Insulin amount remaining at specified time
     */
    public func insulinOnBoard(
        at date: Date
    ) -> Double {
        return reduce(0) { (value, dose) -> Double in
            return value + dose.insulinOnBoard(at: date, delta: GlucoseMath.defaultDelta)
        }
    }


    /// Calculates the timeline of glucose effects for a collection of doses. The ISF used for a given dose is based on the ISF in effect at the dose start time.
    ///
    /// - Parameters:
    ///   - insulinSensitivityHistory: The timeline of glucose effect per unit of insulin
    ///   - start: The earliest date of effects to return
    ///   - end: The latest date of effects to return. If nil is passed, it will be calculated from the last sample end date plus the longestEffectDuration.
    ///   - delta: The interval between returned effects
    /// - Returns: An array of glucose effects for the duration of the doses
    public func glucoseEffects(
        insulinSensitivityHistory: [AbsoluteScheduleValue<HKQuantity>],
        from start: Date? = nil,
        to end: Date? = nil,
        delta: TimeInterval = TimeInterval(/* minutes: */60 * 5)
    ) -> [GlucoseEffect] {

        let activeEntries = self.filter({ entry in
            entry.netBasalUnits != 0
        })

        guard let (start, end) = LoopMath.simulationDateRangeForSamples(activeEntries, from: start, to: end, duration: InsulinMath.longestInsulinActivityDuration, delta: delta) else {
            return []
        }

        var date = start
        var values = [GlucoseEffect]()
        let unit = HKUnit.milligramsPerDeciliter

        repeat {
            let value = reduce(0) { (value, dose) -> Double in

                guard let isfScheduleValue = insulinSensitivityHistory.closestPrior(to: dose.startDate), isfScheduleValue.endDate >= dose.startDate else {
                    preconditionFailure("ISF History must cover dose startDates")
                }
                let isf = isfScheduleValue.value.doubleValue(for: unit)
                let doseEffect = dose.glucoseEffect(at: date, insulinSensitivity: isf, delta: delta)
                return value + doseEffect
            }

            values.append(GlucoseEffect(startDate: date, quantity: HKQuantity(unit: unit, doubleValue: value)))
            date = date.addingTimeInterval(delta)
        } while date <= end

        return values
    }


    /// Calculates the timeline of glucose effects for a collection of doses.  Effects for a specific dose will vary over the course
    /// of that dose's absoption interval based on the timeline of insulin sensitivity.
    ///
    /// - Parameters:
    ///   - longestEffectDuration: The longest duration that a dose could be active.
    ///   - insulinSensitivityHistory: A timeline of glucose effect per unit of insulin
    ///   - start: The earliest date of effects to return
    ///   - end: The latest date of effects to return
    ///   - delta: The interval between returned effects
    /// - Returns: An array of glucose effects for the duration of the doses
    public func glucoseEffectsMidAbsorptionISF(
        longestEffectDuration: TimeInterval = InsulinMath.defaultInsulinActivityDuration,
        insulinSensitivityHistory: [AbsoluteScheduleValue<HKQuantity>],
        from start: Date? = nil,
        to end: Date? = nil,
        delta: TimeInterval = TimeInterval(/* minutes: */60 * 5)
    ) -> [GlucoseEffect] {
        guard let (start, end) = LoopMath.simulationDateRangeForSamples(self.filter({ entry in
            entry.netBasalUnits != 0
        }), from: start, to: end, duration: longestEffectDuration, delta: delta) else {
            return []
        }

        var lastDate = start
        var date = start
        var values = [GlucoseEffect]()
        let unit = HKUnit.milligramsPerDeciliter

        var value: Double = 0
        repeat {
            // Sum effects over doses
            value = reduce(value) { (value, dose) -> Double in
                guard date != lastDate else {
                    return 0
                }

                // Sum effects over pertinent ISF timeline segments
                let isfSegments = insulinSensitivityHistory.filterDateRange(lastDate, date)
                if isfSegments.count == 0 {
                    preconditionFailure("ISF Timeline must cover dose absorption duration")
                }
                return value + isfSegments.reduce(0, { partialResult, segment in
                    let start = Swift.max(lastDate, segment.startDate)
                    let end = Swift.min(date, segment.endDate)
                    let effect = dose.glucoseEffect(during: DateInterval(start: start, end: end), insulinSensitivity: segment.value.doubleValue(for: unit), delta: delta)
                    return partialResult + effect
                })
            }

            values.append(GlucoseEffect(startDate: date, quantity: HKQuantity(unit: unit, doubleValue: value)))
            lastDate = date
            date = date.addingTimeInterval(delta)
        } while date <= end

        return values
    }

    /// Calculates the timeline of glucose effects for a collection of doses at specified points in time. Effects for a specific dose will vary over the course
    /// of that dose's absoption interval based on the timeline of insulin sensitivity.
    ///
    /// - Parameters:
    ///   - longestEffectDuration: The longest duration that a dose could be active.
    ///   - insulinSensitivityTimeline: A timeline of glucose effect per unit of insulin
    ///   - effectDates: The dates at which to calculate glucose effects
    ///   - delta: The interval below which to consider doses as momentary
    /// - Returns: An array of glucose effects for the duration of the doses
    public func glucoseEffects(
        longestEffectDuration: TimeInterval = InsulinMath.defaultInsulinActivityDuration,
        insulinSensitivityTimeline: [AbsoluteScheduleValue<HKQuantity>],
        effectDates: [Date],
        delta: TimeInterval = TimeInterval(/* minutes: */60 * 5)
    ) -> [GlucoseEffect] {

        var lastDate = effectDates.first!
        var values = [GlucoseEffect]()
        let unit = HKUnit.milligramsPerDeciliter

        for date in effectDates {
            // Sum effects over doses
            let value = reduce(0) { (value, dose) -> Double in
                guard date != lastDate else {
                    return 0
                }

                // Sum effects over pertinent ISF timeline segments
                let isfSegments = insulinSensitivityTimeline.filterDateRange(lastDate, date)
                return value + isfSegments.reduce(0, { partialResult, segment in
                    let start = Swift.max(lastDate, segment.startDate)
                    let end = Swift.min(date, segment.endDate)
                    let effect = dose.glucoseEffect(during: DateInterval(start: start, end: end), insulinSensitivity: segment.value.doubleValue(for: unit), delta: delta)
                    return partialResult + effect
                })
            }

            values.append(GlucoseEffect(startDate: date, quantity: HKQuantity(unit: unit, doubleValue: value)))
            lastDate = date
        }

        return values
    }
}
