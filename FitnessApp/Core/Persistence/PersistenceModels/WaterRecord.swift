//
//  WaterRecord.swift
//  Arovia
//

import Foundation
import SwiftData

@Model
final class WaterRecord {
    @Attribute(.unique) var id: UUID
    var amountMl: Double
    var date: Date

    init(id: UUID, amountMl: Double, date: Date) {
        self.id = id
        self.amountMl = amountMl
        self.date = date
    }
}

extension WaterRecord {
    var asDomainModel: WaterEntry {
        WaterEntry(id: id, amountMl: amountMl, date: date)
    }

    convenience init(_ entry: WaterEntry) {
        self.init(id: entry.id, amountMl: entry.amountMl, date: entry.date)
    }
}
