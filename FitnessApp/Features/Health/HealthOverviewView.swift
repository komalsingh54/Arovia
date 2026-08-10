//
//  HealthOverviewView.swift
//  Arovia
//

import SwiftUI
import Charts

struct HealthOverviewView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var localStore: LocalStore
    @AppStorage("dailyCalorieTarget") private var dailyCalorieTarget = 2_000.0

    private var insights: HealthInsights {
        HealthInsights(metrics: healthStore.metrics, trends: healthStore.weeklyTrends, calorieTarget: dailyCalorieTarget)
    }

    private var todaysCalories: Double {
        localStore.mealEntries
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if healthStore.status != .ready {
                        connectHealthCard
                    }

                    energyBalanceCard
                    heartRateCard
                    sleepCard
                    activityDistanceCard
                    weightCard
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("Health")
            .navigationBarTitleDisplayMode(.inline)
            .task { await healthStore.refresh() }
            .refreshable { await healthStore.refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Health")
                .font(.largeTitle.weight(.bold))
            if let lastUpdated = healthStore.lastUpdated {
                Text("Auto-synced from Apple Health · updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                Text("A complete view of your body's numbers, synced from Apple Health.")
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var connectHealthCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Connect Apple Health", systemImage: "heart.text.square")
                    .font(.headline)
                Text("Grant access to see heart rate, sleep, distance, and weight trends here automatically.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                if let error = healthStore.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppTheme.energy)
                }
                Button("Connect Health") {
                    Task { await healthStore.requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.tint)
            }
        }
    }

    private var energyBalanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Energy Balance")
                .font(.title3.weight(.bold))
            HStack(spacing: 12) {
                MetricPill(title: "Active", value: "\(Int(healthStore.metrics.activeEnergy))", unit: "kcal", color: AppTheme.energy)
                MetricPill(title: "Resting", value: "\(Int(healthStore.metrics.restingEnergy))", unit: "kcal", color: .cyan)
                MetricPill(title: "Eaten", value: "\(Int(todaysCalories))", unit: "kcal", color: AppTheme.tint)
            }
            Text(insights.calorieBalanceInsight(caloriesConsumed: todaysCalories))
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)

            if !healthStore.weeklyTrends.activeEnergy.isEmpty {
                Chart(healthStore.weeklyTrends.activeEnergy) { point in
                    BarMark(x: .value("Day", point.date, unit: .day), y: .value("kcal", point.value))
                        .foregroundStyle(AppTheme.energy.gradient)
                        .cornerRadius(4)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.abbreviated)) } }
                .frame(height: 140)
                .accessibilityLabel("Active energy burned over the last 7 days")
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border) }
    }

    private var heartRateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Heart Rate")
                .font(.title3.weight(.bold))
            HStack(spacing: 12) {
                MetricPill(title: "Average today", value: healthStore.metrics.averageHeartRate.map { "\(Int($0))" } ?? "—", unit: "bpm", color: AppTheme.energy)
                MetricPill(title: "Resting", value: healthStore.metrics.restingHeartRate.map { "\(Int($0))" } ?? "—", unit: "bpm", color: .cyan)
            }
            if let insight = insights.restingHeartRateTrendInsight {
                Text(insight).font(.footnote).foregroundStyle(AppTheme.secondaryText)
            }

            let restingSeries = healthStore.weeklyTrends.restingHeartRate.filter { $0.value > 0 }
            if !restingSeries.isEmpty {
                Chart(restingSeries) { point in
                    LineMark(x: .value("Day", point.date, unit: .day), y: .value("bpm", point.value))
                        .foregroundStyle(AppTheme.tint)
                        .symbol(Circle())
                    AreaMark(x: .value("Day", point.date, unit: .day), y: .value("bpm", point.value))
                        .foregroundStyle(AppTheme.tint.opacity(0.12))
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.abbreviated)) } }
                .frame(height: 140)
                .accessibilityLabel("Resting heart rate over the last 7 days")
            } else {
                Text("Resting heart rate needs an Apple Watch — it'll appear here automatically once available.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.8))
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border) }
    }

    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sleep")
                .font(.title3.weight(.bold))
            if let insight = insights.sleepInsight {
                Text(insight).font(.footnote).foregroundStyle(AppTheme.secondaryText)
            } else {
                Text("Sleep tracked in Apple Health or your Apple Watch will appear here automatically.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            let sleepSeries = healthStore.weeklyTrends.sleepHours
            if sleepSeries.contains(where: { $0.value > 0 }) {
                Chart(sleepSeries) { point in
                    BarMark(x: .value("Day", point.date, unit: .day), y: .value("Hours", point.value))
                        .foregroundStyle(.cyan.gradient)
                        .cornerRadius(4)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.abbreviated)) } }
                .frame(height: 140)
                .accessibilityLabel("Hours slept per night over the last 7 days")
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border) }
    }

    private var activityDistanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Steps & Distance")
                .font(.title3.weight(.bold))
            HStack(spacing: 12) {
                MetricPill(title: "Steps today", value: "\(Int(healthStore.metrics.steps))", unit: "steps", color: AppTheme.tint)
                MetricPill(title: "Distance", value: String(format: "%.1f", healthStore.metrics.distanceMeters / 1000), unit: "km", color: .cyan)
                MetricPill(title: "Flights", value: "\(Int(healthStore.metrics.flightsClimbed))", unit: "climbed", color: AppTheme.energy)
            }
            if let insight = insights.stepsTrendInsight {
                Text(insight).font(.footnote).foregroundStyle(AppTheme.secondaryText)
            }

            if !healthStore.weeklyTrends.steps.isEmpty {
                Chart(healthStore.weeklyTrends.steps) { point in
                    LineMark(x: .value("Day", point.date, unit: .day), y: .value("Steps", point.value))
                        .foregroundStyle(AppTheme.tint)
                        .interpolationMethod(.catmullRom)
                        .symbol(Circle())
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.abbreviated)) } }
                .frame(height: 140)
                .accessibilityLabel("Steps over the last 7 days")
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border) }
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Weight")
                .font(.title3.weight(.bold))
            if let weight = healthStore.metrics.latestWeightKg {
                Text("Latest: \(String(format: "%.1f", weight)) kg")
                    .font(.subheadline.weight(.semibold))
            }
            if let insight = insights.weightTrendInsight {
                Text(insight).font(.footnote).foregroundStyle(AppTheme.secondaryText)
            } else {
                Text("Log weight in the Health app to see your trend here automatically.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            let weightSeries = healthStore.weeklyTrends.weightKg
            if weightSeries.count >= 2 {
                Chart(weightSeries) { point in
                    LineMark(x: .value("Day", point.date, unit: .day), y: .value("kg", point.value))
                        .foregroundStyle(AppTheme.energy)
                        .symbol(Circle())
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.abbreviated)) } }
                .frame(height: 140)
                .accessibilityLabel("Weight over the last 7 days")
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border) }
    }
}

private struct MetricPill: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(value).font(.title3.weight(.bold))
            Text(unit).font(.caption2).foregroundStyle(AppTheme.secondaryText)
            Text(title).font(.caption2).foregroundStyle(AppTheme.secondaryText.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.elevatedCardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
