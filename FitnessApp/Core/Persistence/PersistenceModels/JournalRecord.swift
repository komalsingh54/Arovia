//
//  JournalRecord.swift
//  Arovia
//

import Foundation
import SwiftData

@Model
final class JournalRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String
    var date: Date
    var categoryRaw: String
    var updatedAt: Date

    var cloudRecordName: String?
    var pendingSync: Bool

    init(
        id: UUID,
        title: String,
        details: String,
        date: Date,
        categoryRaw: String,
        updatedAt: Date,
        cloudRecordName: String? = nil,
        pendingSync: Bool = true
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.date = date
        self.categoryRaw = categoryRaw
        self.updatedAt = updatedAt
        self.cloudRecordName = cloudRecordName
        self.pendingSync = pendingSync
    }
}

extension JournalRecord {
    var asDomainModel: JournalEntry {
        JournalEntry(
            id: id,
            title: title,
            details: details,
            date: date,
            category: JournalCategory(rawValue: categoryRaw) ?? .reflection,
            updatedAt: updatedAt
        )
    }

    func apply(_ entry: JournalEntry) {
        title = entry.title
        details = entry.details
        date = entry.date
        categoryRaw = entry.category.rawValue
        updatedAt = entry.updatedAt
        pendingSync = true
    }

    convenience init(_ entry: JournalEntry) {
        self.init(
            id: entry.id,
            title: entry.title,
            details: entry.details,
            date: entry.date,
            categoryRaw: entry.category.rawValue,
            updatedAt: entry.updatedAt
        )
    }
}
