//
//  DailyMetrics.swift
//  Arovia
//

import Foundation

struct DailyMetrics: Equatable {
    let steps: Double
    let activeEnergy: Double
    let restingEnergy: Double
    let exerciseMinutes: Double
    let workoutCount: Int
    let distanceMeters: Double
    let flightsClimbed: Double
    let averageHeartRate: Double?
    let restingHeartRate: Double?
    let sleepHours: Double?
    let latestWeightKg: Double?

    /// Active + resting (basal) energy — a much better "calories out" figure than active energy
    /// alone, since resting energy is what your body burns just staying alive.
    var totalEnergyOut: Double { activeEnergy + restingEnergy }

    static let empty = DailyMetrics(
        steps: 0,
        activeEnergy: 0,
        restingEnergy: 0,
        exerciseMinutes: 0,
        workoutCount: 0,
        distanceMeters: 0,
        flightsClimbed: 0,
        averageHeartRate: nil,
        restingHeartRate: nil,
        sleepHours: nil,
        latestWeightKg: nil
    )
}

/// A single day's value for a given metric, used across all the weekly trend charts
/// (steps, distance, resting heart rate, sleep, active energy, etc).
struct DailyMetricPoint: Identifiable, Equatable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// Bundled 7-day trend series so a single HealthKit refresh populates every chart at once.
struct WeeklyHealthTrends: Equatable {
    var activeEnergy: [DailyMetricPoint] = []
    var steps: [DailyMetricPoint] = []
    var distanceMeters: [DailyMetricPoint] = []
    var restingHeartRate: [DailyMetricPoint] = []
    var sleepHours: [DailyMetricPoint] = []
    var weightKg: [DailyMetricPoint] = []

    static let empty = WeeklyHealthTrends()
}
