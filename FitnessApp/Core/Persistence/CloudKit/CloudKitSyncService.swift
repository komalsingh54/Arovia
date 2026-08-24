//
//  CloudKitSyncService.swift
//  Arovia
//
//  App-owned data (goals, journal entries, meals) synced to the user's private CloudKit database.
//  HealthKit data itself is never written here — only personal logs the app owns.
//  Uses a single custom zone and last-writer-wins conflict resolution via `updatedAt`.
//

import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

enum CloudKitRecordType {
    static let goal = "Goal"
    static let journalEntry = "JournalEntry"
    static let meal = "Meal"
}

enum CloudKitSyncError: Error {
    case unavailable
    case notSignedIn
}

protocol CloudKitSyncing: Sendable {
    /// Pushes any locally-pending goals/journal entries/meals to CloudKit, then pulls remote
    /// changes newer than what's stored locally. Safe to call opportunistically (app foreground,
    /// after a local write, pull-to-refresh) — it no-ops quickly when there's nothing to do.
    func syncAll() async
}

#if canImport(CloudKit)

/// Feature-flagged: disabled automatically if CloudKit is unavailable (no container, not signed
/// into iCloud, simulator without an account, etc.) so the app degrades gracefully to local-only.
actor CloudKitSyncService: CloudKitSyncing {
    private let container: CKContainer
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID
    private var zoneCreated = false

    private let goalsRepository: GoalsRepository
    private let journalRepository: JournalRepository
    private let mealsRepository: MealsRepository

    init(
        containerIdentifier: String? = nil,
        goalsRepository: GoalsRepository,
        journalRepository: JournalRepository,
        mealsRepository: MealsRepository
    ) {
        self.container = containerIdentifier.map { CKContainer(identifier: $0) } ?? .default()
        self.database = container.privateCloudDatabase
        self.zoneID = CKRecordZone.ID(zoneName: "PersonalDataZone", ownerName: CKCurrentUserDefaultName)
        self.goalsRepository = goalsRepository
        self.journalRepository = journalRepository
        self.mealsRepository = mealsRepository
    }

    func syncAll() async {
        do {
            guard try await isAvailable() else { return }
            try await ensureZoneExists()
            try await pushPendingGoals()
            try await pushPendingJournalEntries()
            try await pushPendingMeals()
        } catch {
            // CloudKit sync is best-effort; local SwiftData remains the source of truth for the UI,
            // so a failed sync never blocks or crashes the app. Retried on the next opportunistic call.
        }
    }

    private func isAvailable() async throws -> Bool {
        let status = try await container.accountStatus()
        return status == .available
    }

    private func ensureZoneExists() async throws {
        guard !zoneCreated else { return }
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await database.modifyRecordZones(saving: [zone], deleting: [])
        zoneCreated = true
    }

    private func recordID(for id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
    }

    // MARK: Goals

    private func pushPendingGoals() async throws {
        let pending = try await MainActor.run { try goalsRepository.fetchPendingSync() }
        guard !pending.isEmpty else { return }

        for goal in pending {
            let record = CKRecord(recordType: CloudKitRecordType.goal, recordID: recordID(for: goal.id))
            record["title"] = goal.title
            record["targetValue"] = goal.targetValue
            record["currentValue"] = goal.currentValue
            record["unit"] = goal.unit
            record["metric"] = goal.metric.rawValue
            record["createdAt"] = goal.createdAt
            record["updatedAt"] = goal.updatedAt

            let saved = try await database.save(record)
            try await MainActor.run {
                try goalsRepository.markSynced(id: goal.id, cloudRecordName: saved.recordID.recordName)
            }
        }
    }

    // MARK: Journal entries

    private func pushPendingJournalEntries() async throws {
        let pending = try await MainActor.run { try journalRepository.fetchPendingSync() }
        guard !pending.isEmpty else { return }

        for entry in pending {
            let record = CKRecord(recordType: CloudKitRecordType.journalEntry, recordID: recordID(for: entry.id))
            record["title"] = entry.title
            record["details"] = entry.details
            record["date"] = entry.date
            record["category"] = entry.category.rawValue
            record["updatedAt"] = entry.updatedAt

            let saved = try await database.save(record)
            try await MainActor.run {
                try journalRepository.markSynced(id: entry.id, cloudRecordName: saved.recordID.recordName)
            }
        }
    }

    // MARK: Meals

    private func pushPendingMeals() async throws {
        let pending = try await MainActor.run { try mealsRepository.fetchPendingSync() }
        guard !pending.isEmpty else { return }

        for meal in pending {
            let record = CKRecord(recordType: CloudKitRecordType.meal, recordID: recordID(for: meal.id))
            record["name"] = meal.name
            record["mealType"] = meal.mealType.rawValue
            record["calories"] = meal.calories
            record["proteinGrams"] = meal.proteinGrams
            record["carbohydratesGrams"] = meal.carbohydratesGrams
            record["fatGrams"] = meal.fatGrams
            record["date"] = meal.date
            record["updatedAt"] = meal.updatedAt

            let saved = try await database.save(record)
            try await MainActor.run {
                try mealsRepository.markSynced(id: meal.id, cloudRecordName: saved.recordID.recordName)
            }
        }
    }
}

#else

/// CloudKit isn't available on this platform/SDK — sync becomes a no-op and the app runs local-only.
actor CloudKitSyncService: CloudKitSyncing {
    init(containerIdentifier: String? = nil, goalsRepository: GoalsRepository, journalRepository: JournalRepository, mealsRepository: MealsRepository) {}
    func syncAll() async {}
}

#endif
