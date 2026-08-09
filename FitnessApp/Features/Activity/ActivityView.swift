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
            List {
                Section("Today") {
                    LabeledContent("Steps", value: healthStore.metrics.steps.formatted(.number.precision(.fractionLength(0))))
                    LabeledContent("Active energy", value: "\(healthStore.metrics.activeEnergy.formatted(.number.precision(.fractionLength(0)))) kcal")
                    LabeledContent("Exercise", value: "\(healthStore.metrics.exerciseMinutes.formatted(.number.precision(.fractionLength(0)))) min")
                    LabeledContent("Workouts", value: healthStore.metrics.workoutCount.formatted())
                }
                Section("Recent Workouts") {
                    if healthStore.recentWorkouts.isEmpty {
                        Text("Your recent workouts will appear here after you connect Health.")
                            .foregroundStyle(AppTheme.secondaryText)
                    } else {
                        ForEach(healthStore.recentWorkouts) { workout in
                            Button {
                                workoutToAnnotate = workout
                            } label: {
                                HStack {
                                    Image(systemName: "figure.run")
                                        .foregroundStyle(AppTheme.tint)
                                    VStack(alignment: .leading) {
                                        Text(workout.title)
                                            .foregroundStyle(.primary)
                                        Text(workout.startDate, format: .dateTime.weekday(.abbreviated).month().day())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(workout.durationDescription)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    NavigationLink("View journal history") { HistoryView() }
                    NavigationLink("View weekly insights") { InsightsView() }
                    NavigationLink("View fitness trends") { FitnessTrendsView() }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
            .navigationTitle("Activity")
            .task { await healthStore.refresh() }
            .refreshable { await healthStore.refresh() }
            .sheet(item: $workoutToAnnotate) { workout in
                WorkoutNoteEditor(workout: workout)
            }
        }
    }
}

private struct WorkoutNoteEditor: View {
    let workout: WorkoutSummary

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localStore: LocalStore
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    LabeledContent("Type", value: workout.title)
                    LabeledContent("Duration", value: workout.durationDescription)
                }
                Section("Your note") {
                    TextField("How did it feel?", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Workout Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        localStore.add(entry: JournalEntry(
                            title: workout.title,
                            details: note,
                            category: .workout,
                            date: workout.startDate
                        ))
                        dismiss()
                    }
                }
            }
        }
    }
}
