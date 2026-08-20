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
    /// CloudKit requires a paid Apple Developer Program membership — personal/free Apple IDs
    /// can't add the iCloud capability at all. Defaults to off so the app builds and runs fully
    /// local-only. Flip to `true` once you're enrolled and have re-added the iCloud + CloudKit
    /// capability in Signing & Capabilities (and restored the entitlement — see Arovia.entitlements.disabled).
    static let cloudKitEnabled = false
}

@MainActor
final class AppDependencies {
    let modelContainer: ModelContainer
    let goalsRepository: GoalsRepository
    let journalRepository: JournalRepository
    let mealsRepository: MealsRepository
    let scannedFoodRepository: ScannedFoodRepository
    let waterRepository: WaterRepository
    let cloudKitSyncService: CloudKitSyncing

    init() {
        let schema = Schema([GoalRecord.self, JournalRecord.self, MealRecord.self, ScannedFoodRecord.self, WaterRecord.self])
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
        scannedFoodRepository = SwiftDataScannedFoodRepository(context: context)
        waterRepository = SwiftDataWaterRepository(context: context)

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
