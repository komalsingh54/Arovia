//
//  MealReminderScheduler.swift
//  Arovia
//

import Foundation
import Combine
import UserNotifications

@MainActor
final class MealReminderScheduler: ObservableObject {
    enum AuthorizationStatus {
        case notDetermined
        case authorized
        case denied
    }

    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "mealReminder."
    /// A week of coverage is plenty — this whole schedule gets rebuilt from scratch every time
    /// the app becomes active or a meal is logged, so it self-heals rather than needing to plan
    /// further ahead.
    private let daysAhead = 7

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorizationStatus = .authorized
        case .denied:
            authorizationStatus = .denied
        case .notDetermined:
            authorizationStatus = .notDetermined
        @unknown default:
            authorizationStatus = .notDetermined
        }
    }

    /// Only call this from an explicit user action (e.g. turning the Settings toggle on) —
    /// requesting permission on app launch, before the person has asked for reminders, is the
    /// kind of thing that gets Health & Fitness apps a one-star review.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authorizationStatus = granted ? .authorized : .denied
            return granted
        } catch {
            authorizationStatus = .denied
            return false
        }
    }

    /// Rebuilds the entire meal-reminder schedule from scratch: clears every pending reminder
    /// this app owns, then re-adds one-shot notifications for the next 7 days, skipping today's
    /// occurrence for any meal type already logged today. This runs cheaply enough (a handful of
    /// local notification requests) to call on every app-foreground and every meal add/edit/delete,
    /// which is what keeps "already logged" suppression correct without needing background
    /// execution the OS won't reliably grant a personal app anyway.
    func refreshSchedule(settings: MealReminderSettings, todaysLoggedMealTypes: Set<MealType>) async {
        let pending = await center.pendingNotificationRequests()
        let ourIdentifiers = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        if !ourIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ourIdentifiers)
        }

        guard settings.isEnabled, authorizationStatus == .authorized else { return }

        let calendar = Calendar.current
        let now = Date.now
        guard let today = calendar.dateComponents([.year, .month, .day], from: now) as DateComponents?,
              let todayStart = calendar.date(from: today) else { return }

        for dayOffset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) else { continue }

            for reminder in settings.reminders where reminder.isEnabled {
                if dayOffset == 0 && todaysLoggedMealTypes.contains(reminder.mealType) { continue }

                var components = calendar.dateComponents([.year, .month, .day], from: day)
                components.hour = reminder.hour
                components.minute = reminder.minute
                components.second = 0

                guard let fireDate = calendar.date(from: components), fireDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "\(reminder.mealType.title) time"
                content.body = "Don't forget to log \(reminder.mealType.title.lowercased()) in Arovia."
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let identifier = "\(identifierPrefix)\(reminder.mealType.rawValue).\(dayOffset)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }
}
