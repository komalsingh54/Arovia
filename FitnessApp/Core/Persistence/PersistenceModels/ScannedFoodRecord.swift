//
//  ScannedFoodRecord.swift
//  Arovia
//
//  Local cache of barcode → product lookups from Open Food Facts. Keeps repeat scans (and the
//  "Recent" list) instant and working offline once a barcode has been looked up once.
//

import Foundation
import SwiftData

@Model
final class ScannedFoodRecord {
    @Attribute(.unique) var barcode: String
    var name: String
    var brand: String?
    var servingDescription: String
    var servingGrams: Double
    var calories: Double
    var proteinGrams: Double
    var carbohydratesGrams: Double
    var fatGrams: Double
    var cachedAt: Date

    init(
        barcode: String,
        name: String,
        brand: String?,
        servingDescription: String,
        servingGrams: Double,
        calories: Double,
        proteinGrams: Double,
        carbohydratesGrams: Double,
        fatGrams: Double,
        cachedAt: Date = .now
    ) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.servingDescription = servingDescription
        self.servingGrams = servingGrams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydratesGrams = carbohydratesGrams
        self.fatGrams = fatGrams
        self.cachedAt = cachedAt
    }
}

extension ScannedFoodRecord {
    var asFoodItem: FoodItem {
        FoodItem(
            id: "barcode-\(barcode)",
            name: name,
            brand: brand,
            servingDescription: servingDescription,
            servingGrams: servingGrams,
            calories: calories,
            proteinGrams: proteinGrams,
            carbohydratesGrams: carbohydratesGrams,
            fatGrams: fatGrams,
            source: .barcode(code: barcode)
        )
    }

    convenience init(food: FoodItem, barcode: String) {
        self.init(
            barcode: barcode,
            name: food.name,
            brand: food.brand,
            servingDescription: food.servingDescription,
            servingGrams: food.servingGrams,
            calories: food.calories,
            proteinGrams: food.proteinGrams,
            carbohydratesGrams: food.carbohydratesGrams,
            fatGrams: food.fatGrams
        )
    }
}
