//
//  ProfileView.swift
//  Arovia
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var localStore: LocalStore
    @EnvironmentObject private var healthStore: HealthStore
    @AppStorage("profileFirstLaunchTimestamp") private var firstLaunchTimestamp: Double = 0

    private var memberSince: Date {
        Date(timeIntervalSince1970: firstLaunchTimestamp)
    }

    private var completedGoalsCount: Int {
        localStore.goals.filter { $0.progress(using: healthStore.metrics) >= 1 }.count
    }

    private var journalStreak: Int {
        JournalAnalytics(entries: localStore.journalEntries).currentStreak
    }

    private var mealLoggingStreak: Int {
        MealAnalytics(meals: localStore.mealEntries).loggingStreak
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(AppTheme.tint)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Profile")
                            .font(.title2.weight(.bold))
                        Text("Member since \(memberSince.formatted(date: .abbreviated, time: .omitted))")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricCard(title: "Goals Completed", value: completedGoalsCount.formatted(), unit: "goals", systemImage: "checkmark.seal.fill")
                    MetricCard(title: "Total Goals", value: localStore.goals.count.formatted(), unit: "active", systemImage: "target")
                    MetricCard(title: "Journal Streak", value: journalStreak.formatted(), unit: "days", systemImage: "flame.fill")
                    MetricCard(title: "Meal Log Streak", value: mealLoggingStreak.formatted(), unit: "days", systemImage: "fork.knife")
                }

                SectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Data & Privacy", systemImage: "lock.shield")
                            .font(.headline)
                        Text("Your goals, journal entries, and meals are stored on this device and synced privately to your iCloud account. Health metrics stay in Apple Health and are only read, never written, by Arovia.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if firstLaunchTimestamp == 0 {
                firstLaunchTimestamp = Date.now.timeIntervalSince1970
            }
            await healthStore.refresh()
        }
    }
}
