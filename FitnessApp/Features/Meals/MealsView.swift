//
//  MealsView.swift
//  Arovia
//

import SwiftUI
import Charts

struct MealsView: View {
    @EnvironmentObject private var localStore: LocalStore
    @EnvironmentObject private var healthStore: HealthStore
    @AppStorage("dailyCalorieTarget") private var dailyCalorieTarget = 2_000.0
    @AppStorage("dailyCarbsTarget") private var dailyCarbsTarget = 250.0
    @AppStorage("dailyFatTarget") private var dailyFatTarget = 65.0
    @AppStorage("dailyProteinTarget") private var dailyProteinTarget = 100.0

    @State private var selectedDate = Date.now
    @State private var isAddingMeal = false
    @State private var mealTypeToAdd: MealType = .breakfast
    @State private var isEditingTargets = false

    private var calendar: Calendar { .current }
    private var analytics: MealAnalytics { MealAnalytics(meals: localStore.mealEntries) }
    private var mealsForSelectedDay: [MealEntry] { analytics.meals(on: selectedDate) }

    private var caloriesConsumed: Double { mealsForSelectedDay.reduce(0) { $0 + $1.calories } }
    private var carbs: Double { mealsForSelectedDay.reduce(0) { $0 + $1.carbohydratesGrams } }
    private var fat: Double { mealsForSelectedDay.reduce(0) { $0 + $1.fatGrams } }
    private var protein: Double { mealsForSelectedDay.reduce(0) { $0 + $1.proteinGrams } }
    private var isToday: Bool { calendar.isDateInToday(selectedDate) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    weekStrip
                    goalRings
                    if isToday { energyBalanceSummary }

                    ForEach(MealType.allCases) { type in
                        mealSection(for: type)
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Nutrition").font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        MealInsightsView()
                    } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                }
            }
            .sheet(isPresented: $isAddingMeal) {
                FoodSearchView(mealType: mealTypeToAdd, date: selectedDate)
            }
            .sheet(isPresented: $isEditingTargets) {
                NutritionTargetsEditor(
                    calorieTarget: $dailyCalorieTarget,
                    carbsTarget: $dailyCarbsTarget,
                    fatTarget: $dailyFatTarget,
                    proteinTarget: $dailyProteinTarget
                )
            }
            .task { await healthStore.refresh() }
            .refreshable { await healthStore.refresh() }
        }
    }

    // MARK: Header + day selector

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nutrition")
                    .font(.largeTitle.weight(.bold))
                Text(selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Button("Edit Targets") { isEditingTargets = true }
                .font(.footnote.weight(.semibold))
        }
    }

    private var weekStrip: some View {
        let days = lastSevenDays()
        return HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                let selected = calendar.isDate(day, inSameDayAs: selectedDate)
                Button {
                    Haptic.light()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        selectedDate = day
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(day, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(.semibold))
                        Text(day, format: .dateTime.day())
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selected ? AppTheme.tint : AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(selected ? AppTheme.screenBackground : .primary)
                    .scaleEffect(selected ? 1.05 : 1)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private func lastSevenDays() -> [Date] {
        guard let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    // MARK: Goal rings

    private var goalRings: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            GoalRingCard(title: "Calories", value: caloriesConsumed, target: dailyCalorieTarget, unit: "", color: AppTheme.energy)
                .staggeredAppear(0)
            GoalRingCard(title: "Carbs", value: carbs, target: dailyCarbsTarget, unit: "g", color: .blue)
                .staggeredAppear(1)
            GoalRingCard(title: "Fat", value: fat, target: dailyFatTarget, unit: "g", color: .green)
                .staggeredAppear(2)
            GoalRingCard(title: "Protein", value: protein, target: dailyProteinTarget, unit: "g", color: .orange)
                .staggeredAppear(3)
        }
    }

    private var energyBalanceSummary: some View {
        let insights = HealthInsights(metrics: healthStore.metrics, trends: healthStore.weeklyTrends, calorieTarget: dailyCalorieTarget)
        return VStack(alignment: .leading, spacing: 6) {
            Label("Energy Balance", systemImage: "flame.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.tint)
            Text(insights.calorieBalanceInsight(caloriesConsumed: caloriesConsumed))
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.border) }
    }

    // MARK: Meal sections

    private func mealSection(for type: MealType) -> some View {
        let meals = mealsForSelectedDay.filter { $0.mealType == type }
        let total = meals.reduce(0) { $0 + $1.calories }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(type.title, systemImage: type.systemImage)
                    .font(.headline)
                Spacer()
                if !meals.isEmpty {
                    AnimatedIntText(value: Int(total), suffix: " kcal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            VStack(spacing: 0) {
                ForEach(meals) { meal in
                    MealRow(meal: meal)
                    if meal.id != meals.last?.id {
                        Divider().background(AppTheme.border)
                    }
                }

                if !meals.isEmpty {
                    Divider().background(AppTheme.border)
                }

                Button {
                    Haptic.light()
                    mealTypeToAdd = type
                    isAddingMeal = true
                } label: {
                    Label("Add Food", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.tint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.border) }
        }
    }
}

private struct GoalRingCard: View {
    let title: String
    let value: Double
    let target: Double
    let unit: String
    let color: Color

    private var progress: Double { target > 0 ? min(value / target, 1) : 0 }
    private var remaining: Double { target - value }
    private var isOver: Bool { remaining < 0 }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    AnimatedIntText(value: Int(abs(remaining)), suffix: "\(unit) \(isOver ? "over" : "under")")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    if !isOver {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(color)
                    }
                }
            }
            Spacer()
            AnimatedRing(progress: progress, color: color, lineWidth: 6, celebratesCompletion: true)
                .frame(width: 36, height: 36)
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.border) }
    }
}

