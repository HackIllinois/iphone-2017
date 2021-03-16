//
//  Formatters.swift
//  HackIllinois
//
//  Created by HackIllinois Team on 11/20/17.
//  Copyright © 2017 HackIllinois. All rights reserved.
//  This file is part of the Hackillinois iOS App.
//  The Hackillinois iOS App is open source software, released under the University of
//  Illinois/NCSA Open Source License. You should have received a copy of
//  this license in a file with the distribution.
//

import Foundation

extension Formatter {
    static let coreData: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZ"
        return formatter
    }()

    static let simpleTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Chicago")
        return formatter
    }()
}

extension Date {
    static let YEAR_IN_SECONDS   = 31540000.0
    static let MONTH_IN_SECONDS  =  2628000.0
    static let WEEK_IN_SECONDS   =   604800.0
    static let DAY_IN_SECONDS    =    86400.0
    static let HOUR_IN_SECONDS   =     3600.0
    static let MINUTE_IN_SECONDS =       60.0
    static let SECOND_IN_SECONDS =        1.0

    static func humanReadableTimeSince(_ date: Date) -> String {
        let timeSinceDate = Date().timeIntervalSince(date)

        switch timeSinceDate {
        // YEARS
        case (2 * YEAR_IN_SECONDS)... :
            let years = Int(floor(timeSinceDate/YEAR_IN_SECONDS))
            return "\(years)y ago"
        case (1 * YEAR_IN_SECONDS)... :
            return "last year"

        // MONTH
        case (2 * MONTH_IN_SECONDS)... :
            let month = Int(floor(timeSinceDate/MONTH_IN_SECONDS))
            return "\(month)mo ago"
        case (1 * MONTH_IN_SECONDS)... :
            return "last month"

        // WEEK
        case (2 * WEEK_IN_SECONDS)... :
            let week = Int(floor(timeSinceDate/WEEK_IN_SECONDS))
            return "\(week)w ago"
        case (1 * WEEK_IN_SECONDS)... :
            return "last week"

        // DAY
        case (2 * DAY_IN_SECONDS)... :
            let day = Int(floor(timeSinceDate/DAY_IN_SECONDS))
            return "\(day)d ago"
        case (1 * DAY_IN_SECONDS)... :
            return "yesterday"

        // HOUR
        case (2 * HOUR_IN_SECONDS)... :
            let hour = Int(floor(timeSinceDate/HOUR_IN_SECONDS))
            return "\(hour)h ago"
        case (1 * HOUR_IN_SECONDS)... :
            return "an hour ago"

        // MINUTE
        case (2 * MINUTE_IN_SECONDS)... :
            let minute = Int(floor(timeSinceDate/MINUTE_IN_SECONDS))
            return "\(minute)m ago"
        case (1 * MINUTE_IN_SECONDS)... :
            return "a minute ago"

        // SECOND
        default:
            return "just now"
        }
    }
}

extension Date {
    func byRemoving(components componentsToRemove: Set<Calendar.Component>) -> Date {
        let allComponents: Set<Calendar.Component> = [
            .calendar,
            .day,
            .era,
            .hour,
            .minute,
            .month,
            .nanosecond,
            .quarter,
            .second,
            .timeZone,
            .weekOfMonth,
            .weekOfYear,
            .weekday,
            .weekdayOrdinal,
            .year,
            .yearForWeekOfYear
        ]
        let remainingComponents = allComponents.symmetricDifference(componentsToRemove)
        let extractedComponents = Calendar.current.dateComponents(remainingComponents, from: self)
        return Calendar.current.date(from: extractedComponents)!
    }
}
