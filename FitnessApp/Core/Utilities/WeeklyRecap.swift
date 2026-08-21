//
//  WeeklyRecap.swift
//  Arovia
//
//  Summarizes the 7-day window HealthStore already fetches (`weeklyTrends`) into a shareable
//  recap: totals, the best day, and a plain-language summary. Deliberately scoped to the current
//  week only — a true "vs last week" comparison would need a second HealthKit fetch covering the
//  prior 7 days, which HealthKitService doesn't currently expose. Noted as a natural follow-up
//  rather than silently faked with made-up numbers.
//

import Foundation

struct WeeklyRecap {
    let trends: WeeklyHealthTrends
    let journalEntries: [JournalEntry]
    let waterEntries: [WaterEntry]

    private var calendar: Calendar { .current }

    var totalSteps: Double { trends.steps.reduce(0) { $0 + $1.value } }
    var totalActiveEnergy: Double { trends.activeEnergy.reduce(0) { $0 + $1.value } }
    var totalExerciseMinutes: Double { trends.exerciseMinutes.reduce(0) { $0 + $1.value } }
    var averageSteps: Double { trends.steps.isEmpty ? 0 : totalSteps / Double(trends.steps.count) }

    /// Days where exercise minutes met the standard 30-minute goal.
    var activeDayCount: Int { trends.exerciseMinutes.filter { $0.value >= 30 }.count }

    var bestStepsDay: DailyMetricPoint? {
        trends.steps.max { $0.value < $1.value }
    }

    private var weekInterval: DateInterval? {
        guard let first = trends.steps.first?.date, let last = trends.steps.last?.date else { return nil }
        return DateInterval(start: calendar.startOfDay(for: min(first, last)), end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(first, last))) ?? .now)
    }

    var journalEntriesThisWeek: Int {
        guard let interval = weekInterval else { return 0 }
        return journalEntries.filter { interval.contains($0.date) }.count
    }

    var currentStreak: Int {
        JournalAnalytics(entries: journalEntries).currentStreak
    }

    var averageWaterMl: Double {
        guard let interval = weekInterval else { return 0 }
        let byDay = Dictionary(grouping: waterEntries.filter { interval.contains($0.date) }) { calendar.startOfDay(for: $0.date) }
        guard !byDay.isEmpty else { return 0 }
        let total = byDay.values.reduce(0) { $0 + $1.reduce(0) { $0 + $1.amountMl } }
        return total / Double(byDay.count)
    }

    /// A short, plain-language summary suitable for a share sheet — one place generating the
    /// text so the on-screen card and the ShareLink text always say the same thing.
    var summaryText: String {
        var lines = ["My week on Arovia:"]
        lines.append("• \(Int(totalSteps).formatted()) steps (avg \(Int(averageSteps).formatted())/day)")
        lines.append("• \(Int(totalActiveEnergy).formatted()) kcal active energy")
        if let best = bestStepsDay, best.value > 0 {
            lines.append("• Best day: \(best.date.formatted(.dateTime.weekday(.wide))) with \(Int(best.value).formatted()) steps")
        }
        lines.append("• \(activeDayCount) of 7 days hit the exercise goal")
        if journalEntriesThisWeek > 0 {
            lines.append("• \(journalEntriesThisWeek) journal \(journalEntriesThisWeek == 1 ? "entry" : "entries"), \(currentStreak)-day streak")
        }
        return lines.joined(separator: "\n")
    }
}