private struct MealRow: View {
    let meal: MealEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(meal.name).font(.subheadline.weight(.semibold))
                HStack(spacing: 10) {
                    MacroBadge(label: "🔥", value: Int(meal.calories), color: AppTheme.energy)
                    MacroBadge(label: "C", value: Int(meal.carbohydratesGrams), color: .blue)
                    MacroBadge(label: "F", value: Int(meal.fatGrams), color: .green)
                    MacroBadge(label: "P", value: Int(meal.proteinGrams), color: .orange)
                }
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(meal.name), \(meal.mealType.title)")
        .accessibilityValue("\(Int(meal.calories)) calories, \(Int(meal.carbohydratesGrams)) grams carbohydrates, \(Int(meal.fatGrams)) grams fat, \(Int(meal.proteinGrams)) grams protein")
    }
}

private struct MacroBadge: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }
}


private struct NutritionTargetsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var calorieTarget: Double
    @Binding var carbsTarget: Double
    @Binding var fatTarget: Double
    @Binding var proteinTarget: Double

    @State private var calories: Double
    @State private var carbs: Double
    @State private var fat: Double
    @State private var protein: Double

    init(calorieTarget: Binding<Double>, carbsTarget: Binding<Double>, fatTarget: Binding<Double>, proteinTarget: Binding<Double>) {
        _calorieTarget = calorieTarget
        _carbsTarget = carbsTarget
        _fatTarget = fatTarget
        _proteinTarget = proteinTarget
        _calories = State(initialValue: calorieTarget.wrappedValue)
        _carbs = State(initialValue: carbsTarget.wrappedValue)
        _fat = State(initialValue: fatTarget.wrappedValue)
        _protein = State(initialValue: proteinTarget.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily Targets") {
                    LabeledContent("Calories") {
                        TextField("Calories", value: $calories, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Carbs (g)") {
                        TextField("Carbs", value: $carbs, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Fat (g)") {
                        TextField("Fat", value: $fat, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Protein (g)") {
                        TextField("Protein", value: $protein, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                Text("Choose targets that suit your own goals and professional guidance.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Nutrition Targets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        calorieTarget = max(calories, 1)
                        carbsTarget = max(carbs, 1)
                        fatTarget = max(fat, 1)
                        proteinTarget = max(protein, 1)
                        dismiss()
                    }
                }
            }
        }
    }
}
