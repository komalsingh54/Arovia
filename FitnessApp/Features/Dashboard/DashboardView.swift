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
                                HStack(spacing: 5) {
                                    PulseIndicator(color: AppTheme.tint, size: 6)
                                    Text("synced \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                                }
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText.opacity(0.7))
                            }
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        AnimatedMetricCard(title: "Steps", value: healthStore.metrics.steps, unit: "steps", systemImage: "figure.walk")
                            .staggeredAppear(0)
                        AnimatedMetricCard(title: "Active Energy", value: healthStore.metrics.activeEnergy, unit: "kcal", systemImage: "flame.fill")
                            .staggeredAppear(1)
                        AnimatedMetricCard(title: "Distance", value: healthStore.metrics.distanceMeters / 1000, unit: "km", systemImage: "location.fill", precision: 1)
                            .staggeredAppear(2)
                        AnimatedMetricCard(title: "Exercise", value: healthStore.metrics.exerciseMinutes, unit: "minutes", systemImage: "figure.run")
                            .staggeredAppear(3)
                        AnimatedMetricCard(title: "Resting HR", value: healthStore.metrics.restingHeartRate ?? 0, unit: "bpm", systemImage: "heart.fill", placeholder: healthStore.metrics.restingHeartRate == nil)
                            .staggeredAppear(4)
                        AnimatedMetricCard(title: "Sleep", value: healthStore.metrics.sleepHours ?? 0, unit: "hours", systemImage: "bed.double.fill", precision: 1, placeholder: healthStore.metrics.sleepHours == nil)
                            .staggeredAppear(5)
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

                            ForEach(Array(localStore.goals.prefix(3).enumerated()), id: \.element.id) { index, goal in
                                SectionCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(goal.title).font(.headline)
                                            Spacer()
                                            AnimatedIntText(value: Int(goal.progress(using: healthStore.metrics) * 100), suffix: "%")
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }
                                        ProgressView(value: goal.progress(using: healthStore.metrics))
                                            .animation(.spring(response: 0.7, dampingFraction: 0.8), value: goal.progress(using: healthStore.metrics))
                                    }
                                }
                                .staggeredAppear(index)
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
                            .simultaneousGesture(TapGesture().onEnded { Haptic.light() })
                            NavigationLink { JournalView() } label: {
                                QuickAction(title: "Add Note", image: "square.and.pencil")
                            }
                            .simultaneousGesture(TapGesture().onEnded { Haptic.light() })
                        }
                    }

                    if healthStore.status != .ready {
                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(statusMessage, systemImage: "heart.text.square")
                                    .font(.headline)
                                if let error = healthStore.lastErrorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.energy)
                                }
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

private struct AnimatedMetricCard: View {
    let title: String
    let value: Double
    let unit: String
    let systemImage: String
    var precision: Int = 0
    var placeholder: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.tint)
            if placeholder {
                Text("—").font(.title2.bold())
            } else {
                AnimatedNumberText(value: value, precision: precision)
                    .font(.title2.bold())
            }
            Text(unit)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(placeholder ? "no data" : "\(Int(value)) \(unit)")
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
