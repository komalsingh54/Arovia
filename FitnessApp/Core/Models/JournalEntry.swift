//
//  JournalEntry.swift
//  Arovia
//

import Foundation

enum JournalCategory: String, Codable, CaseIterable, Identifiable {
    case workout
    case recovery
    case nutrition
    case reflection

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .workout: "dumbbell.fill"
        case .recovery: "bed.double.fill"
        case .nutrition: "leaf.fill"
        case .reflection: "text.quote"
        }
    }
}

struct JournalEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let details: String
    let date: Date
    let category: JournalCategory

    init(title: String, details: String, category: JournalCategory = .reflection, date: Date = .now) {
        self.id = UUID()
        self.title = title
        self.details = details
        self.date = date
        self.category = category
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, details, date, category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        details = try container.decode(String.self, forKey: .details)
        date = try container.decode(Date.self, forKey: .date)
        category = try container.decodeIfPresent(JournalCategory.self, forKey: .category) ?? .reflection
    }

    func updating(title: String, details: String, category: JournalCategory) -> JournalEntry {
        JournalEntry(id: id, title: title, details: details, date: date, category: category)
    }

    private init(id: UUID, title: String, details: String, date: Date, category: JournalCategory) {
        self.id = id
        self.title = title
        self.details = details
        self.date = date
        self.category = category
    }
}
