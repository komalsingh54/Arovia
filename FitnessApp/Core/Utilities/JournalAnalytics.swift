//
//  JournalAnalytics.swift
//  Arovia
//

import Foundation

struct JournalAnalytics {
    let entries: [JournalEntry]
    let calendar: Calendar

    init(entries: [JournalEntry], calendar: Calendar = .current) {
        self.entries = entries
        self.calendar = calendar
    }

    var entriesThisWeek: [JournalEntry] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return entries.filter { interval.contains($0.date) }
    }

    var categoryCounts: [(category: JournalCategory, count: Int)] {
        JournalCategory.allCases.map { category in
            (category, entriesThisWeek.filter { $0.category == category }.count)
        }
    }

    var currentStreak: Int {
        let entryDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: .now)
        var streak = 0

        while entryDays.contains(day) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previousDay
        }
        return streak
    }
}
