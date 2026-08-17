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
                    List {
                        ForEach(localStore.goals) { goal in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(goal.title).font(.headline)
                                    Spacer()
                                    Text("\(goal.currentValue(using: healthStore.metrics).formatted(.number.precision(.fractionLength(0)))) / \(goal.targetValue.formatted(.number.precision(.fractionLength(0)))) \(goal.unit)")
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                ProgressView(value: goal.progress(using: healthStore.metrics))
                                    .accessibilityLabel("\(goal.title) progress")
                                    .accessibilityValue("\(Int(goal.progress(using: healthStore.metrics) * 100)) percent")

                                if goal.progress(using: healthStore.metrics) >= 1 {
                                    Label("Goal complete", systemImage: "checkmark.circle.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.tint)
                                }

                                if goal.metric == .custom {
                                    Button("Log Progress") {
                                        goalToUpdate = goal
                                    }
                                    .font(.subheadline.weight(.semibold))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: localStore.deleteGoals)
                    }
                    .scrollContentBackground(.hidden)
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
