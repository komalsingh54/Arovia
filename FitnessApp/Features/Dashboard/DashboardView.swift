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

                    // Bento grid — a featured ring card, a tall hydration card, and compact
                    // stat cells, mirroring the reference's mixed-size composition instead of
                    // a flat row of equal cards. Deliberately only two colors across the whole
                    // grid — tint for activity metrics, secondaryAccent for body/nutrition —
                    // instead of a different hue per card, which read as arbitrary rather than
                    // designed.
                    HStack(alignment: .top, spacing: 12) {
                        BentoRingCard(
                            title: "Steps", value: healthStore.metrics.steps, unit: "steps",
                            systemImage: "figure.walk", color: AppTheme.tint, goalValue: 10_000
                        )
                        .staggeredAppear(0)

                        BentoTallCard(
                            title: "Hydration", value: todaysWaterMl, unit: "ml",
                            systemImage: "drop.fill", color: AppTheme.secondaryAccent, goalValue: dailyWaterTarget
                        )
                        .staggeredAppear(1)
                    }

                    HStack(spacing: 12) {
                        BentoStatCard(title: "Active Energy", value: healthStore.metrics.activeEnergy, unit: "kcal", systemImage: "flame.fill", color: AppTheme.tint)
                            .staggeredAppear(2)
                        BentoStatCard(title: "Exercise", value: healthStore.metrics.exerciseMinutes, unit: "min", systemImage: "figure.run", color: AppTheme.tint)
                            .staggeredAppear(3)
                    }

                    HStack(spacing: 12) {
                        BentoStatCard(title: "Eaten", value: todaysCaloriesEaten, unit: "kcal", systemImage: "fork.knife", color: AppTheme.secondaryAccent)
                            .staggeredAppear(4)
                        BentoStatCard(
                            title: "Resting HR", value: healthStore.metrics.restingHeartRate ?? 0, unit: "bpm",
                            systemImage: "heart.fill", color: AppTheme.secondaryAccent,
                            placeholder: healthStore.metrics.restingHeartRate == nil
                        )
                        .staggeredAppear(5)
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

    private var todaysWaterMl: Double {
        localStore.waterEntries
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.amountMl }
    }

    private var todaysCaloriesEaten: Double {
        localStore.mealEntries
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.calories }
    }

    private var dailyBriefing: DailyBriefing {
        DailyBriefing(
            metrics: healthStore.metrics,
            trends: healthStore.weeklyTrends,
            todaysMeals: localStore.mealEntries.filter { Calendar.current.isDateInToday($0.date) },
            calorieTarget: dailyCalorieTarget,
            goals: localStore.goals,
            journalEntries: localStore.journalEntries,
            todaysWaterMl: todaysWaterMl,
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
