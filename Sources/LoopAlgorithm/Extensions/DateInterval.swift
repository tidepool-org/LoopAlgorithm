//
//  DateInterval.swift
//  LoopAlgorithm
//
//  Created by Pete Schwamb on 10/16/24.
//
import Foundation

extension DateInterval {
    func extendedForSimulation(_ delta: TimeInterval? = nil) -> DateInterval {
        let delta = delta ?? GlucoseMath.defaultDelta
        return DateInterval(start: start.dateFlooredToTimeInterval(delta), end: end.dateCeiledToTimeInterval(delta))
    }

    func extendedToInclude(_ date: Date) -> DateInterval {
        return DateInterval(start: min(start, date), end: max(end, date))
    }

    func extendedToInclude(_ interval: DateInterval) -> DateInterval {
        return DateInterval(start: min(start, interval.start), end: max(end, interval.end))
    }
}
