//
//  MealsRepository.swift
//  Arovia
//

import Foundation
import SwiftData

protocol MealsRepository: Sendable {
    @MainActor func fetchAll() throws -> [MealEntry]
    @MainActor func insert(_ meal: MealEntry) throws
    @MainActor func delete(id: UUID) throws
    @MainActor func fetchPendingSync() throws -> [MealEntry]
    @MainActor func markSynced(id: UUID, cloudRecordName: String) throws
}

@MainActor
final class SwiftDataMealsRepository: MealsRepository, @unchecked Sendable {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [MealEntry] {
        let descriptor = FetchDescriptor<MealRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try context.fetch(descriptor).map(\.asDomainModel)
    }

    func insert(_ meal: MealEntry) throws {
        context.insert(MealRecord(meal))
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let record = try record(for: id) else { return }
        context.delete(record)
        try context.save()
    }

    func fetchPendingSync() throws -> [MealEntry] {
        let predicate = #Predicate<MealRecord> { $0.pendingSync }
        return try context.fetch(FetchDescriptor(predicate: predicate)).map(\.asDomainModel)
    }

    func markSynced(id: UUID, cloudRecordName: String) throws {
        guard let record = try record(for: id) else { return }
        record.pendingSync = false
        record.cloudRecordName = cloudRecordName
        try context.save()
    }

    private func record(for id: UUID) throws -> MealRecord? {
        var descriptor = FetchDescriptor<MealRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
