//
//  WorkoutSummary.swift
//  Arovia
//

import Foundation

struct WorkoutSummary: Identifiable, Equatable {
    let id: UUID
    let title: String
    let startDate: Date
    let duration: TimeInterval

    var durationDescription: String {
        Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
