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

    /// A reasonable share of the daily calorie target for this meal type, used for per-meal-type insight targets.
    var typicalCalorieShare: Double {
        switch self {
        case .breakfast: 0.25
        case .lunch: 0.30
        case .dinner: 0.30
        case .snack: 0.15
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
    let updatedAt: Date

    init(
        name: String,
        mealType: MealType,
        calories: Double,
        proteinGrams: Double = 0,
        carbohydratesGrams: Double = 0,
        fatGrams: Double = 0,
        date: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.mealType = mealType
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydratesGrams = carbohydratesGrams
        self.fatGrams = fatGrams
        self.date = date
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, mealType, calories, proteinGrams, carbohydratesGrams, fatGrams, date, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        mealType = try container.decode(MealType.self, forKey: .mealType)
        calories = try container.decode(Double.self, forKey: .calories)
        proteinGrams = try container.decodeIfPresent(Double.self, forKey: .proteinGrams) ?? 0
        carbohydratesGrams = try container.decodeIfPresent(Double.self, forKey: .carbohydratesGrams) ?? 0
        fatGrams = try container.decodeIfPresent(Double.self, forKey: .fatGrams) ?? 0
        date = try container.decode(Date.self, forKey: .date)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? date
    }

    init(id: UUID, name: String, mealType: MealType, calories: Double, proteinGrams: Double, carbohydratesGrams: Double, fatGrams: Double, date: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.mealType = mealType
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydratesGrams = carbohydratesGrams
        self.fatGrams = fatGrams
        self.date = date
        self.updatedAt = updatedAt
    }
}
