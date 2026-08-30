//
//  ActivityView.swift
//  Arovia
//

import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var motionDetector: MotionActivityDetector
    @AppStorage("motionDetectionEnabled") private var motionDetectionEnabled = false
    @State private var workoutToAnnotate: WorkoutSummary?
    @State private var isLoggingWorkout = false

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

                    if motionDetectionEnabled && !motionDetector.suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Noticed on your iPhone")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.primaryText)
                            ForEach(motionDetector.suggestions) { session in
                                DetectedSessionCard(session: session) {
                                    Task {
                                        try? await healthStore.saveManualWorkout(type: session.type, start: session.start, duration: session.duration)
                                        motionDetector.dismiss(session)
                                    }
                                } onDismiss: {
                                    motionDetector.dismiss(session)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Workouts")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            Button("Log Workout", systemImage: "plus") { isLoggingWorkout = true }
                                .font(.caption.weight(.semibold))
                        }

                        if healthStore.recentWorkouts.isEmpty {
                            SectionCard {
                                Text("Your recent workouts will appear here after you connect Health.")
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(healthStore.recentWorkouts.prefix(5).enumerated()), id: \.element.id) { index, workout in
                                    Button { workoutToAnnotate = workout } label: {
                                        WorkoutSummaryRow(workout: workout)
                                    }
                                    .buttonStyle(.pressable)
                                    .staggeredAppear(index)
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
                            NavigationLink { FitnessTrendsView() } label: {
                                QuickLinkRow(title: "Insights", systemImage: "waveform.path.ecg")
                            }
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .clearsFloatingTabBar()
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await healthStore.refresh()
                if motionDetectionEnabled { await motionDetector.refresh(existingWorkouts: healthStore.recentWorkouts) }
            }
            .refreshable {
                await healthStore.refresh()
                if motionDetectionEnabled { await motionDetector.refresh(existingWorkouts: healthStore.recentWorkouts) }
            }
            .sheet(item: $workoutToAnnotate) { workout in
                WorkoutNoteEditor(workout: workout)
            }
            .sheet(isPresented: $isLoggingWorkout) {
                ManualWorkoutEditorView()
            }
        }
    }
}

private struct ManualWorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthStore: HealthStore

    @State private var type: ManualWorkoutType = .walk
    @State private var startDate = Date.now
    @State private var durationMinutes = 30.0
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    Picker("Type", selection: $type) {
                        ForEach(ManualWorkoutType.allCases) { type in
                            Label(type.title, systemImage: type.systemImage).tag(type)
                        }
                    }
                    DatePicker("When", selection: $startDate, in: ...Date.now)
                    Stepper(value: $durationMinutes, in: 5...300, step: 5) {
                        LabeledContent("Duration", value: "\(Int(durationMinutes)) min")
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.energy)
                }
                Text("Saved to Apple Health, the same place Watch-recorded workouts come from — it'll show up in Recent Workouts right alongside them.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
            }
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            do {
                                try await healthStore.saveManualWorkout(type: type, start: startDate, duration: durationMinutes * 60)
                                dismiss()
                            } catch {
                                errorMessage = "Couldn't save to Apple Health: \(error.localizedDescription)"
                            }
                            isSaving = false
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}

private struct DetectedSessionCard: View {
    let session: DetectedActivitySession
    let onLog: () -> Void
    let onDismiss: () -> Void

    private var durationText: String {
        let minutes = Int(session.duration / 60)
        return "\(minutes) min"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: session.type.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryAccent)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.secondaryAccent.opacity(0.16), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Looks like a \(durationText) \(session.type.title.lowercased())")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(session.start, format: .dateTime.weekday(.abbreviated).hour().minute())
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedText)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.appSecondary)
                Button("Log it", action: onLog)
                    .buttonStyle(.appPrimary)
            }
        }
        .padding()
        .softCard(radius: 20)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

private struct WorkoutSummaryRow: View {
    let workout: WorkoutSummary

    /// Duration relative to a 60-minute reference session — gives the progress bar real
    /// meaning instead of a decorative fill, while staying honest that it's not implying a
    /// "start workout" action Arovia doesn't support (hence a note icon, not a play triangle).
    private var sessionProgress: Double { min(workout.duration / 3600, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: "figure.run")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.tint)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.tint.opacity(0.16), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(workout.startDate, format: .dateTime.weekday(.abbreviated).month().day())
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "square.and.pencil")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedText)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.elevatedCardBackground, in: Circle())
            }
            HStack(spacing: 10) {
                Capsule()
                    .fill(AppTheme.tint.opacity(0.18))
                    .frame(height: 5)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.tint)
                            .scaleEffect(x: max(sessionProgress, 0.001), y: 1, anchor: .leading)
                            .animation(.spring(response: 0.7, dampingFraction: 0.85), value: sessionProgress)
                    }
                Text(workout.durationDescription)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize()
            }
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

