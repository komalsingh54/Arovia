//
//  WorkoutNoteEditor.swift
//  Arovia
//
//  Shared sheet for attaching a personal note to a HealthKit workout. Used from both
//  ActivityView and WorkoutsView so the two screens stay consistent.
//

import SwiftUI

struct WorkoutNoteEditor: View {
    let workout: WorkoutSummary

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localStore: LocalStore
    @State private var note: String

    /// If the workout already has a note logged, pass it in so the editor starts pre-filled.
    init(workout: WorkoutSummary, existingNote: String = "") {
        self.workout = workout
        _note = State(initialValue: existingNote)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    LabeledContent("Type", value: workout.title)
                    LabeledContent("Duration", value: workout.durationDescription)
                    LabeledContent("Date", value: workout.startDate.formatted(date: .abbreviated, time: .shortened))
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
