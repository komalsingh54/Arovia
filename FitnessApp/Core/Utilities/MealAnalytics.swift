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
    func weeklyBalance(activeEnergyByDay: [DailyMetricPoint]) -> [DailyCalorieBalance] {
        activeEnergyByDay.map { point in
            let caloriesIn = meals(on: point.date).reduce(0) { $0 + $1.calories }
            return DailyCalorieBalance(date: point.date, caloriesIn: caloriesIn, caloriesOut: point.value)
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

    // MARK: Period insights (Week / Month / Year)

    enum Period: String, CaseIterable, Identifiable {
        case week, month, year
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var dayCount: Int {
            switch self {
            case .week: 7
            case .month: 30
            case .year: 365
            }
        }
    }

    struct DailyMacros: Identifiable {
        let date: Date
        let carbs: Double
        let fat: Double
        let protein: Double
        var id: Date { date }
    }

    /// One entry per day in the period (oldest first), zero-filled for days without meals so the
    /// chart's x-axis stays continuous.
    func dailyMacros(for period: Period) -> [DailyMacros] {
        guard let start = calendar.date(byAdding: .day, value: -(period.dayCount - 1), to: calendar.startOfDay(for: .now)) else { return [] }
        return (0..<period.dayCount).compactMap { offset -> DailyMacros? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let dayMeals = meals(on: day)
            return DailyMacros(
                date: day,
                carbs: dayMeals.reduce(0) { $0 + $1.carbohydratesGrams },
                fat: dayMeals.reduce(0) { $0 + $1.fatGrams },
                protein: dayMeals.reduce(0) { $0 + $1.proteinGrams }
            )
        }
    }

    /// Average macros across the period, excluding today and any day with nothing logged —
    /// mirrors how most nutrition trackers compute "average" so partial/in-progress days don't skew it.
    func averageMacros(for period: Period) -> (carbs: Double, fat: Double, protein: Double) {
        let today = calendar.startOfDay(for: .now)
        let days = dailyMacros(for: period).filter {
            $0.date != today && ($0.carbs > 0 || $0.fat > 0 || $0.protein > 0)
        }
        guard !days.isEmpty else { return (0, 0, 0) }
        let count = Double(days.count)
        return (
            days.reduce(0) { $0 + $1.carbs } / count,
            days.reduce(0) { $0 + $1.fat } / count,
            days.reduce(0) { $0 + $1.protein } / count
        )
    }

    /// Each macronutrient's share of total calories, using standard 4/9/4 kcal-per-gram factors.
    func nutrientCaloriePercentages(for period: Period) -> [(name: String, grams: Double, percent: Double)] {
        let average = averageMacros(for: period)
        let carbCalories = average.carbs * 4
        let fatCalories = average.fat * 9
        let proteinCalories = average.protein * 4
        let total = carbCalories + fatCalories + proteinCalories
        guard total > 0 else { return [] }
        return [
            ("Carbohydrates", average.carbs, carbCalories / total),
            ("Fat", average.fat, fatCalories / total),
            ("Protein", average.protein, proteinCalories / total)
        ]
    }
}
