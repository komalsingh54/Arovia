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

                    energyBalanceCard.staggeredAppear(0)
                    heartRateCard.staggeredAppear(1)
                    sleepCard.staggeredAppear(2)
                    activityDistanceCard.staggeredAppear(3)
                    weightCard.staggeredAppear(4)
                    diagnosticsCard.staggeredAppear(5)
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .clearsFloatingTabBar()
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
                HStack(spacing: 5) {
                    PulseIndicator(color: AppTheme.tint, size: 6)
                    Text("Auto-synced from Apple Health · updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                }
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
                .buttonStyle(.appPrimary)
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
        .softCard(radius: 24)
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
                Text("Resting heart rate needs an Apple Watch — the iPhone itself has no heart rate sensor. It'll appear here automatically once you've worn a Watch overnight.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.8))
            }
        }
        .padding()
        .softCard(radius: 24)
    }

    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sleep")
                .font(.title3.weight(.bold))
            if let insight = insights.sleepInsight {
                Text(insight).font(.footnote).foregroundStyle(AppTheme.secondaryText)
            } else {
                Text("Needs either an Apple Watch worn overnight, or \"Track Sleep with iPhone\" turned on in Health app → Browse → Sleep (it's off by default).")
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
        .softCard(radius: 24)
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
        .softCard(radius: 24)
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
        .softCard(radius: 24)
    }

    private var diagnosticsCard: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                DiagnosticRow(label: "HealthKit available on device", value: healthStore.isHealthDataAvailable ? "Yes" : "No")
                DiagnosticRow(label: "Connection status", value: "\(healthStore.status)")
                DiagnosticRow(label: "Last successful sync", value: healthStore.lastUpdated?.formatted(date: .abbreviated, time: .standard) ?? "Never")
                if let error = healthStore.lastErrorMessage {
                    DiagnosticRow(label: "Last error", value: error)
                }
                DiagnosticRow(
                    label: "Types never granted",
                    value: healthStore.pendingPermissionNames.isEmpty ? "None — all granted" : healthStore.pendingPermissionNames.joined(separator: ", ")
                )

                Divider().background(AppTheme.border)

                Text("Raw values from the last fetch")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                DiagnosticRow(label: "Steps", value: "\(Int(healthStore.metrics.steps))")
                DiagnosticRow(label: "Active energy", value: "\(Int(healthStore.metrics.activeEnergy)) kcal")
                DiagnosticRow(label: "Resting energy", value: "\(Int(healthStore.metrics.restingEnergy)) kcal")
                DiagnosticRow(label: "Distance", value: "\(Int(healthStore.metrics.distanceMeters)) m")
                DiagnosticRow(label: "Heart rate (avg)", value: healthStore.metrics.averageHeartRate.map { "\(Int($0)) bpm" } ?? "nil")
                DiagnosticRow(label: "Resting heart rate", value: healthStore.metrics.restingHeartRate.map { "\(Int($0)) bpm" } ?? "nil")
                DiagnosticRow(label: "Sleep", value: healthStore.metrics.sleepHours.map { String(format: "%.2f hrs", $0) } ?? "nil")
                DiagnosticRow(label: "Weight", value: healthStore.metrics.latestWeightKg.map { String(format: "%.1f kg", $0) } ?? "nil")

                Text("A metric reading 0 or nil here, while Apple's own Health app also shows nothing for it, means there's genuinely no data recorded — not an app bug. If Health.app has data but this doesn't match, screenshot this panel.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.8))
                    .padding(.top, 4)

                Text("One Apple limitation worth knowing: for data types you only read (not write), iOS deliberately never tells any app — including this one — whether you specifically denied access to that type. It only tells us whether we've asked at all. So the only way to fully confirm a permission is granted is Settings → Privacy & Security → Health → Arovia, and to check the toggle for that specific type is on.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.8))
                    .padding(.top, 4)

                Button("Force Refresh") {
                    Task { await healthStore.refresh() }
                }
                .font(.footnote.weight(.semibold))
            }
            .padding(.top, 8)
        } label: {
            Label("Diagnostics", systemImage: "stethoscope")
                .font(.subheadline.weight(.semibold))
        }
        .padding()
        .softCard(radius: 24)
    }
}

private struct DiagnosticRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 200, alignment: .trailing)
        }
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
