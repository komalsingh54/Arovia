//
//  FoodLibrary.swift
//  Arovia
//
//  A small, curated local database so food search works instantly offline. Deliberately not
//  exhaustive — the barcode scanner (Open Food Facts) covers packaged/branded items this can't.
//

import Foundation

enum FoodLibrary {
    static let items: [FoodItem] = [
        // Proteins
        FoodItem(name: "Chicken Breast (Grilled, Skinless)", servingDescription: "1 cup, diced (135g)", servingGrams: 135, calories: 238, proteinGrams: 40, carbohydratesGrams: 0, fatGrams: 7),
        FoodItem(name: "Chicken Thigh (Skinless)", servingDescription: "1 cup, diced (135g)", servingGrams: 135, calories: 261, proteinGrams: 33, carbohydratesGrams: 0, fatGrams: 14),
        FoodItem(name: "Chicken Curry (Home-style)", servingDescription: "1 cup (240g)", servingGrams: 240, calories: 257, proteinGrams: 16, carbohydratesGrams: 16, fatGrams: 16),
        FoodItem(name: "Paneer (Raw)", servingDescription: "100g", servingGrams: 100, calories: 265, proteinGrams: 18, carbohydratesGrams: 3.6, fatGrams: 20.8),
        FoodItem(name: "Eggs (Whole, Boiled)", servingDescription: "2 large (100g)", servingGrams: 100, calories: 155, proteinGrams: 13, carbohydratesGrams: 1.1, fatGrams: 11),
        FoodItem(name: "Salmon (Grilled)", servingDescription: "1 fillet (150g)", servingGrams: 150, calories: 280, proteinGrams: 39, carbohydratesGrams: 0, fatGrams: 13),
        FoodItem(name: "Greek Yoghurt (Plain)", servingDescription: "170g pot", servingGrams: 170, calories: 100, proteinGrams: 17, carbohydratesGrams: 6, fatGrams: 0.7),
        FoodItem(name: "Tofu (Firm)", servingDescription: "100g", servingGrams: 100, calories: 144, proteinGrams: 15, carbohydratesGrams: 3, fatGrams: 8),

        // Grains, breads & staples
        FoodItem(name: "Bread (Chappati or Roti)", servingDescription: "2 medium (7\", 80g)", servingGrams: 80, calories: 239, proteinGrams: 6, carbohydratesGrams: 37, fatGrams: 7),
        FoodItem(name: "Basmati Rice (Cooked)", servingDescription: "1 cup (158g)", servingGrams: 158, calories: 205, proteinGrams: 4.3, carbohydratesGrams: 45, fatGrams: 0.4),
        FoodItem(name: "Dal (Lentil Curry)", servingDescription: "1 cup (200g)", servingGrams: 200, calories: 230, proteinGrams: 12, carbohydratesGrams: 32, fatGrams: 6),
        FoodItem(name: "Oats (Rolled, Dry)", servingDescription: "1/2 cup (40g)", servingGrams: 40, calories: 150, proteinGrams: 5, carbohydratesGrams: 27, fatGrams: 3),
        FoodItem(name: "Wholemeal Bread", servingDescription: "1 slice (36g)", servingGrams: 36, calories: 82, proteinGrams: 4, carbohydratesGrams: 14, fatGrams: 1.1),
        FoodItem(name: "Pasta (Cooked)", servingDescription: "1 cup (140g)", servingGrams: 140, calories: 221, proteinGrams: 8, carbohydratesGrams: 43, fatGrams: 1.3),
        FoodItem(name: "Naan Bread", servingDescription: "1 piece (90g)", servingGrams: 90, calories: 262, proteinGrams: 9, carbohydratesGrams: 45, fatGrams: 5),
        FoodItem(name: "Quinoa (Cooked)", servingDescription: "1 cup (185g)", servingGrams: 185, calories: 222, proteinGrams: 8, carbohydratesGrams: 39, fatGrams: 3.6),

        // Fruit & veg
        FoodItem(name: "Apple", servingDescription: "1 small (165g)", servingGrams: 165, calories: 101, proteinGrams: 0.3, carbohydratesGrams: 24, fatGrams: 0.2),
        FoodItem(name: "Banana", servingDescription: "1 medium (118g)", servingGrams: 118, calories: 105, proteinGrams: 1.3, carbohydratesGrams: 27, fatGrams: 0.4),
        FoodItem(name: "Mixed Salad Greens", servingDescription: "1 cup (85g)", servingGrams: 85, calories: 14, proteinGrams: 1.2, carbohydratesGrams: 2.7, fatGrams: 0.2),
        FoodItem(name: "Avocado", servingDescription: "1/2 fruit (100g)", servingGrams: 100, calories: 160, proteinGrams: 2, carbohydratesGrams: 9, fatGrams: 15),
        FoodItem(name: "Broccoli (Steamed)", servingDescription: "1 cup (156g)", servingGrams: 156, calories: 55, proteinGrams: 3.7, carbohydratesGrams: 11, fatGrams: 0.6),

        // Snacks & drinks
        FoodItem(name: "Soft Bakes Red Berries", brand: "Belvita", servingDescription: "1 serving (50g)", servingGrams: 50, calories: 193, proteinGrams: 3, carbohydratesGrams: 31, fatGrams: 6),
        FoodItem(name: "Almonds (Raw)", servingDescription: "1 oz, ~23 nuts (28g)", servingGrams: 28, calories: 164, proteinGrams: 6, carbohydratesGrams: 6, fatGrams: 14),
        FoodItem(name: "Cookie (Chocolate Oatmeal, No Bake)", servingDescription: "1 bite-size (5g)", servingGrams: 5, calories: 22, proteinGrams: 0.3, carbohydratesGrams: 3, fatGrams: 0.9),
        FoodItem(name: "Tea (Hot, Herbal)", servingDescription: "1 cup (240g)", servingGrams: 240, calories: 2, proteinGrams: 0, carbohydratesGrams: 0.5, fatGrams: 0),
        FoodItem(name: "Japanese Matcha Ginger Tea Sachet", servingDescription: "1 sachet (2g)", servingGrams: 2, calories: 5, proteinGrams: 0, carbohydratesGrams: 1, fatGrams: 0),
        FoodItem(name: "Coffee (Black)", servingDescription: "1 cup (240g)", servingGrams: 240, calories: 2, proteinGrams: 0.3, carbohydratesGrams: 0, fatGrams: 0),
        FoodItem(name: "Vodka and Soda", servingDescription: "1 fl oz (30g)", servingGrams: 30, calories: 18, proteinGrams: 0, carbohydratesGrams: 0, fatGrams: 0),

        // Dairy & fats
        FoodItem(name: "Milk (Semi-Skimmed)", servingDescription: "1 cup (240ml)", servingGrams: 240, calories: 122, proteinGrams: 8, carbohydratesGrams: 12, fatGrams: 4.8),
        FoodItem(name: "Olive Oil", servingDescription: "1 tbsp (14g)", servingGrams: 14, calories: 119, proteinGrams: 0, carbohydratesGrams: 0, fatGrams: 14),
        FoodItem(name: "Peanut Butter", servingDescription: "2 tbsp (32g)", servingGrams: 32, calories: 188, proteinGrams: 8, carbohydratesGrams: 6, fatGrams: 16),
    ]

    static func search(_ query: String) -> [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) || ($0.brand?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    /// A handful of common items to show before the person types anything.
    static var suggestions: [FoodItem] {
        Array(items.prefix(6))
    }
}
