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

    @State private var onlineResults: [FoodItem] = []
    @State private var isSearchingOnline = false
    @State private var onlineSearchError: String?
    /// Tracks which query the current online results belong to, so stale results from a previous
    /// search don't linger on screen after the person changes what they typed.
    @State private var lastOnlineSearchQuery: String?

    /// Single source of truth for "is there actually a search in progress" — using raw `query`
    /// directly for that meant a stray leading/trailing space (easy to end up with from
    /// autocorrect or a fat-fingered space bar) made the view think there was a query when
    /// there wasn't, hiding Suggestions/Recent and showing a confusing "no local matches" state.
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var results: [FoodItem] {
        trimmedQuery.isEmpty ? FoodLibrary.suggestions(for: mealType) : FoodLibrary.search(trimmedQuery)
    }

    /// Distinct foods the person has actually logged before, most recent first, with anything
    /// previously logged under this same meal type surfaced ahead of other meals' history —
    /// the most useful "suggestions" since they're specific to what this person eats and when.
    private var recentFoods: [FoodItem] {
        var seen = Set<String>()
        var sameMealType: [FoodItem] = []
        var otherMealType: [FoodItem] = []
        for meal in localStore.mealEntries where !seen.contains(meal.name.lowercased()) {
            seen.insert(meal.name.lowercased())
            let item = FoodItem(
                name: meal.name,
                servingDescription: "as logged",
                servingGrams: 0,
                calories: meal.calories,
                proteinGrams: meal.proteinGrams,
                carbohydratesGrams: meal.carbohydratesGrams,
                fatGrams: meal.fatGrams
            )
            if meal.mealType == mealType {
                sameMealType.append(item)
            } else {
                otherMealType.append(item)
            }
        }
        return Array((sameMealType + otherMealType).prefix(6))
    }

    var body: some View {
        NavigationStack {
            List {
                if isLookingUpBarcode {
                    Section {
                        PulseLoadingRow(text: "Looking up product…")
                    }
                }

                if !localStore.scannedFoods.isEmpty && trimmedQuery.isEmpty {
                    Section("Previously Scanned") {
                        ForEach(localStore.scannedFoods.prefix(5)) { food in
                            FoodRow(food: food) { selectedFood = food }
                        }
                    }
                }

                if trimmedQuery.isEmpty && !recentFoods.isEmpty {
                    Section("Recent") {
                        ForEach(recentFoods) { food in
                            FoodRow(food: food) { selectedFood = food }
                        }
                    }
                }

                Section(trimmedQuery.isEmpty ? "Suggestions" : "In Arovia's Library") {
                    if results.isEmpty {
                        Text(trimmedQuery.isEmpty ? "Start typing, scan a barcode, or search Open Food Facts online." : "No local matches for \"\(trimmedQuery)\".")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    } else {
                        ForEach(results) { food in
                            FoodRow(food: food) { selectedFood = food }
                        }
                    }
                }

                if !trimmedQuery.isEmpty {
                    onlineSearchSection
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
            .onSubmit(of: .search) {
                Task { await searchOnline() }
            }
            .onChange(of: query) {
                // Clear stale results once the (trimmed) text no longer matches what was
                // searched, rather than leaving a mismatched list on screen.
                if trimmedQuery != lastOnlineSearchQuery {
                    onlineResults = []
                    onlineSearchError = nil
                }
            }
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

    /// Shown once the person has typed something — lets them reach past Arovia's small local
    /// library into Open Food Facts' full database when a barcode isn't available or wasn't found.
    private var onlineSearchSection: some View {
        Section("Open Food Facts") {
            if isSearchingOnline {
                PulseLoadingRow(text: "Searching Open Food Facts…")
            } else if let onlineSearchError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(onlineSearchError)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                    Button("Try Again") {
                        Task { await searchOnline() }
                    }
                    .font(.footnote.weight(.semibold))
                }
            } else if lastOnlineSearchQuery == trimmedQuery && !onlineResults.isEmpty {
                ForEach(onlineResults) { food in
                    FoodRow(food: food) { selectedFood = food }
                }
            } else {
                Button {
                    Task { await searchOnline() }
                } label: {
                    Label("Search Open Food Facts for \"\(trimmedQuery)\"", systemImage: "magnifyingglass")
                }
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

    /// Free-text search against Open Food Facts for when there's no barcode to scan, or the
    /// barcode wasn't found. Results with a barcode are cached the same way scanned items are.
    private func searchOnline() async {
        let trimmed = trimmedQuery
        guard !trimmed.isEmpty else { return }

        isSearchingOnline = true
        onlineSearchError = nil
        defer { isSearchingOnline = false }

        do {
            let foods = try await OpenFoodFactsService().searchProducts(query: trimmed)
            for item in foods {
                if case let .barcode(code) = item.source {
                    localStore.cacheScannedFood(item, barcode: code)
                }
            }
            onlineResults = foods
            lastOnlineSearchQuery = trimmed
            if foods.isEmpty {
                onlineSearchError = "No Open Food Facts results for \"\(trimmed)\". Try a shorter or more general term."
            }
        } catch {
            onlineSearchError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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
                        Haptic.success()
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
