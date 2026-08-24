//
//  ManualWorkoutType.swift
//  Arovia
//
//  A small curated set for manual workout logging — deliberately not HKWorkoutActivityType
//  itself (which has 80+ cases and lives behind #if canImport(HealthKit)) so ActivityView can
//  reference this without importing HealthKit, keeping "UI never talks directly to HealthKit"
//  intact. HealthKitService maps this down to the real HK type internally.
//

import Foundation

enum ManualWorkoutType: String, CaseIterable, Identifiable {
    case walk
    case run
    case cycling
    case strengthTraining
    case yoga
    case swimming
    case hiking
    case hiit
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walk: "Walk"
        case .run: "Run"
        case .cycling: "Cycling"
        case .strengthTraining: "Strength Training"
        case .yoga: "Yoga"
        case .swimming: "Swimming"
        case .hiking: "Hike"
        case .hiit: "HIIT"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .walk: "figure.walk"
        case .run: "figure.run"
        case .cycling: "figure.outdoor.cycle"
        case .strengthTraining: "dumbbell.fill"
        case .yoga: "figure.yoga"
        case .swimming: "figure.pool.swim"
        case .hiking: "figure.hiking"
        case .hiit: "figure.highintensity.intervaltraining"
        case .other: "figure.mixed.cardio"
        }
    }
}
