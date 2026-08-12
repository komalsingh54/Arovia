//
//  ScannedFoodRepository.swift
//  Arovia
//

import Foundation
import SwiftData

protocol ScannedFoodRepository: Sendable {
    @MainActor func lookup(barcode: String) throws -> FoodItem?
    @MainActor func save(_ food: FoodItem, barcode: String) throws
    @MainActor func fetchAll() throws -> [FoodItem]
}

@MainActor
final class SwiftDataScannedFoodRepository: ScannedFoodRepository, @unchecked Sendable {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func lookup(barcode: String) throws -> FoodItem? {
        try record(for: barcode)?.asFoodItem
    }

    func save(_ food: FoodItem, barcode: String) throws {
        if let existing = try record(for: barcode) {
            context.delete(existing)
        }
        context.insert(ScannedFoodRecord(food: food, barcode: barcode))
        try context.save()
    }

    func fetchAll() throws -> [FoodItem] {
        let descriptor = FetchDescriptor<ScannedFoodRecord>(sortBy: [SortDescriptor(\.cachedAt, order: .reverse)])
        return try context.fetch(descriptor).map(\.asFoodItem)
    }

    private func record(for barcode: String) throws -> ScannedFoodRecord? {
        var descriptor = FetchDescriptor<ScannedFoodRecord>(predicate: #Predicate { $0.barcode == barcode })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
