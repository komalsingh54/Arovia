//
//  LocalStore.swift
//  Arovia
//
//  Thin, UI-facing facade over the repository layer. Views bind to the @Published arrays here;
//  all persistence detail (SwiftData) and cloud sync (CloudKit) is delegated to the repositories
//  and `CloudKitSyncing`, keeping the "UI never talks directly to CloudKit" rule from agents.md.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class LocalStore: ObservableObject {
    @Published private(set) var goals: [FitnessGoal] = []
    @Published private(set) var journalEntries: [JournalEntry] = []
    @Published private(set) var mealEntries: [MealEntry] = []
    @Published private(set) var scannedFoods: [FoodItem] = []

    private let goalsRepository: GoalsRepository
    private let journalRepository: JournalRepository
    private let mealsRepository: MealsRepository
    private let scannedFoodRepository: ScannedFoodRepository
    private let cloudKitSyncService: CloudKitSyncing

    init(dependencies: AppDependencies) {
        self.goalsRepository = dependencies.goalsRepository
        self.journalRepository = dependencies.journalRepository
        self.mealsRepository = dependencies.mealsRepository
        self.scannedFoodRepository = dependencies.scannedFoodRepository
        self.cloudKitSyncService = dependencies.cloudKitSyncService
        reloadAll()
        Task { await syncWithCloud() }
    }

    /// Preview/test-friendly initializer that skips CloudKit entirely.
    init(
        goalsRepository: GoalsRepository,
        journalRepository: JournalRepository,
        mealsRepository: MealsRepository,
        scannedFoodRepository: ScannedFoodRepository
    ) {
        self.goalsRepository = goalsRepository
        self.journalRepository = journalRepository
        self.mealsRepository = mealsRepository
        self.scannedFoodRepository = scannedFoodRepository
        self.cloudKitSyncService = NoopCloudKitSyncService()
        reloadAll()
    }

    // MARK: Goals

    func add(goal: FitnessGoal) {
        do {
            try goalsRepository.insert(goal)
            goals.append(goal)
            Task { await syncWithCloud() }
        } catch {
            reloadAll()
        }
    }

    func deleteGoals(at offsets: IndexSet) {
        let removed = offsets.map { goals[$0] }
        goals.remove(atOffsets: offsets)
        for goal in removed {
            try? goalsRepository.delete(id: goal.id)
        }
    }

    func update(goal: FitnessGoal) {
        guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        do {
            try goalsRepository.update(goal)
            goals[index] = goal
            Task { await syncWithCloud() }
        } catch {
            reloadAll()
        }
    }

    // MARK: Journal

    func add(entry: JournalEntry) {
        do {
            try journalRepository.insert(entry)
            journalEntries.append(entry)
            journalEntries.sort { $0.date > $1.date }
            Task { await syncWithCloud() }
        } catch {
            reloadAll()
        }
    }

    func deleteJournalEntries(at offsets: IndexSet) {
        let removed = offsets.map { journalEntries[$0] }
        journalEntries.remove(atOffsets: offsets)
        for entry in removed {
            try? journalRepository.delete(id: entry.id)
        }
    }

    func update(entry: JournalEntry) {
        guard let index = journalEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        do {
            try journalRepository.update(entry)
            journalEntries[index] = entry
            Task { await syncWithCloud() }
        } catch {
            reloadAll()
        }
    }

    // MARK: Meals

    func add(meal: MealEntry) {
        do {
            try mealsRepository.insert(meal)
            mealEntries.append(meal)
            mealEntries.sort { $0.date > $1.date }
            Task { await syncWithCloud() }
        } catch {
            reloadAll()
        }
    }

    func deleteMealEntries(at offsets: IndexSet) {
        let removed = offsets.map { mealEntries[$0] }
        mealEntries.remove(atOffsets: offsets)
        for meal in removed {
            try? mealsRepository.delete(id: meal.id)
        }
    }

    // MARK: Scanned foods (barcode cache)

    /// Checks the local cache first — avoids a network call for barcodes already looked up.
    func cachedFood(forBarcode barcode: String) -> FoodItem? {
        (try? scannedFoodRepository.lookup(barcode: barcode)) ?? nil
    }

    func cacheScannedFood(_ food: FoodItem, barcode: String) {
        do {
            try scannedFoodRepository.save(food, barcode: barcode)
            scannedFoods.removeAll { $0.id == food.id }
            scannedFoods.insert(food, at: 0)
        } catch {
            // Cache is best-effort — the food can still be logged even if caching fails.
        }
    }

    // MARK: Sync

    /// Called after every local mutation and can also be triggered from pull-to-refresh.
    func syncWithCloud() async {
        await cloudKitSyncService.syncAll()
    }

    private func reloadAll() {
        goals = (try? goalsRepository.fetchAll()) ?? []
        journalEntries = ((try? journalRepository.fetchAll()) ?? []).sorted { $0.date > $1.date }
        mealEntries = ((try? mealsRepository.fetchAll()) ?? []).sorted { $0.date > $1.date }
        scannedFoods = (try? scannedFoodRepository.fetchAll()) ?? []
    }
}
