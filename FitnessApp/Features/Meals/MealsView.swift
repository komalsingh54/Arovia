//
//  MealsView.swift
//  Arovia
//

import SwiftUI

struct MealsView: View {
    @EnvironmentObject private var localStore: LocalStore
    @EnvironmentObject private var healthStore: HealthStore
    @AppStorage("dailyCalorieTarget") private var dailyCalorieTarget = 2_000.0
    @State private var isAddingMeal = false
    @State private var isEditingTarget = false

    private var todaysMeals: [MealEntry] {
        localStore.mealEntries.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var caloriesConsumed: Double { todaysMeals.reduce(0) { $0 + $1.calories } }
    private var protein: Double { todaysMeals.reduce(0) { $0 + $1.proteinGrams } }
    private var carbohydrates: Double { todaysMeals.reduce(0) { $0 + $1.carbohydratesGrams } }
    private var fat: Double { todaysMeals.reduce(0) { $0 + $1.fatGrams } }
    private var netCalories: Double { caloriesConsumed - healthStore.metrics.activeEnergy }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nutrition")
                            .font(.largeTitle.weight(.bold))
                        Text("Track meals and understand your daily energy balance.")
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    calorieSummary
                    macroSummary

                    HStack {
                        Text("Today’s Meals")
                            .font(.title3.weight(.bold))
                        Spacer()
                        Button("Add Meal", systemImage: "plus") { isAddingMeal = true }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.tint)
                            .foregroundStyle(AppTheme.screenBackground)
                    }

                    if todaysMeals.isEmpty {
                        ContentUnavailableView("No meals logged", systemImage: "fork.knife", description: Text("Add a meal to start tracking today’s nutrition."))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(todaysMeals) { meal in
                            MealCard(meal: meal)
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isAddingMeal) { MealEditorView() }
            .sheet(isPresented: $isEditingTarget) { CalorieTargetEditor(target: $dailyCalorieTarget) }
            .task { await healthStore.refresh() }
            .refreshable { await healthStore.refresh() }
        }
    }

    private var calorieSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Daily Energy")
                    .font(.title3.weight(.bold))
                Spacer()
                Button("Edit target") { isEditingTarget = true }
                    .font(.subheadline.weight(.semibold))
            }
            HStack(alignment: .firstTextBaseline) {
                Text(caloriesConsumed.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                Text("/ \(dailyCalorieTarget.formatted(.number.precision(.fractionLength(0)))) kcal")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            ProgressView(value: min(caloriesConsumed / max(dailyCalorieTarget, 1), 1))
                .tint(caloriesConsumed > dailyCalorieTarget ? AppTheme.energy : AppTheme.tint)
            HStack {
                InsightLabel(title: "Intake", value: "\(Int(caloriesConsumed)) kcal", image: "fork.knife")
                Spacer()
                InsightLabel(title: "Active burn", value: "\(Int(healthStore.metrics.activeEnergy)) kcal", image: "flame.fill")
                Spacer()
                InsightLabel(title: "Net", value: "\(Int(netCalories)) kcal", image: "equal.circle.fill")
            }
            Text(calorieInsight)
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border) }
    }

    private var macroSummary: some View {
        HStack(spacing: 12) {
            MacroCard(title: "Protein", value: protein, color: .cyan)
            MacroCard(title: "Carbs", value: carbohydrates, color: AppTheme.tint)
            MacroCard(title: "Fat", value: fat, color: AppTheme.energy)
        }
    }

    private var calorieInsight: String {
        let remaining = dailyCalorieTarget - caloriesConsumed
        if remaining >= 0 {
            return "\(Int(remaining)) kcal remain within your daily target. Active calories burned are read from HealthKit."
        }
        return "You are \(Int(abs(remaining))) kcal above your daily target. Active calories burned are read from HealthKit."
    }
}

private struct MealCard: View {
    let meal: MealEntry

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: meal.mealType.systemImage)
                .font(.title3)
                .foregroundStyle(AppTheme.tint)
                .frame(width: 40, height: 40)
                .background(AppTheme.elevatedCardBackground, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name).font(.headline)
                Text("\(meal.mealType.title) · P \(Int(meal.proteinGrams))g · C \(Int(meal.carbohydratesGrams))g · F \(Int(meal.fatGrams))g")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Text("\(Int(meal.calories))")
                .font(.title3.weight(.bold))
            Text("kcal")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.border) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(meal.name), \(meal.mealType.title)")
        .accessibilityValue("\(Int(meal.calories)) calories, \(Int(meal.proteinGrams)) grams protein, \(Int(meal.carbohydratesGrams)) grams carbohydrates, \(Int(meal.fatGrams)) grams fat")
    }
}

private struct MacroCard: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(Int(value))g").font(.title3.bold())
            Text(title).font(.caption).foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct InsightLabel: View {
    let title: String
    let value: String
    let image: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: image)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value).font(.subheadline.weight(.bold))
        }
    }
}

private struct MealEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localStore: LocalStore
    @State private var name = ""
    @State private var mealType: MealType = .breakfast
    @State private var calories = 0.0
    @State private var protein = 0.0
    @State private var carbohydrates = 0.0
    @State private var fat = 0.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $mealType) {
                        ForEach(MealType.allCases) { type in
                            Label(type.title, systemImage: type.systemImage).tag(type)
                        }
                    }
                    TextField("Calories", value: $calories, format: .number)
                        .keyboardType(.decimalPad)
                }
                Section("Macros (optional, grams)") {
                    TextField("Protein", value: $protein, format: .number).keyboardType(.decimalPad)
                    TextField("Carbohydrates", value: $carbohydrates, format: .number).keyboardType(.decimalPad)
                    TextField("Fat", value: $fat, format: .number).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Log Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        localStore.add(meal: MealEntry(name: name, mealType: mealType, calories: calories, proteinGrams: protein, carbohydratesGrams: carbohydrates, fatGrams: fat))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || calories <= 0)
                }
            }
        }
    }
}

private struct CalorieTargetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var target: Double
    @State private var value: Double

    init(target: Binding<Double>) {
        _target = target
        _value = State(initialValue: target.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Daily calorie target", value: $value, format: .number)
                    .keyboardType(.decimalPad)
                Text("Choose a target that suits your own goals and professional guidance.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Calorie Target")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        target = max(value, 1)
                        dismiss()
                    }
                }
            }
        }
    }
}
