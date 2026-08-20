//
//  WaterEntry.swift
//  Arovia
//

import Foundation

struct WaterEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let amountMl: Double
    let date: Date

    init(amountMl: Double, date: Date = .now) {
        self.id = UUID()
        self.amountMl = amountMl
        self.date = date
    }

    init(id: UUID, amountMl: Double, date: Date) {
        self.id = id
        self.amountMl = amountMl
        self.date = date
    }
}
