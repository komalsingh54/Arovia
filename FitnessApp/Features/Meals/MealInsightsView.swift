//
//  MealInsightsView.swift
//  Arovia
//

import SwiftUI
import Charts

struct MealInsightsView: View {
    @EnvironmentObject private var localStore: LocalStore
    @State private var period: MealAnalytics.Period = .week

    private var analytics: MealAnalytics { MealAnalytics(meals: localStore.mealEntries) }
    private var average: (carbs: Double, fat: Double, protein: Double) { analytics.averageMacros(for: period) }
    private var dailyMacros: [MealAnalytics.DailyMacros] { analytics.dailyMacros(for: period) }
    private var nutrientBreakdown: [(name: String, grams: Double, percent: Double)] { analytics.nutrientCaloriePercentages(for: period) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Macros")
                    .font(.largeTitle.weight(.bold))

                Picker("Period", selection: $period) {
                    ForEach(MealAnalytics.Period.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                averageHeader

                chart

                Text("Averages exclude today and days without data.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)

                if !nutrientBreakdown.isEmpty {
                    nutrientList
                }

                caloriesInsightCard
            }
            .padding()
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var averageHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AVERAGE")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.secondaryText)
            HStack(spacing: 16) {
                MacroAverage(label: "C", value: average.carbs, color: .blue)
                MacroAverage(label: "F", value: average.fat, color: .green)
                MacroAverage(label: "P", value: average.protein, color: .orange)
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(dailyMacros) { day in
                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Grams", day.carbs))
                    .foregroundStyle(by: .value("Macro", "Carbs"))
                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Grams", day.fat))
                    .foregroundStyle(by: .value("Macro", "Fat"))
                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Grams", day.protein))
                    .foregroundStyle(by: .value("Macro", "Protein"))
            }
        }
        .chartForegroundStyleScale(["Carbs": Color.blue, "Fat": Color.green, "Protein": Color.orange])
        .chartXAxis {
            AxisMarks(values: period == .week ? .stride(by: .day) : .automatic(desiredCount: 6)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel(period == .week ? date.formatted(.dateTime.weekday(.narrow)) : date.formatted(.dateTime.month(.abbreviated).day()))
                }
            }
        }
        .frame(height: period == .week ? 220 : 180)
        .accessibilityLabel("Macronutrient grams per day for the selected period")
    }

    private var nutrientList: some View {
        VStack(spacing: 0) {
            ForEach(Array(nutrientBreakdown.enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item.name)
                    Spacer()
                    Text("\(Int(item.grams))g (\(Int(item.percent * 100))%)")
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.vertical, 12)
                if index != nutrientBreakdown.count - 1 {
                    Divider().background(AppTheme.border)
                }
            }
        }
        .padding(.horizontal)
        .softCard(radius: 18)
    }

    private var caloriesInsightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Insights", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.tint)
            Text("Average \(Int(analytics.averageDailyCalories)) kcal logged per day. \(streakText)")
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
            if let biggest = analytics.biggestContributor() {
                Text("\(biggest.mealType.title) is your biggest calorie contributor today at \(Int(biggest.calories)) kcal.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding()
        .softCard(radius: 18)
    }

    private var streakText: String {
        let streak = analytics.loggingStreak
        return streak <= 1 ? "Log today to start a streak." : "You’ve logged meals \(streak) days in a row."
    }
}

private struct MacroAverage: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text("\(Int(value))g")
                .font(.title3.weight(.bold))
        }
    }
}
