//
//  MealEntry.swift
//  Arovia
//

import Foundation

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "takeoutbag.and.cup.and.straw.fill"
        }
    }
}

struct MealEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let mealType: MealType
    let calories: Double
    let proteinGrams: Double
    let carbohydratesGrams: Double
    let fatGrams: Double
    let date: Date

    init(
        name: String,
        mealType: MealType,
        calories: Double,
        proteinGrams: Double = 0,
        carbohydratesGrams: Double = 0,
        fatGrams: Double = 0,
        date: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.mealType = mealType
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydratesGrams = carbohydratesGrams
        self.fatGrams = fatGrams
        self.date = date
    }
}
