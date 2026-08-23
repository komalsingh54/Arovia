//
//  MotionActivityDetector.swift
//  Arovia
//
//  Queries CoreMotion's on-device activity history (iOS logs this continuously in the
//  background via a dedicated low-power motion coprocessor — present on every iPhone since the
//  5s — with no special Background Modes capability needed to *read* it after the fact) and
//  surfaces walking/running/cycling stretches of 8+ minutes that aren't already covered by a
//  logged workout. This is retrospective, not live: it runs when the app becomes active, not as
//  a background service, so there's no continuous battery cost from Arovia itself.
//

import Foundation
import Combine
#if canImport(CoreMotion)
import CoreMotion
#endif

@MainActor
final class MotionActivityDetector: ObservableObject {
    enum AuthorizationStatus {
        case notDetermined
        case authorized
        case denied
        case restricted
        case unavailable
    }

    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published private(set) var suggestions: [DetectedActivitySession] = []

    #if canImport(CoreMotion)
    private let activityManager = CMMotionActivityManager()
    #endif

    private let dismissedKey = "dismissedMotionActivitySessionIDs"
    private let minimumSessionDuration: TimeInterval = 8 * 60
    private let gapTolerance: TimeInterval = 4 * 60
    private let lookback: TimeInterval = 18 * 60 * 60

    var isAvailable: Bool {
        #if canImport(CoreMotion)
        CMMotionActivityManager.isActivityAvailable()
        #else
        false
        #endif
    }

    /// Removes a suggestion the person doesn't want to log, and remembers that choice so the
    /// exact same session doesn't reappear on the next refresh.
    func dismiss(_ session: DetectedActivitySession) {
        var dismissed = Set(UserDefaults.standard.stringArray(forKey: dismissedKey) ?? [])
        dismissed.insert(session.id)
        UserDefaults.standard.set(Array(dismissed), forKey: dismissedKey)
        suggestions.removeAll { $0.id == session.id }
    }

    func refresh(existingWorkouts: [WorkoutSummary]) async {
        #if canImport(CoreMotion)
        guard isAvailable else {
            authorizationStatus = .unavailable
            suggestions = []
            return
        }

        updateAuthorizationStatus()
        guard authorizationStatus != .denied, authorizationStatus != .restricted else {
            suggestions = []
            return
        }

        let end = Date.now
        let start = end.addingTimeInterval(-lookback)

        let samples: [CMMotionActivity] = await withCheckedContinuation { continuation in
            activityManager.queryActivityStarting(from: start, to: end, to: .main) { activities, _ in
                continuation.resume(returning: activities ?? [])
            }
        }

        // The query above is what triggers the system permission prompt the first time — status
        // may have just changed as a result, so re-check before deciding what to show.
        updateAuthorizationStatus()

        let sessions = Self.groupIntoSessions(samples, minimumDuration: minimumSessionDuration, gapTolerance: gapTolerance)
        let dismissed = Set(UserDefaults.standard.stringArray(forKey: dismissedKey) ?? [])

        suggestions = Array(
            sessions
                .filter { !dismissed.contains($0.id) }
                .filter { session in !existingWorkouts.contains { workoutOverlaps($0, session) } }
                .sorted { $0.start > $1.start }
                .prefix(3)
        )
        #else
        authorizationStatus = .unavailable
        #endif
    }

    #if canImport(CoreMotion)
    private func updateAuthorizationStatus() {
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized: authorizationStatus = .authorized
        case .denied: authorizationStatus = .denied
        case .restricted: authorizationStatus = .restricted
        case .notDetermined: authorizationStatus = .notDetermined
        @unknown default: authorizationStatus = .notDetermined
        }
    }
    #endif

    private func workoutOverlaps(_ workout: WorkoutSummary, _ session: DetectedActivitySession) -> Bool {
        let workoutEnd = workout.startDate.addingTimeInterval(workout.duration)
        let overlapStart = max(workout.startDate, session.start)
        let overlapEnd = min(workoutEnd, session.end)
        guard overlapEnd > overlapStart else { return false }
        // More than half the detected session already covered by a logged workout — treat it as
        // "already captured" rather than suggesting a near-duplicate.
        return overlapEnd.timeIntervalSince(overlapStart) > session.duration * 0.5
    }

    #if canImport(CoreMotion)
    /// CMMotionActivity samples are point-in-time state changes, not fixed-interval readings —
    /// this walks them chronologically and merges consecutive same-type samples (tolerating
    /// brief gaps, e.g. a few seconds of "stationary" at a red light mid-walk) into sessions.
    private static func groupIntoSessions(
        _ samples: [CMMotionActivity], minimumDuration: TimeInterval, gapTolerance: TimeInterval
    ) -> [DetectedActivitySession] {
        let sorted = samples
            .filter { $0.confidence != .low }
            .sorted { $0.startDate < $1.startDate }

        var result: [DetectedActivitySession] = []
        var currentType: ManualWorkoutType?
        var currentStart: Date?
        var currentEnd: Date?

        func finalizeCurrent() {
            guard let type = currentType, let start = currentStart, let end = currentEnd else { return }
            let duration = end.timeIntervalSince(start)
            if duration >= minimumDuration {
                let id = "\(type.rawValue)-\(Int(start.timeIntervalSince1970))"
                result.append(DetectedActivitySession(id: id, type: type, start: start, end: end))
            }
        }

        for sample in sorted {
            let category = dominantType(for: sample)

            if let type = currentType, let end = currentEnd,
               category == type, sample.startDate.timeIntervalSince(end) <= gapTolerance {
                currentEnd = sample.startDate
                continue
            }

            finalizeCurrent()
            currentType = category
            currentStart = category != nil ? sample.startDate : nil
            currentEnd = category != nil ? sample.startDate : nil
        }
        finalizeCurrent()
        return result
    }

    private static func dominantType(for sample: CMMotionActivity) -> ManualWorkoutType? {
        if sample.running { return .run }
        if sample.cycling { return .cycling }
        if sample.walking { return .walk }
        return nil
    }
    #endif
}
