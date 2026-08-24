//
//  WellnessReminderScheduler.swift
//  Arovia
//
//  Same architecture as MealReminderScheduler: rebuild the whole schedule from scratch on every
//  app-foreground/data-change rather than trying to surgically patch individual pending requests.
//  The one addition here is pace-based suppression for hydration/movement — each checkpoint knows
//  what fraction of the daily target "should" be done by that time, and skips firing if you're
//  already there, so it nudges you when you're actually behind rather than on a blind timer.
//

import Foundation
import Combine
import UserNotifications

@MainActor
final class WellnessReminderScheduler: ObservableObject {
    enum AuthorizationStatus {
        case notDetermined
        case authorized
        case denied
    }

    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "wellnessReminder."

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

    func refreshSchedule(settings: WellnessReminderSettings, todaysWaterMl: Double, todaysSteps: Double) async {
        let pending = await center.pendingNotificationRequests()
        let ourIdentifiers = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        if !ourIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ourIdentifiers)
        }

        guard authorizationStatus == .authorized else { return }

        if settings.hydrationEnabled {
            await scheduleCheckpoints(
                WellnessReminderSettings.hydrationCheckpoints,
                kind: "hydration",
                todaysProgress: todaysWaterMl,
                target: settings.hydrationTargetMl,
                title: "Hydration check-in",
                body: "Stay on track — have some water."
            )
        }

        if settings.movementEnabled {
            await scheduleCheckpoints(
                WellnessReminderSettings.movementCheckpoints,
                kind: "movement",
                todaysProgress: todaysSteps,
                target: settings.movementStepGoal,
                title: "Time to move",
                body: "A short walk would help close today's step gap."
            )
        }

        if settings.bedtimeEnabled {
            await scheduleBedtime(hour: settings.bedtimeHour, minute: settings.bedtimeMinute)
        }
    }

    /// Only today's checkpoints are meaningful for pace suppression (we don't know tomorrow's
    /// progress in advance), so — unlike meal reminders' 7-day rolling window — this schedules
    /// just the remaining checkpoints for today. Called again on every foreground/data-change,
    /// so tomorrow's checkpoints get scheduled once the day actually turns over.
    private func scheduleCheckpoints(
        _ checkpoints: [WellnessReminderSettings.Checkpoint],
        kind: String,
        todaysProgress: Double,
        target: Double,
        title: String,
        body: String
    ) async {
        guard target > 0 else { return }
        let calendar = Calendar.current
        let now = Date.now

        for (index, checkpoint) in checkpoints.enumerated() {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = checkpoint.hour
            components.minute = checkpoint.minute
            components.second = 0

            guard let fireDate = calendar.date(from: components), fireDate > now else { continue }

            let expectedProgress = target * checkpoint.expectedFraction
            let threshold = expectedProgress * WellnessReminderSettings.suppressionSlack
            if todaysProgress >= threshold { continue }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "\(identifierPrefix)\(kind).\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// A rolling 7-day window like meal reminders — unlike hydration/movement there's nothing to
    /// pace-suppress here (we can't tell in advance whether you've gone to bed), so a plain
    /// repeat-by-rebuilding schedule is enough.
    private func scheduleBedtime(hour: Int, minute: Int) async {
        let calendar = Calendar.current
        let now = Date.now
        guard let todayStart = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: now)) else { return }

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            components.second = 0

            guard let fireDate = calendar.date(from: components), fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Wind-down time"
            content.body = "Heading toward bedtime — a consistent schedule helps sleep quality."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "\(identifierPrefix)bedtime.\(dayOffset)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
