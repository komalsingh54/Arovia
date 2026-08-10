//
//  FoodItem.swift
//  Arovia
//
//  A single food/drink someone can search for and log — distinct from `MealEntry`, which is the
//  logged record. Search once, then log an adjustable quantity of it as a MealEntry.
//

import Foundation

struct FoodItem: Identifiable, Equatable, Hashable {
    enum Source: Equatable, Hashable {
        case local
        case barcode(code: String)
    }

    let id: String
    let name: String
    let brand: String?
    let servingDescription: String
    let servingGrams: Double
    let calories: Double
    let proteinGrams: Double
    let carbohydratesGrams: Double
    let fatGrams: Double
    let source: Source

    init(
        id: String = UUID().uuidString,
        name: String,
        brand: String? = nil,
        servingDescription: String,
        servingGrams: Double,
        calories: Double,
        proteinGrams: Double,
        carbohydratesGrams: Double,
        fatGrams: Double,
        source: Source = .local
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.servingDescription = servingDescription
        self.servingGrams = servingGrams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydratesGrams = carbohydratesGrams
        self.fatGrams = fatGrams
        self.source = source
    }

    /// Scales this food's nutrition by a serving multiplier (e.g. 1.5 servings) into a loggable meal.
    func mealEntry(mealType: MealType, servings: Double, date: Date = .now) -> MealEntry {
        MealEntry(
            name: brand.map { "\(name) (\($0))" } ?? name,
            mealType: mealType,
            calories: calories * servings,
            proteinGrams: proteinGrams * servings,
            carbohydratesGrams: carbohydratesGrams * servings,
            fatGrams: fatGrams * servings,
            date: date
        )
    }
}
