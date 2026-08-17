//
//  ActivityView.swift
//  Arovia
//

import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @State private var workoutToAnnotate: WorkoutSummary?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Activity")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppTheme.primaryText)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(title: "Steps", value: healthStore.metrics.steps.formatted(.number.precision(.fractionLength(0))), unit: "steps", systemImage: "figure.walk")
                        MetricCard(title: "Active Energy", value: healthStore.metrics.activeEnergy.formatted(.number.precision(.fractionLength(0))), unit: "kcal", systemImage: "flame.fill")
                        MetricCard(title: "Exercise", value: healthStore.metrics.exerciseMinutes.formatted(.number.precision(.fractionLength(0))), unit: "minutes", systemImage: "figure.run")
                        MetricCard(title: "Workouts", value: healthStore.metrics.workoutCount.formatted(), unit: "today", systemImage: "dumbbell.fill")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Workouts")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.primaryText)

                        if healthStore.recentWorkouts.isEmpty {
                            SectionCard {
                                Text("Your recent workouts will appear here after you connect Health.")
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        } else {
                            VStack(spacing: 10) {
                                ForEach(healthStore.recentWorkouts.prefix(5)) { workout in
                                    Button { workoutToAnnotate = workout } label: {
                                        WorkoutSummaryRow(workout: workout)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("More")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.primaryText)

                        VStack(spacing: 10) {
                            NavigationLink { WorkoutsView() } label: {
                                QuickLinkRow(title: "Workout log", systemImage: "list.bullet.rectangle")
                            }
                            NavigationLink { HistoryView() } label: {
                                QuickLinkRow(title: "Journal history", systemImage: "clock.arrow.circlepath")
                            }
                            NavigationLink { InsightsView() } label: {
                                QuickLinkRow(title: "Weekly insights", systemImage: "chart.bar.fill")
                            }
                            NavigationLink { FitnessTrendsView() } label: {
                                QuickLinkRow(title: "Fitness trends", systemImage: "waveform.path.ecg")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .clearsFloatingTabBar()
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .task { await healthStore.refresh() }
            .refreshable { await healthStore.refresh() }
            .sheet(item: $workoutToAnnotate) { workout in
                WorkoutNoteEditor(workout: workout)
            }
        }
    }
}

private struct WorkoutSummaryRow: View {
    let workout: WorkoutSummary

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.run")
                .font(.title3)
                .foregroundStyle(AppTheme.tint)
                .frame(width: 40, height: 40)
                .background(AppTheme.elevatedCardBackground, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(workout.startDate, format: .dateTime.weekday(.abbreviated).month().day())
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Text(workout.durationDescription)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .softCard(radius: 20)
    }
}

private struct QuickLinkRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.tint)
                .frame(width: 34, height: 34)
                .background(AppTheme.elevatedCardBackground, in: Circle())
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.mutedText)
        }
        .padding()
        .softCard(radius: 18)
    }
}

