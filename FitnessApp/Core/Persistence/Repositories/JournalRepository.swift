//
//  JournalRepository.swift
//  Arovia
//

import Foundation
import SwiftData

protocol JournalRepository: Sendable {
    @MainActor func fetchAll() throws -> [JournalEntry]
    @MainActor func insert(_ entry: JournalEntry) throws
    @MainActor func update(_ entry: JournalEntry) throws
    @MainActor func delete(id: UUID) throws
    @MainActor func fetchPendingSync() throws -> [JournalEntry]
    @MainActor func markSynced(id: UUID, cloudRecordName: String) throws
}

@MainActor
final class SwiftDataJournalRepository: JournalRepository, @unchecked Sendable {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [JournalEntry] {
        let descriptor = FetchDescriptor<JournalRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try context.fetch(descriptor).map(\.asDomainModel)
    }

    func insert(_ entry: JournalEntry) throws {
        context.insert(JournalRecord(entry))
        try context.save()
    }

    func update(_ entry: JournalEntry) throws {
        guard let record = try record(for: entry.id) else {
            try insert(entry)
            return
        }
        record.apply(entry)
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let record = try record(for: id) else { return }
        context.delete(record)
        try context.save()
    }

    func fetchPendingSync() throws -> [JournalEntry] {
        let predicate = #Predicate<JournalRecord> { $0.pendingSync }
        return try context.fetch(FetchDescriptor(predicate: predicate)).map(\.asDomainModel)
    }

    func markSynced(id: UUID, cloudRecordName: String) throws {
        guard let record = try record(for: id) else { return }
        record.pendingSync = false
        record.cloudRecordName = cloudRecordName
        try context.save()
    }

    private func record(for id: UUID) throws -> JournalRecord? {
        var descriptor = FetchDescriptor<JournalRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
