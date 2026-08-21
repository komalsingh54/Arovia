//
//  WeeklyRecapView.swift
//  Arovia
//

import SwiftUI

struct WeeklyRecapView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var localStore: LocalStore

    private var recap: WeeklyRecap {
        WeeklyRecap(trends: healthStore.weeklyTrends, journalEntries: localStore.journalEntries, waterEntries: localStore.waterEntries)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Recap")
                        .font(.largeTitle.weight(.bold))
                    Text("The last 7 days, at a glance.")
                        .foregroundStyle(AppTheme.secondaryText)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricCard(title: "Total Steps", value: recap.totalSteps.formatted(.number.precision(.fractionLength(0))), unit: "steps", systemImage: "figure.walk")
                    MetricCard(title: "Avg Steps/Day", value: recap.averageSteps.formatted(.number.precision(.fractionLength(0))), unit: "steps", systemImage: "chart.bar.fill")
                    MetricCard(title: "Active Energy", value: recap.totalActiveEnergy.formatted(.number.precision(.fractionLength(0))), unit: "kcal", systemImage: "flame.fill")
                    MetricCard(title: "Active Days", value: "\(recap.activeDayCount)/7", unit: "hit exercise goal", systemImage: "checkmark.seal.fill")
                }

                if let best = recap.bestStepsDay, best.value > 0 {
                    HStack(spacing: 14) {
                        Image(systemName: "trophy.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Best day")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("\(best.date.formatted(.dateTime.weekday(.wide))) — \(Int(best.value).formatted()) steps")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        Spacer()
                    }
                    .padding()
                    .softCard(radius: 18)
                }

                if recap.journalEntriesThisWeek > 0 {
                    HStack(spacing: 14) {
                        Image(systemName: "note.text")
                            .font(.title2)
                            .foregroundStyle(AppTheme.secondaryAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Journal")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("\(recap.journalEntriesThisWeek) entries, \(recap.currentStreak)-day streak")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        Spacer()
                    }
                    .padding()
                    .softCard(radius: 18)
                }

                if recap.averageWaterMl > 0 {
                    HStack(spacing: 14) {
                        Image(systemName: "drop.fill")
                            .font(.title2)
                            .foregroundStyle(.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hydration")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("Averaged \(Int(recap.averageWaterMl)) ml/day")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        Spacer()
                    }
                    .padding()
                    .softCard(radius: 18)
                }

                ShareLink(item: recap.summaryText) {
                    Label("Share this week", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(AppTheme.screenBackground)
                }

                Text("Compares only within this week for now — a true week-over-week comparison is a natural next addition.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.mutedText)
            }
            .padding()
        }
        .background(AppTheme.screenBackground)
        .clearsFloatingTabBar()
        .navigationTitle("Weekly Recap")
        .navigationBarTitleDisplayMode(.inline)
    }
}
