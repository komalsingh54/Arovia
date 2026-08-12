//
//  FoodSearchView.swift
//  Arovia
//

import SwiftUI

struct FoodSearchView: View {
    let mealType: MealType
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localStore: LocalStore
    @State private var query = ""
    @State private var selectedFood: FoodItem?
    @State private var isCreatingCustom = false
    @State private var isScanningBarcode = false
    @State private var isLookingUpBarcode = false
    @State private var barcodeErrorMessage: String?

    private var results: [FoodItem] {
        query.isEmpty ? FoodLibrary.suggestions : FoodLibrary.search(query)
    }

    /// Distinct foods the person has actually logged before, most recent first — the most useful
    /// "suggestions" since they're specific to what this person eats.
    private var recentFoods: [FoodItem] {
        var seen = Set<String>()
        var result: [FoodItem] = []
        for meal in localStore.mealEntries where !seen.contains(meal.name.lowercased()) {
            seen.insert(meal.name.lowercased())
            result.append(FoodItem(
                name: meal.name,
                servingDescription: "as logged",
                servingGrams: 0,
                calories: meal.calories,
                proteinGrams: meal.proteinGrams,
                carbohydratesGrams: meal.carbohydratesGrams,
                fatGrams: meal.fatGrams
            ))
            if result.count == 6 { break }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if isLookingUpBarcode {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Looking up product…")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }

                if !localStore.scannedFoods.isEmpty && query.isEmpty {
                    Section("Previously Scanned") {
                        ForEach(localStore.scannedFoods.prefix(5)) { food in
                            FoodRow(food: food) { selectedFood = food }
                        }
                    }
                }

                if query.isEmpty && !recentFoods.isEmpty {
                    Section("Recent") {
                        ForEach(recentFoods) { food in
                            FoodRow(food: food) { selectedFood = food }
                        }
                    }
                }

                Section(query.isEmpty ? "Suggestions" : "Results") {
                    if results.isEmpty {
                        Text("No matches — try a different search, scan a barcode, or create a custom entry.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    } else {
                        ForEach(results) { food in
                            FoodRow(food: food) { selectedFood = food }
                        }
                    }
                }

                Section {
                    Button {
                        isScanningBarcode = true
                    } label: {
                        Label("Scan Barcode", systemImage: "barcode.viewfinder")
                    }
                    Button {
                        isCreatingCustom = true
                    } label: {
                        Label("Create Custom Food", systemImage: "square.and.pencil")
                    }
                }
            }
            .searchable(text: $query, prompt: "Search for food")
            .navigationTitle("Add to \(mealType.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(item: $selectedFood) { food in
                FoodQuantityView(food: food, mealType: mealType, date: date) {
                    dismiss()
                }
            }
            .sheet(isPresented: $isCreatingCustom) {
                CustomFoodEditorView(mealType: mealType, date: date) {
                    dismiss()
                }
            }
            .sheet(isPresented: $isScanningBarcode) {
                BarcodeScannerView { barcode in
                    isScanningBarcode = false
                    Task { await handleScannedBarcode(barcode) }
                }
            }
            .alert(
                "Product Not Found",
                isPresented: Binding(get: { barcodeErrorMessage != nil }, set: { if !$0 { barcodeErrorMessage = nil } })
            ) {
                Button("Add Manually") {
                    barcodeErrorMessage = nil
                    isCreatingCustom = true
                }
                Button("Cancel", role: .cancel) { barcodeErrorMessage = nil }
            } message: {
                Text(barcodeErrorMessage ?? "")
            }
        }
    }

    /// Checks the local cache first (instant, works offline), then falls back to Open Food Facts.
    /// Every successful lookup is cached so re-scanning the same product never needs the network again.
    private func handleScannedBarcode(_ barcode: String) async {
        if let cached = localStore.cachedFood(forBarcode: barcode) {
            selectedFood = cached
            return
        }

        isLookingUpBarcode = true
        defer { isLookingUpBarcode = false }

        do {
            let food = try await OpenFoodFactsService().fetchProduct(barcode: barcode)
            localStore.cacheScannedFood(food, barcode: barcode)
            selectedFood = food
        } catch {
            barcodeErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct FoodRow: View {
    let food: FoodItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(food.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text([food.brand, food.servingDescription].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    HStack(spacing: 10) {
                        Text("🔥 \(Int(food.calories))")
                        Text("C \(Int(food.carbohydratesGrams))")
                        Text("F \(Int(food.fatGrams))")
                        Text("P \(Int(food.proteinGrams))")
                    }
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Lets the person scale a food's serving size before logging it — mirrors the reference app's
/// "adjust servings" step after picking a food from search.
private struct FoodQuantityView: View {
    let food: FoodItem
    let mealType: MealType
    let date: Date
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localStore: LocalStore
    @State private var servings: Double = 1

    private var scaledEntry: MealEntry {
        food.mealEntry(mealType: mealType, servings: servings, date: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(food.name).font(.headline)
                    if let brand = food.brand {
                        Text(brand).font(.footnote).foregroundStyle(.secondary)
                    }
                    Stepper(value: $servings, in: 0.25...10, step: 0.25) {
                        Text("Servings: \(servings.formatted(.number.precision(.fractionLength(0...2))))")
                    }
                }
                Section("This entry") {
                    LabeledContent("Calories", value: "\(Int(scaledEntry.calories)) kcal")
                    LabeledContent("Carbs", value: "\(Int(scaledEntry.carbohydratesGrams)) g")
                    LabeledContent("Fat", value: "\(Int(scaledEntry.fatGrams)) g")
                    LabeledContent("Protein", value: "\(Int(scaledEntry.proteinGrams)) g")
                }
            }
            .navigationTitle("Adjust & Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        localStore.add(meal: scaledEntry)
                        onSaved()
                    }
                }
            }
        }
    }
}

/// Fallback for foods not in the library — same fields as before, just reached through the
/// search sheet now instead of being the only way to log a meal.
private struct CustomFoodEditorView: View {
    let mealType: MealType
    let date: Date
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localStore: LocalStore
    @State private var name = ""
    @State private var selectedType: MealType
    @State private var calories = 0.0
    @State private var carbohydrates = 0.0
    @State private var fat = 0.0
    @State private var protein = 0.0

    init(mealType: MealType, date: Date, onSaved: @escaping () -> Void) {
        self.mealType = mealType
        self.date = date
        self.onSaved = onSaved
        _selectedType = State(initialValue: mealType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $selectedType) {
                        ForEach(MealType.allCases) { type in
                            Label(type.title, systemImage: type.systemImage).tag(type)
                        }
                    }
                    TextField("Calories", value: $calories, format: .number)
                        .keyboardType(.decimalPad)
                }
                Section("Macros (grams)") {
                    TextField("Carbohydrates", value: $carbohydrates, format: .number).keyboardType(.decimalPad)
                    TextField("Fat", value: $fat, format: .number).keyboardType(.decimalPad)
                    TextField("Protein", value: $protein, format: .number).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Custom Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        localStore.add(meal: MealEntry(
                            name: name,
                            mealType: selectedType,
                            calories: calories,
                            proteinGrams: protein,
                            carbohydratesGrams: carbohydrates,
                            fatGrams: fat,
                            date: date
                        ))
                        onSaved()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || calories <= 0)
                }
            }
        }
    }
}
