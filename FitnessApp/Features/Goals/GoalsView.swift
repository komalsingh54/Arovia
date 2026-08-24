//
//  GoalsView.swift
//  Arovia
//

import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var localStore: LocalStore
    @EnvironmentObject private var healthStore: HealthStore
    @State private var isAddingGoal = false
    @State private var goalToUpdate: FitnessGoal?

    var body: some View {
        NavigationStack {
            Group {
                if localStore.goals.isEmpty {
                    ContentUnavailableView("No goals yet", systemImage: "target", description: Text("Create a goal to keep your progress on track."))
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(Array(localStore.goals.enumerated()), id: \.element.id) { index, goal in
                                GoalRow(goal: goal, metrics: healthStore.metrics) { goalToUpdate = goal }
                                    .staggeredAppear(index)
                                    .contextMenu {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            if let index = localStore.goals.firstIndex(where: { $0.id == goal.id }) {
                                                localStore.deleteGoals(at: IndexSet(integer: index))
                                            }
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                    .background(AppTheme.screenBackground)
                    .clearsFloatingTabBar()
                }
            }
            .navigationTitle("Goals")
            .background(AppTheme.screenBackground)
            .toolbar { Button("Add", systemImage: "plus") { isAddingGoal = true } }
            .sheet(isPresented: $isAddingGoal) { GoalEditorView() }
            .sheet(item: $goalToUpdate) { goal in
                ProgressEditorView(goal: goal)
            }
            .task { await healthStore.refresh() }
        }
    }
}

private struct GoalRow: View {
    let goal: FitnessGoal
    let metrics: DailyMetrics
    let onLogProgress: () -> Void

    private var progress: Double { goal.progress(using: metrics) }
    private var isComplete: Bool { progress >= 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(goal.metric.title)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedText)
                }
                Spacer()
                Text("\(goal.currentValue(using: metrics).formatted(.number.precision(.fractionLength(0)))) / \(goal.targetValue.formatted(.number.precision(.fractionLength(0)))) \(goal.unit)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            ProgressView(value: progress)
                .tint(isComplete ? AppTheme.ringExercise : AppTheme.tint)
                .accessibilityLabel("\(goal.title) progress")
                .accessibilityValue("\(Int(progress * 100)) percent")

            HStack {
                if isComplete {
                    Label("Goal complete", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ringExercise)
                } else {
                    Text("\(Int(progress * 100))% of the way there")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedText)
                }
                Spacer()
                if goal.metric == .custom {
                    Button("Log Progress", action: onLogProgress)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.tint)
                }
            }
        }
        .padding()
        .softCard(radius: 20)
    }
}

private struct ProgressEditorView: View {
    let goal: FitnessGoal

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localStore: LocalStore
    @State private var currentValue: Double

    init(goal: FitnessGoal) {
        self.goal = goal
        _currentValue = State(initialValue: goal.currentValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Goal", value: goal.title)
                TextField("Current progress", value: $currentValue, format: .number)
                    .keyboardType(.decimalPad)
                Text("Target: \(goal.targetValue.formatted(.number.precision(.fractionLength(0)))) \(goal.unit)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Log Progress")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        localStore.update(goal: goal.updatingCurrentValue(to: max(currentValue, 0)))
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localStore: LocalStore
    @EnvironmentObject private var healthStore: HealthStore
    @State private var title = ""
    @State private var targetValue = 10_000.0
    @State private var metric: GoalMetric = .steps

    /// A round 10,000-step goal (or similar defaults) means nothing if your actual baseline is
    /// 4,000 — it's either trivially easy or discouragingly far off. This suggests a target from
    /// your own recent average plus a modest 10% stretch instead, rounded to something sensible.
    /// It's a suggestion, not an auto-fill — tapping it is a deliberate choice, not a surprise.
    private var suggestedTarget: Double? {
        switch metric {
        case .steps:
            return roundedSuggestion(from: healthStore.weeklyTrends.steps, roundingTo: 500)
        case .activeEnergy:
            return roundedSuggestion(from: healthStore.weeklyTrends.activeEnergy, roundingTo: 50)
        case .exerciseMinutes:
            return roundedSuggestion(from: healthStore.weeklyTrends.exerciseMinutes, roundingTo: 5)
        case .workouts, .custom:
            return nil
        }
    }

    private func roundedSuggestion(from points: [DailyMetricPoint], roundingTo step: Double) -> Double? {
        guard !points.isEmpty else { return nil }
        let average = points.reduce(0) { $0 + $1.value } / Double(points.count)
        guard average > 0 else { return nil }
        let stretched = average * 1.1
        return (stretched / step).rounded() * step
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Goal name", text: $title)
                Picker("Tracks", selection: $metric) {
                    ForEach(GoalMetric.allCases) { metric in
                        Text(metric.title).tag(metric)
                    }
                }
                TextField("Target", value: $targetValue, format: .number)
                    .keyboardType(.decimalPad)

                if let suggested = suggestedTarget, Int(suggested) != Int(targetValue) {
                    Button {
                        targetValue = suggested
                    } label: {
                        Label(
                            "Suggested: \(Int(suggested)) \(metric.defaultUnit) — based on your 7-day average, plus a bit",
                            systemImage: "wand.and.stars"
                        )
                    }
                    .font(.footnote)
                    .foregroundStyle(AppTheme.tint)
                }
            }
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        localStore.add(goal: FitnessGoal(title: title, targetValue: targetValue, unit: metric.defaultUnit, metric: metric))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || targetValue <= 0)
                }
            }
        }
    }
}
