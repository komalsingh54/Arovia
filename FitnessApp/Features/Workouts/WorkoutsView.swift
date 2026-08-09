//
//  WorkoutsView.swift
//  Arovia
//

import SwiftUI

struct WorkoutsView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var localStore: LocalStore
    @State private var workoutToAnnotate: WorkoutSummary?

    private var workoutNotesByTitleAndDay: [String: JournalEntry] {
        let calendar = Calendar.current
        var lookup: [String: JournalEntry] = [:]
        for entry in localStore.journalEntries where entry.category == .workout {
            let key = entry.title + calendar.startOfDay(for: entry.date).formatted(.iso8601)
            lookup[key] = entry
        }
        return lookup
    }

    private var weeklyDuration: TimeInterval {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        return healthStore.recentWorkouts
            .filter { $0.startDate >= weekStart }
            .reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        Group {
            if healthStore.recentWorkouts.isEmpty {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text(healthStore.status == .ready
                        ? "Workouts you record in the Health app will appear here."
                        : "Connect Health from the Dashboard to see your workout history.")
                )
            } else {
                List {
                    Section {
                        HStack {
                            MetricSummary(title: "This week", value: weekDurationDescription, systemImage: "calendar")
                            Divider()
                            MetricSummary(title: "Logged", value: "\(healthStore.recentWorkouts.count)", systemImage: "list.bullet")
                        }
                        .listRowBackground(Color.clear)
                    }

                    Section("Recent") {
                        ForEach(healthStore.recentWorkouts) { workout in
                            Button {
                                workoutToAnnotate = workout
                            } label: {
                                WorkoutRow(workout: workout, note: note(for: workout))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await healthStore.refresh() }
        .refreshable { await healthStore.refresh() }
        .sheet(item: $workoutToAnnotate) { workout in
            WorkoutNoteEditor(workout: workout, existingNote: note(for: workout)?.details ?? "")
        }
    }

    private func note(for workout: WorkoutSummary) -> JournalEntry? {
        let key = workout.title + Calendar.current.startOfDay(for: workout.startDate).formatted(.iso8601)
        return workoutNotesByTitleAndDay[key]
    }

    private var weekDurationDescription: String {
        Duration.seconds(weeklyDuration).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

private struct WorkoutRow: View {
    let workout: WorkoutSummary
    let note: JournalEntry?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "figure.run")
                .foregroundStyle(AppTheme.tint)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title).foregroundStyle(.primary).font(.headline)
                Text(workout.startDate, format: .dateTime.weekday(.abbreviated).month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note, !note.details.isEmpty {
                    Text(note.details)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                } else {
                    Text("Tap to add a note")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText.opacity(0.7))
                }
            }
            Spacer()
            Text(workout.durationDescription)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical, 4)
    }
}

private struct MetricSummary: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.title3.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
