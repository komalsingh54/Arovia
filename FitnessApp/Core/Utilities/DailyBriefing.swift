//
//  DailyBriefing.swift
//  Arovia
//
//  Synthesizes activity, nutrition, goals, and journal data into a short plain-language
//  narrative — "what you've done, what's missing" — instead of making the person read four
//  separate cards to piece that together themselves. Pure function over domain models (no
//  HealthKit/SwiftData types) so it's easy to unit test and reuse.
//
//  This deliberately does NOT call an external AI/LLM API. A few reasons:
//  1. It needs to work instantly and offline — a network round-trip for a sentence that
//     changes maybe once an hour isn't worth the latency or the failure modes.
//  2. It needs an API key living somewhere. For a personal single-user app there's no
//     backend to hold that key safely — embedding it in the app bundle means anyone can
//     extract it, and it would be billed to your account for something a few lines of
//     Swift already do deterministically.
//  3. The rule-based version is fully testable and never "hallucinates" a wrong number.
//  If this app grows a backend later, swapping this for a real model call is a contained
//  change — everything downstream just consumes `DailyBriefing.paragraph`.
//

import Foundation

struct DailyBriefing {
    let metrics: DailyMetrics
    let trends: WeeklyHealthTrends
    let todaysMeals: [MealEntry]
    let calorieTarget: Double
    let goals: [FitnessGoal]
    let journalEntries: [JournalEntry]
    let now: Date

    init(
        metrics: DailyMetrics,
        trends: WeeklyHealthTrends,
        todaysMeals: [MealEntry],
        calorieTarget: Double,
        goals: [FitnessGoal],
        journalEntries: [JournalEntry],
        now: Date = .now
    ) {
        self.metrics = metrics
        self.trends = trends
        self.todaysMeals = todaysMeals
        self.calorieTarget = calorieTarget
        self.goals = goals
        self.journalEntries = journalEntries
        self.now = now
    }

    /// The full narrative, 3-4 short sentences: how today's shaping up, the activity headline,
    /// what's logged (and missing) at meals, then whichever of goals/journal has something
    /// worth saying. Sections that have nothing meaningful to add are skipped rather than
    /// padded out, so this doesn't turn into a wall of filler text on a quiet day.
    var paragraph: String {
        [openingLine, activityLine, nutritionLine, closingLine]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    // MARK: - Opening: overall shape of the day so far

    private var activityCompletionAverage: Double {
        let moveProgress = min(metrics.activeEnergy / 500, 1)
        let exerciseProgress = min(metrics.exerciseMinutes / 30, 1)
        let stepsProgress = min(metrics.steps / 10_000, 1)
        return (moveProgress + exerciseProgress + stepsProgress) / 3
    }

    private var hour: Int { Calendar.current.component(.hour, from: now) }

    private var openingLine: String? {
        let average = activityCompletionAverage
        switch (average, hour) {
        case (0.7..., _):
            return "You're having an active day — nice work."
        case (0.35..<0.7, _):
            return "You're making steady progress today."
        case (..<0.35, 0..<12):
            return "Early days yet — plenty of time to get moving."
        default:
            return "Today's been quieter than usual so far."
        }
    }

    // MARK: - Activity: the one metric most worth mentioning

    private var activityLine: String? {
        let insights = HealthInsights(metrics: metrics, trends: trends, calorieTarget: calorieTarget)
        if let trend = [insights.stepsTrendInsight, insights.activeEnergyTrendInsight, insights.exerciseTrendInsight].compactMap({ $0 }).first {
            return trend
        }
        // Not enough history yet for a week-over-week comparison — fall back to goal progress.
        if metrics.steps > 0 {
            return "You've logged \(Int(metrics.steps)) of your 10,000 step goal so far."
        }
        return "No activity logged yet today."
    }

    // MARK: - Nutrition: what's logged, what meal is conspicuously missing

    private var caloriesConsumed: Double { todaysMeals.reduce(0) { $0 + $1.calories } }

    private var loggedMealTypes: Set<MealType> { Set(todaysMeals.map(\.mealType)) }

    /// The meal that "should" have been logged by now, based on time of day, but wasn't —
    /// e.g. don't nag about dinner at 9am, don't nag about breakfast at 9pm.
    private var expectedButMissingMeal: MealType? {
        let expectations: [(MealType, Range<Int>)] = [(.breakfast, 9..<24), (.lunch, 14..<24), (.dinner, 20..<24)]
        for (type, hourRange) in expectations where hourRange.contains(hour) && !loggedMealTypes.contains(type) {
            return type
        }
        return nil
    }

    private var nutritionLine: String? {
        if todaysMeals.isEmpty {
            if hour < 9 { return nil } // too early to say anything meaningful about food yet
            return "No meals logged yet today — add breakfast to start tracking your nutrition."
        }

        let loggedNames = MealType.allCases.filter { loggedMealTypes.contains($0) }.map(\.title).joined(separator: ", ")
        let calorieProgress = calorieTarget > 0 ? Int((caloriesConsumed / calorieTarget) * 100) : 0
        var line = "You've logged \(loggedNames) (\(Int(caloriesConsumed)) kcal, \(calorieProgress)% of your target)."

        if let missing = expectedButMissingMeal {
            line += " \(missing.title) isn't logged yet."
        }
        return line
    }

    // MARK: - Closing: whichever of goals/journal has the most useful thing to say

    private var closingLine: String? {
        goalLine ?? journalLine
    }

    private var goalLine: String? {
        guard !goals.isEmpty else { return nil }
        if let completed = goals.first(where: { $0.progress(using: metrics) >= 1 }) {
            return "Your \"\(completed.title)\" goal is complete for today."
        }
        guard let closest = goals.max(by: { $0.progress(using: metrics) < $1.progress(using: metrics) }) else { return nil }
        let percent = Int(closest.progress(using: metrics) * 100)
        guard percent > 0 else { return nil }
        return "Your \"\(closest.title)\" goal is \(percent)% of the way there."
    }

    private var journalLine: String? {
        let streak = JournalAnalytics(entries: journalEntries).currentStreak
        if streak >= 2 { return "You're on a \(streak)-day journaling streak." }
        if hour >= 18 && streak == 0 { return "You haven't journaled today — even a quick note helps spot patterns later." }
        return nil
    }
}
