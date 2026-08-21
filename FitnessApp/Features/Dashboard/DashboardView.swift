//
//  DashboardView.swift
//  Arovia
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var localStore: LocalStore
    @AppStorage("dailyCalorieTarget") private var dailyCalorieTarget = 2_000.0
    @AppStorage("dailyWaterTargetMl") private var dailyWaterTarget = 2_000.0

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

                    // Hero carousel — steps, active energy, and exercise all get the featured
                    // glow treatment; swipe between them rather than flattening into a grid.
                    GlowHeroCarousel(items: heroMetrics) { metric in
                        GlowHeroCard(
                            title: metric.title, value: metric.value, unit: metric.unit,
                            systemImage: metric.systemImage, color: metric.color,
                            goalValue: metric.goalValue, precision: metric.precision
                        )
                    }
                    .staggeredAppear(0)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        QuietMetricCard(title: "Distance", value: healthStore.metrics.distanceMeters / 1000, unit: "km", systemImage: "location.fill", precision: 1)
                            .staggeredAppear(1)
                        QuietMetricCard(title: "Resting HR", value: healthStore.metrics.restingHeartRate ?? 0, unit: "bpm", systemImage: "heart.fill", placeholder: healthStore.metrics.restingHeartRate == nil)
                            .staggeredAppear(2)
                        QuietMetricCard(title: "Sleep", value: healthStore.metrics.sleepHours ?? 0, unit: "hrs", systemImage: "bed.double.fill", precision: 1, placeholder: healthStore.metrics.sleepHours == nil)
                            .staggeredAppear(3)
                    }

                    if healthStore.status == .ready {
                        dailyBriefingCard
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
                                    .buttonStyle(.appPrimary)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .clearsFloatingTabBar()
            .toolbar(.hidden, for: .navigationBar)
            .task { await healthStore.refresh() }
            .refreshable { await healthStore.refresh() }
        }
    }

    private struct HeroMetric: Identifiable {
        let id: String
        let title: String
        let value: Double
        let unit: String
        let systemImage: String
        let color: Color
        var goalValue: Double? = nil
        var precision: Int = 0
    }

    private var heroMetrics: [HeroMetric] {
        [
            HeroMetric(id: "steps", title: "Steps", value: healthStore.metrics.steps, unit: "steps", systemImage: "figure.walk", color: AppTheme.glowSteps, goalValue: 10_000),
            HeroMetric(id: "energy", title: "Active energy", value: healthStore.metrics.activeEnergy, unit: "kcal", systemImage: "flame.fill", color: AppTheme.glowEnergy, goalValue: 500),
            HeroMetric(id: "exercise", title: "Exercise", value: healthStore.metrics.exerciseMinutes, unit: "min", systemImage: "figure.run", color: AppTheme.glowExercise, goalValue: 30)
        ]
    }

    private var dailyBriefing: DailyBriefing {
        DailyBriefing(
            metrics: healthStore.metrics,
            trends: healthStore.weeklyTrends,
            todaysMeals: localStore.mealEntries.filter { Calendar.current.isDateInToday($0.date) },
            calorieTarget: dailyCalorieTarget,
            goals: localStore.goals,
            journalEntries: localStore.journalEntries,
            todaysWaterMl: localStore.waterEntries
                .filter { Calendar.current.isDateInToday($0.date) }
                .reduce(0) { $0 + $1.amountMl },
            waterTargetMl: dailyWaterTarget
        )
    }

    /// Reads like a short daily briefing rather than a stat card — activity, nutrition, and
    /// whatever's most worth flagging in goals/journal, synthesized into a few sentences
    /// instead of making the person cross-reference four separate cards themselves.
    private var dailyBriefingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Your day so far", systemImage: "sparkles")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.tint)
                Spacer()
                NavigationLink("Full insights") { FitnessTrendsView() }
                    .font(.caption)
            }
            Text(dailyBriefing.paragraph)
                .font(.subheadline)
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .softCard()
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

/// Smaller, quieter card for secondary stats that don't need the hero glow treatment.
private struct QuietMetricCard: View {
    let title: String
    let value: Double
    let unit: String
    let systemImage: String
    var precision: Int = 0
    var placeholder: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            if placeholder {
                Text("—").font(.title3.bold())
            } else {
                AnimatedNumberText(value: value, precision: precision)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.primaryText)
            }
            Text(placeholder ? "\(title)" : "\(unit) · \(title)")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .softCard(radius: 16)
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
            .foregroundStyle(AppTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.elevatedCardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
