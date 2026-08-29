//
//  DataExportBundle.swift
//  Arovia
//
//  Full export of everything Arovia stores locally — the safety net for the fact that
//  CloudKit sync is currently off (needs a paid Apple Developer account), meaning this data
//  otherwise lives in exactly one place: this device. Plain JSON, not a proprietary format,
//  so it's readable even without Arovia itself.
//

import Foundation

struct DataExportBundle: Codable {
    let exportedAt: Date
    let appVersion: String
    let goals: [FitnessGoal]
    let journalEntries: [JournalEntry]
    let mealEntries: [MealEntry]
    let waterEntries: [WaterEntry]

    init(localStore: LocalStore) {
        self.exportedAt = .now
        self.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        self.goals = localStore.goals
        self.journalEntries = localStore.journalEntries
        self.mealEntries = localStore.mealEntries
        self.waterEntries = localStore.waterEntries
    }

    /// Writes pretty-printed JSON to a temp file and returns its URL, ready for a ShareLink —
    /// a fresh file each time rather than a cached one, so it's never stale.
    func writeToTemporaryFile() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "Arovia-Export-\(formatter.string(from: exportedAt)).json"

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}
