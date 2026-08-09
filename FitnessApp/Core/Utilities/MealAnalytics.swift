//
//  MealAnalytics.swift
//  Arovia
//
//  Pure, framework-independent calculations over meal + activity data — easy to unit test in
//  isolation from HealthKit/SwiftData.
//

import Foundation

struct MealTypeBreakdown: Identifiable {
    let mealType: MealType
    let calories: Double
    let count: Int
    var id: MealType { mealType }
}

/// One day's calories-in vs calories-out, for the trend chart.
struct DailyCalorieBalance: Identifiable {
    let date: Date
    let caloriesIn: Double
    let caloriesOut: Double
    var net: Double { caloriesIn - caloriesOut }
    var id: Date { date }
}

struct MealAnalytics {
    let meals: [MealEntry]
    let calendar: Calendar

    init(meals: [MealEntry], calendar: Calendar = .current) {
        self.meals = meals
        self.calendar = calendar
    }

    func meals(on date: Date) -> [MealEntry] {
        meals.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// Calorie + entry-count totals per meal type for a given day (defaults to today).
    func breakdown(for date: Date = .now) -> [MealTypeBreakdown] {
        let dayMeals = meals(on: date)
        return MealType.allCases.map { type in
            let matches = dayMeals.filter { $0.mealType == type }
            return MealTypeBreakdown(
                mealType: type,
                calories: matches.reduce(0) { $0 + $1.calories },
                count: matches.count
            )
        }
    }

    /// Which meal type contributed the most calories today, if any were logged.
    func biggestContributor(for date: Date = .now) -> MealTypeBreakdown? {
        breakdown(for: date).max { $0.calories < $1.calories }.flatMap { $0.calories > 0 ? $0 : nil }
    }

    /// Merges logged calories-in with HealthKit active-energy-out over the same 7-day window,
    /// so the trend chart lines up day-for-day even if one source has gaps.
    func weeklyBalance(activeEnergyByDay: [DailyEnergyPoint]) -> [DailyCalorieBalance] {
        activeEnergyByDay.map { point in
            let caloriesIn = meals(on: point.date).reduce(0) { $0 + $1.calories }
            return DailyCalorieBalance(date: point.date, caloriesIn: caloriesIn, caloriesOut: point.activeEnergy)
        }
    }

    /// Average calories logged per day across all days that have at least one entry.
    var averageDailyCalories: Double {
        let grouped = Dictionary(grouping: meals) { calendar.startOfDay(for: $0.date) }
        guard !grouped.isEmpty else { return 0 }
        let totalPerDay = grouped.values.map { day in day.reduce(0) { $0 + $1.calories } }
        return totalPerDay.reduce(0, +) / Double(totalPerDay.count)
    }

    /// Consecutive days (including today) with at least one meal logged.
    var loggingStreak: Int {
        let loggedDays = Set(meals.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: .now)
        var streak = 0
        while loggedDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
