//
//  ContentView.swift
//  Arovia
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var localStore: LocalStore
    @EnvironmentObject private var mealReminderScheduler: MealReminderScheduler
    @EnvironmentObject private var wellnessReminderScheduler: WellnessReminderScheduler
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            HealthPermissionBanner()

            // Exactly 5 tabs on purpose — iOS auto-collapses anything past 5 into a stock
            // "More" list (that's what was rendering the undesigned overflow screen before).
            // Journal/Goals/Profile/Settings now live in our own MoreView instead.
            TabView {
                DashboardView()
                    .tabItem { Image(systemName: "square.grid.2x2.fill") }

                ActivityView()
                    .tabItem { Image(systemName: "figure.walk") }

                HealthOverviewView()
                    .tabItem { Image(systemName: "heart.fill") }

                MealsView()
                    .tabItem { Image(systemName: "fork.knife") }

                MoreView()
                    .tabItem { Image(systemName: "ellipsis") }
            }
            .tint(AppTheme.tint)
        }
        .background(AppTheme.screenBackground)
        .task {
            await refreshMealReminders()
            await refreshWellnessReminders()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await refreshMealReminders()
                    await refreshWellnessReminders()
                }
            }
        }
        .onChange(of: localStore.mealEntries) { _, _ in
            Task { await refreshMealReminders() }
        }
        .onChange(of: localStore.waterEntries) { _, _ in
            Task { await refreshWellnessReminders() }
        }
        .onChange(of: healthStore.metrics) { _, _ in
            Task { await refreshWellnessReminders() }
        }
    }

    /// Re-syncs the whole reminder schedule: fresh authorization status, fresh "what's already
    /// logged today" set. Cheap enough to call every time either of those might have changed.
    private func refreshMealReminders() async {
        await mealReminderScheduler.refreshAuthorizationStatus()
        let settings = MealReminderSettings.current()
        let todaysTypes = Set(
            localStore.mealEntries
                .filter { Calendar.current.isDateInToday($0.date) }
                .map(\.mealType)
        )
        await mealReminderScheduler.refreshSchedule(settings: settings, todaysLoggedMealTypes: todaysTypes)
    }

    private func refreshWellnessReminders() async {
        await wellnessReminderScheduler.refreshAuthorizationStatus()
        let settings = WellnessReminderSettings.current()
        let todaysWater = localStore.waterEntries
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.amountMl }
        await wellnessReminderScheduler.refreshSchedule(
            settings: settings,
            todaysWaterMl: todaysWater,
            todaysSteps: healthStore.metrics.steps
        )
    }
}
