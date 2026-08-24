//
//  WaterRepository.swift
//  Arovia
//

import Foundation
import SwiftData

protocol WaterRepository: Sendable {
    @MainActor func fetchAll() throws -> [WaterEntry]
    @MainActor func insert(_ entry: WaterEntry) throws
    @MainActor func delete(id: UUID) throws
}

@MainActor
final class SwiftDataWaterRepository: WaterRepository, @unchecked Sendable {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [WaterEntry] {
        let descriptor = FetchDescriptor<WaterRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try context.fetch(descriptor).map(\.asDomainModel)
    }

    func insert(_ entry: WaterEntry) throws {
        context.insert(WaterRecord(entry))
        try context.save()
    }

    func delete(id: UUID) throws {
        var descriptor = FetchDescriptor<WaterRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let record = try context.fetch(descriptor).first else { return }
        context.delete(record)
        try context.save()
    }
}
