//
//  LocalStore.swift
//  Arovia
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class LocalStore: ObservableObject {
    @Published private(set) var goals: [FitnessGoal]
    @Published private(set) var journalEntries: [JournalEntry]
    @Published private(set) var mealEntries: [MealEntry]

    private let defaults: UserDefaults
    private let goalsKey = "fitnessGoals"
    private let journalEntriesKey = "journalEntries"
    private let mealEntriesKey = "mealEntries"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.goals = Self.decode([FitnessGoal].self, forKey: "fitnessGoals", defaults: defaults)
        self.journalEntries = Self.decode([JournalEntry].self, forKey: "journalEntries", defaults: defaults)
        self.mealEntries = Self.decode([MealEntry].self, forKey: "mealEntries", defaults: defaults)
    }

    func add(goal: FitnessGoal) {
        goals.append(goal)
        persist(goals, forKey: goalsKey)
    }

    func deleteGoals(at offsets: IndexSet) {
        goals.remove(atOffsets: offsets)
        persist(goals, forKey: goalsKey)
    }

    func update(goal: FitnessGoal) {
        guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[index] = goal
        persist(goals, forKey: goalsKey)
    }

    func add(entry: JournalEntry) {
        journalEntries.append(entry)
        journalEntries.sort { $0.date > $1.date }
        persist(journalEntries, forKey: journalEntriesKey)
    }

    func deleteJournalEntries(at offsets: IndexSet) {
        journalEntries.remove(atOffsets: offsets)
        persist(journalEntries, forKey: journalEntriesKey)
    }

    func update(entry: JournalEntry) {
        guard let index = journalEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        journalEntries[index] = entry
        persist(journalEntries, forKey: journalEntriesKey)
    }

    func add(meal: MealEntry) {
        mealEntries.append(meal)
        mealEntries.sort { $0.date > $1.date }
        persist(mealEntries, forKey: mealEntriesKey)
    }

    func deleteMealEntries(at offsets: IndexSet) {
        mealEntries.remove(atOffsets: offsets)
        persist(mealEntries, forKey: mealEntriesKey)
    }

    private func persist<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<Element: Decodable>(_ type: [Element].Type, forKey key: String, defaults: UserDefaults) -> [Element] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode(type, from: data)) ?? []
    }
}
