//
//  MealRecord.swift
//  Arovia
//

import Foundation
import SwiftData

@Model
final class MealRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var mealTypeRaw: String
    var calories: Double
    var proteinGrams: Double
    var carbohydratesGrams: Double
    var fatGrams: Double
    var date: Date
    var updatedAt: Date

    var cloudRecordName: String?
    var pendingSync: Bool

    init(
        id: UUID,
        name: String,
        mealTypeRaw: String,
        calories: Double,
        proteinGrams: Double,
        carbohydratesGrams: Double,
        fatGrams: Double,
        date: Date,
        updatedAt: Date,
        cloudRecordName: String? = nil,
        pendingSync: Bool = true
    ) {
        self.id = id
        self.name = name
        self.mealTypeRaw = mealTypeRaw
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydratesGrams = carbohydratesGrams
        self.fatGrams = fatGrams
        self.date = date
        self.updatedAt = updatedAt
        self.cloudRecordName = cloudRecordName
        self.pendingSync = pendingSync
    }
}

extension MealRecord {
    var asDomainModel: MealEntry {
        MealEntry(
            id: id,
            name: name,
            mealType: MealType(rawValue: mealTypeRaw) ?? .snack,
            calories: calories,
            proteinGrams: proteinGrams,
            carbohydratesGrams: carbohydratesGrams,
            fatGrams: fatGrams,
            date: date,
            updatedAt: updatedAt
        )
    }

    convenience init(_ meal: MealEntry) {
        self.init(
            id: meal.id,
            name: meal.name,
            mealTypeRaw: meal.mealType.rawValue,
            calories: meal.calories,
            proteinGrams: meal.proteinGrams,
            carbohydratesGrams: meal.carbohydratesGrams,
            fatGrams: meal.fatGrams,
            date: meal.date,
            updatedAt: meal.updatedAt
        )
    }
}
