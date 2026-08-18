//
//  HealthInsights.swift
//  Arovia
//
//  Turns raw HealthKit numbers into short, plain-language observations. Pure functions over
//  domain models — no HealthKit types — so they're easy to unit test and reuse across screens.
//

import Foundation

struct HealthInsights {
    let metrics: DailyMetrics
    let trends: WeeklyHealthTrends
    let calorieTarget: Double

    /// Calories in vs total energy out (active + resting), the figure that actually matters for
    /// weight trend — resting energy alone is usually 1500-2000 kcal/day and dwarfs active burn.
    func calorieBalanceInsight(caloriesConsumed: Double) -> String {
        let net = caloriesConsumed - metrics.totalEnergyOut
        if metrics.totalEnergyOut == 0 {
            return "Connect Health to compare what you eat against your total energy burn (active + resting)."
        }
        if net > 0 {
            return "You're about \(Int(net)) kcal above your total burn today (active + resting energy)."
        }
        return "You're about \(Int(abs(net))) kcal under your total burn today — a deficit, if that's your goal."
    }

    var stepsTrendInsight: String? {
        trendInsight(for: trends.steps, metricLabel: "steps", unit: "")
    }

    var activeEnergyTrendInsight: String? {
        trendInsight(for: trends.activeEnergy, metricLabel: "active energy", unit: " kcal")
    }

    var exerciseTrendInsight: String? {
        trendInsight(for: trends.exerciseMinutes, metricLabel: "exercise", unit: " min")
    }

    /// Shared "today vs your 7-day average" phrasing so every metric gets the same comparison
    /// treatment instead of each screen inventing its own one-off insight text.
    private func trendInsight(for points: [DailyMetricPoint], metricLabel: String, unit: String) -> String? {
        guard points.count >= 2 else { return nil }
        let average = points.map(\.value).reduce(0, +) / Double(points.count)
        guard average > 0 else { return nil }
        let today = points.last?.value ?? 0
        let delta = ((today - average) / average) * 100
        if abs(delta) < 5 { return "Today's \(metricLabel) is in line with your 7-day average of \(Int(average))\(unit)." }
        let direction = delta > 0 ? "above" : "below"
        return "Today's \(metricLabel) is \(Int(abs(delta)))% \(direction) your 7-day average of \(Int(average))\(unit)."
    }

    var restingHeartRateTrendInsight: String? {
        let values = trends.restingHeartRate.map(\.value).filter { $0 > 0 }
        guard values.count >= 3, let latest = values.last else { return nil }
        let earlier = values.dropLast()
        let earlierAverage = earlier.reduce(0, +) / Double(earlier.count)
        guard earlierAverage > 0 else { return nil }
        let delta = latest - earlierAverage
        if abs(delta) < 2 { return "Resting heart rate has been steady around \(Int(latest)) bpm this week." }
        let direction = delta > 0 ? "up" : "down"
        return "Resting heart rate is \(direction) \(String(format: "%.1f", abs(delta))) bpm versus your recent average — \(direction == "down" ? "a good recovery sign" : "worth keeping an eye on if it continues")."
    }

    var sleepInsight: String? {
        guard let lastNight = metrics.sleepHours else { return nil }
        let values = trends.sleepHours.map(\.value).filter { $0 > 0 }
        let average = values.isEmpty ? lastNight : values.reduce(0, +) / Double(values.count)
        if lastNight < 6 {
            return "You slept \(formattedHours(lastNight)) last night — below the 7-9 hours generally recommended for recovery."
        }
        if lastNight >= average + 0.5 {
            return "You slept \(formattedHours(lastNight)) last night, more than your recent average of \(formattedHours(average))."
        }
        return "You slept \(formattedHours(lastNight)) last night, close to your recent average of \(formattedHours(average))."
    }

    var weightTrendInsight: String? {
        let points = trends.weightKg.filter { $0.value > 0 }
        guard let first = points.first, let last = points.last, points.count >= 2 else { return nil }
        let delta = last.value - first.value
        if abs(delta) < 0.2 { return "Weight has been stable over the last week." }
        let direction = delta > 0 ? "up" : "down"
        return "Weight is \(direction) \(String(format: "%.1f", abs(delta))) kg over the last 7 days."
    }

    private func formattedHours(_ hours: Double) -> String {
        let wholeHours = Int(hours)
        let minutes = Int((hours - Double(wholeHours)) * 60)
        return "\(wholeHours)h \(minutes)m"
    }
}
