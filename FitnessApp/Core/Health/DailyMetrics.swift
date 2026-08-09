//
//  DailyMetrics.swift
//  Arovia
//

import Foundation

struct DailyMetrics: Equatable {
    let steps: Double
    let activeEnergy: Double
    let exerciseMinutes: Double
    let workoutCount: Int

    static let empty = DailyMetrics(steps: 0, activeEnergy: 0, exerciseMinutes: 0, workoutCount: 0)
}
