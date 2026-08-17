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
                            ForEach(localStore.goals) { goal in
                                GoalRow(goal: goal, metrics: healthStore.metrics) { goalToUpdate = goal }
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
    @State private var title = ""
    @State private var targetValue = 10_000.0
    @State private var metric: GoalMetric = .steps

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
