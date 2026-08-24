//
//  MealReminderSettings.swift
//  Arovia
//
//  Plain data + UserDefaults keys for meal reminders. Deliberately NOT an ObservableObject —
//  it's read fresh via `.current()` wherever it's needed (Settings UI via @AppStorage against
//  these same keys, and the scheduler when it rebuilds notifications), so there's one source of
//  truth for the keys and defaults instead of two places that could drift out of sync.
//

import Foundation

struct MealReminderSettings {
    struct ReminderTime {
        let mealType: MealType
        var isEnabled: Bool
        var hour: Int
        var minute: Int
    }

    var isEnabled: Bool
    var reminders: [ReminderTime]

    /// Snacks don't have a natural "you should have eaten by now" time, so only the three
    /// scheduled meals get reminders.
    static let remindableMealTypes: [MealType] = [.breakfast, .lunch, .dinner]

    static let defaultHours: [MealType: Int] = [.breakfast: 8, .lunch: 13, .dinner: 19]

    enum Keys {
        static let masterEnabled = "mealRemindersEnabled"
        static func enabled(_ type: MealType) -> String { "mealReminderEnabled.\(type.rawValue)" }
        static func hour(_ type: MealType) -> String { "mealReminderHour.\(type.rawValue)" }
        static func minute(_ type: MealType) -> String { "mealReminderMinute.\(type.rawValue)" }
    }

    static func current(defaults: UserDefaults = .standard) -> MealReminderSettings {
        let isEnabled = defaults.bool(forKey: Keys.masterEnabled)
        let reminders = remindableMealTypes.map { type -> ReminderTime in
            let enabledKey = Keys.enabled(type)
            // A key that's never been set reads as `false` from UserDefaults, which would make
            // every reminder start "off" the first time this ever runs — register a default of
            // `true` up front instead so unset means "on" for these three meal types.
            let isTypeEnabled = defaults.object(forKey: enabledKey) as? Bool ?? true
            let hour = defaults.object(forKey: Keys.hour(type)) as? Int ?? (defaultHours[type] ?? 8)
            let minute = defaults.object(forKey: Keys.minute(type)) as? Int ?? 0
            return ReminderTime(mealType: type, isEnabled: isTypeEnabled, hour: hour, minute: minute)
        }
        return MealReminderSettings(isEnabled: isEnabled, reminders: reminders)
    }
}
