//
//  AppDependencies.swift
//  Arovia
//
//  Single composition root. Views never construct repositories/services themselves —
//  everything is built once here and handed down via `LocalStore`/`HealthStore`.
//

import Foundation
import SwiftData

enum FeatureFlags {
    /// Flip off to run fully local-only (e.g. for previews, tests, or if CloudKit isn't configured
    /// for this bundle ID yet). Sync itself also self-disables if the account isn't signed in.
    static let cloudKitEnabled = true
}

@MainActor
final class AppDependencies {
    let modelContainer: ModelContainer
    let goalsRepository: GoalsRepository
    let journalRepository: JournalRepository
    let mealsRepository: MealsRepository
    let cloudKitSyncService: CloudKitSyncing

    init() {
        let schema = Schema([GoalRecord.self, JournalRecord.self, MealRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Fall back to an in-memory store rather than crashing the app if the on-disk store
            // can't be opened (e.g. corrupted after a failed migration).
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            modelContainer = (try? ModelContainer(for: schema, configurations: [fallback]))
                ?? { fatalError("Unable to create SwiftData ModelContainer: \(error)") }()
        }

        let context = ModelContext(modelContainer)
        goalsRepository = SwiftDataGoalsRepository(context: context)
        journalRepository = SwiftDataJournalRepository(context: context)
        mealsRepository = SwiftDataMealsRepository(context: context)

        if FeatureFlags.cloudKitEnabled {
            cloudKitSyncService = CloudKitSyncService(
                goalsRepository: goalsRepository,
                journalRepository: journalRepository,
                mealsRepository: mealsRepository
            )
        } else {
            cloudKitSyncService = NoopCloudKitSyncService()
        }
    }

    /// Test/preview-friendly initializer using an in-memory store and no CloudKit sync.
    static func preview() -> AppDependencies {
        AppDependencies()
    }
}

struct NoopCloudKitSyncService: CloudKitSyncing {
    func syncAll() async {}
}
