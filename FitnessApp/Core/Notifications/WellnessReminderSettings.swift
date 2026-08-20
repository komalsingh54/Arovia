//
//  WellnessReminderSettings.swift
//  Arovia
//
//  Plain data + UserDefaults keys, same pattern as MealReminderSettings — read fresh via
//  `.current()` from both the Settings UI (@AppStorage against these same keys) and the
//  scheduler, so there's one source of truth instead of two copies of the defaults.
//

import Foundation

struct WellnessReminderSettings {
    struct Checkpoint {
        let hour: Int
        let minute: Int
        /// Fraction of the daily target expected to be met by this point in the day — used to
        /// decide whether this checkpoint's reminder is worth firing at all.
        let expectedFraction: Double
    }

    var hydrationEnabled: Bool
    var hydrationTargetMl: Double
    var movementEnabled: Bool
    var movementStepGoal: Double
    var bedtimeEnabled: Bool
    var bedtimeHour: Int
    var bedtimeMinute: Int

    /// Fixed checkpoints rather than user-configurable ones — editing 5+ individual times for
    /// two different reminder kinds would be a lot of Settings UI for very little real benefit
    /// over a sensible spread through the waking day.
    static let hydrationCheckpoints: [Checkpoint] = [
        Checkpoint(hour: 10, minute: 0, expectedFraction: 0.2),
        Checkpoint(hour: 12, minute: 30, expectedFraction: 0.4),
        Checkpoint(hour: 15, minute: 0, expectedFraction: 0.6),
        Checkpoint(hour: 17, minute: 30, expectedFraction: 0.8),
        Checkpoint(hour: 19, minute: 30, expectedFraction: 0.95),
    ]

    static let movementCheckpoints: [Checkpoint] = [
        Checkpoint(hour: 11, minute: 0, expectedFraction: 0.3),
        Checkpoint(hour: 14, minute: 0, expectedFraction: 0.55),
        Checkpoint(hour: 17, minute: 0, expectedFraction: 0.8),
    ]

    /// Slack so a reminder doesn't fire the moment you're a single step behind an idealized
    /// pace — only nudges when you're meaningfully behind.
    static let suppressionSlack = 0.7

    enum Keys {
        static let hydrationEnabled = "hydrationRemindersEnabled"
        static let movementEnabled = "movementRemindersEnabled"
        static let bedtimeEnabled = "bedtimeReminderEnabled"
        static let bedtimeHour = "bedtimeReminderHour"
        static let bedtimeMinute = "bedtimeReminderMinute"
    }

    static let defaultBedtimeHour = 22
    static let defaultBedtimeMinute = 0

    static func current(defaults: UserDefaults = .standard) -> WellnessReminderSettings {
        WellnessReminderSettings(
            hydrationEnabled: defaults.bool(forKey: Keys.hydrationEnabled),
            hydrationTargetMl: defaults.object(forKey: "dailyWaterTargetMl") as? Double ?? 2_000,
            movementEnabled: defaults.bool(forKey: Keys.movementEnabled),
            movementStepGoal: 10_000,
            bedtimeEnabled: defaults.bool(forKey: Keys.bedtimeEnabled),
            bedtimeHour: defaults.object(forKey: Keys.bedtimeHour) as? Int ?? defaultBedtimeHour,
            bedtimeMinute: defaults.object(forKey: Keys.bedtimeMinute) as? Int ?? defaultBedtimeMinute
        )
    }
}
