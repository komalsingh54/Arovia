//
//  DashboardView.swift
//  Arovia
//

import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var localStore: LocalStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.tint)
                            .textCase(.uppercase)
                        Text("Move with purpose")
                            .font(.largeTitle.weight(.bold))
                        HStack(spacing: 6) {
                            Text("Your performance, at a glance.")
                                .foregroundStyle(AppTheme.secondaryText)
                            if let lastUpdated = healthStore.lastUpdated {
                                Text("· synced \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText.opacity(0.7))
                            }
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(title: "Steps", value: healthStore.metrics.steps.formatted(.number.precision(.fractionLength(0))), unit: "steps", systemImage: "figure.walk")
                        MetricCard(title: "Active Energy", value: healthStore.metrics.activeEnergy.formatted(.number.precision(.fractionLength(0))), unit: "kcal", systemImage: "flame.fill")
                        MetricCard(title: "Distance", value: String(format: "%.1f", healthStore.metrics.distanceMeters / 1000), unit: "km", systemImage: "location.fill")
                        MetricCard(title: "Exercise", value: healthStore.metrics.exerciseMinutes.formatted(.number.precision(.fractionLength(0))), unit: "minutes", systemImage: "figure.run")
                        MetricCard(title: "Resting HR", value: healthStore.metrics.restingHeartRate.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "—", unit: "bpm", systemImage: "heart.fill")
                        MetricCard(title: "Sleep", value: healthStore.metrics.sleepHours.map { String(format: "%.1f", $0) } ?? "—", unit: "hours", systemImage: "bed.double.fill")
                    }

                    if !healthStore.weeklyTrends.steps.isEmpty {
                        weeklyStepsSparkline
                    }

                    if !localStore.goals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Today’s Goals")
                                    .font(.title3.bold())
                                Spacer()
                                NavigationLink("See all") { GoalsView() }
                                    .font(.subheadline)
                            }

                            ForEach(localStore.goals.prefix(3)) { goal in
                                SectionCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(goal.title).font(.headline)
                                            Spacer()
                                            Text("\(Int(goal.progress(using: healthStore.metrics) * 100))%")
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }
                                        ProgressView(value: goal.progress(using: healthStore.metrics))
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.title3.bold())
                        HStack(spacing: 12) {
                            NavigationLink { GoalsView() } label: {
                                QuickAction(title: "Add Goal", image: "target")
                            }
                            NavigationLink { JournalView() } label: {
                                QuickAction(title: "Add Note", image: "square.and.pencil")
                            }
                        }
                    }

                    if healthStore.status != .ready {
                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(statusMessage, systemImage: "heart.text.square")
                                    .font(.headline)
                                if healthStore.status == .authorizationRequired || healthStore.status == .denied {
                                    Button("Connect Health") {
                                        Task { await healthStore.requestAuthorization() }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .task { await healthStore.refresh() }
            .refreshable { await healthStore.refresh() }
        }
    }

    private var weeklyStepsSparkline: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("7-Day Steps")
                    .font(.subheadline.weight(.bold))
                Spacer()
                NavigationLink("Full trends") { FitnessTrendsView() }
                    .font(.caption)
            }
            Chart(healthStore.weeklyTrends.steps) { point in
                BarMark(x: .value("Day", point.date, unit: .day), y: .value("Steps", point.value))
                    .foregroundStyle(AppTheme.tint.gradient)
                    .cornerRadius(4)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
            .chartYAxis(.hidden)
            .frame(height: 90)
            .accessibilityLabel("Steps over the last 7 days")
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.border) }
    }

    private var statusMessage: String {
        switch healthStore.status {
        case .loading: "Refreshing your health data…"
        case .unavailable: "Health data is unavailable on this device."
        case .authorizationRequired: "Connect Health to see today’s progress."
        case .denied: "Health access is needed to show today’s progress."
        case .failed: "We couldn’t refresh your health data. Try again later."
        default: "Your daily health snapshot will appear here."
        }
    }
}

private struct QuickAction: View {
    let title: String
    let image: String

    var body: some View {
        Label(title, systemImage: image)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.elevatedCardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
