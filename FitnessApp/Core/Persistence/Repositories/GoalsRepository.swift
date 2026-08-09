//
//  GoalsRepository.swift
//  Arovia
//
//  Mediates between domain models and the SwiftData local cache. Views/ViewModels never touch
//  SwiftData or CloudKit directly — only this protocol.
//

import Foundation
import SwiftData

protocol GoalsRepository: Sendable {
    @MainActor func fetchAll() throws -> [FitnessGoal]
    @MainActor func insert(_ goal: FitnessGoal) throws
    @MainActor func update(_ goal: FitnessGoal) throws
    @MainActor func delete(id: UUID) throws
    /// Records still awaiting a confirmed CloudKit sync, used by `CloudKitSyncService`.
    @MainActor func fetchPendingSync() throws -> [FitnessGoal]
    @MainActor func markSynced(id: UUID, cloudRecordName: String) throws
}

@MainActor
final class SwiftDataGoalsRepository: GoalsRepository, @unchecked Sendable {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [FitnessGoal] {
        let descriptor = FetchDescriptor<GoalRecord>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        return try context.fetch(descriptor).map(\.asDomainModel)
    }

    func insert(_ goal: FitnessGoal) throws {
        context.insert(GoalRecord(goal))
        try context.save()
    }

    func update(_ goal: FitnessGoal) throws {
        guard let record = try record(for: goal.id) else {
            try insert(goal)
            return
        }
        record.apply(goal)
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let record = try record(for: id) else { return }
        context.delete(record)
        try context.save()
    }

    func fetchPendingSync() throws -> [FitnessGoal] {
        let predicate = #Predicate<GoalRecord> { $0.pendingSync }
        return try context.fetch(FetchDescriptor(predicate: predicate)).map(\.asDomainModel)
    }

    func markSynced(id: UUID, cloudRecordName: String) throws {
        guard let record = try record(for: id) else { return }
        record.pendingSync = false
        record.cloudRecordName = cloudRecordName
        try context.save()
    }

    private func record(for id: UUID) throws -> GoalRecord? {
        var descriptor = FetchDescriptor<GoalRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
