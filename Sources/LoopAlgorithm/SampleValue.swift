//
//  SampleValue.swift
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public protocol TimelineValue {
    var startDate: Date { get }
    var endDate: Date { get }
}


public extension TimelineValue {
    var endDate: Date {
        return startDate
    }
}


public protocol SampleValue: TimelineValue {
    var quantity: LoopQuantity { get }
}


public extension Sequence where Element: TimelineValue {
    /**
     Returns the closest element in the sorted sequence prior to the specified date

     - parameter date: The date to use in the search

     - returns: The closest index, if any exist before the specified date
     */
    func closestPrior(to date: Date) -> Iterator.Element? {
        return elementsAdjacent(to: date).before
    }

    /// Returns the elements immediately before and after the specified date
    ///
    /// - Parameter date: The date to use in the search
    /// - Returns: The closest elements, if found
    func elementsAdjacent(to date: Date) -> (before: Iterator.Element?, after: Iterator.Element?) {
        var before: Iterator.Element?
        var after: Iterator.Element?

        for value in self {
            if value.startDate <= date {
                before = value
            } else {
                after = value
                break
            }
        }

        return (before, after)
    }

    /**
     Returns an array of elements filtered by the specified date range.

     This behavior mimics HKQueryOptionNone, where the value must merely overlap the specified range,
     not strictly exist inside of it.

     - parameter startDate: The earliest date of elements to return
     - parameter endDate:   The latest date of elements to return

     - returns: A new array of elements
     */
    func filterDateRange(_ startDate: Date?, _ endDate: Date?) -> [Iterator.Element] {
        return filter { (value) -> Bool in
            if let startDate = startDate, value.endDate < startDate {
                return false
            }

            if let endDate = endDate, value.startDate > endDate {
                return false
            }

            return true
        }
    }

    /**
     Returns an array of elements filtered by the specified DateInterval.

     This behavior mimics HKQueryOptionNone, where the value must merely overlap the specified range,
     not strictly exist inside of it.

     - parameter startDate: The earliest date of elements to return
     - parameter endDate:   The latest date of elements to return

     - returns: A new array of elements
     */
    func filterDateInterval(interval: DateInterval) -> [Iterator.Element] {
        return filterDateRange(interval.start, interval.end)
    }
}
