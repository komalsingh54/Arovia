//
//  HealthStore.swift
//  Arovia
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

#if canImport(HealthKit)
import HealthKit
#endif

@MainActor
final class HealthStore: ObservableObject {
    enum Status: Equatable {
        case idle
        case loading
        case unavailable
        case authorizationRequired
        case denied
        case ready
        case failed
    }

    @Published private(set) var metrics = DailyMetrics.empty
    @Published private(set) var recentWorkouts: [WorkoutSummary] = []
    @Published private(set) var weeklyTrends = WeeklyHealthTrends.empty
    @Published private(set) var status: Status = .idle
    /// Timestamp of the last successful refresh (manual or background-triggered), shown in the UI
    /// so it's clear data really is syncing automatically.
    @Published private(set) var lastUpdated: Date?
    /// The real error text from HealthKit, if the last authorization/refresh attempt failed.
    /// Shown in the UI so "it's not syncing" can actually be diagnosed instead of guessed at.
    @Published private(set) var lastErrorMessage: String?
    /// Health types HealthKit has never actually asked the person about (`.notDetermined`).
    /// This is the real, API-backed signal for "some health data isn't connected" — unlike a
    /// vague "connect health" prompt, it names exactly what's missing. Powers the header banner.
    @Published private(set) var pendingPermissionNames: [String] = []
    /// Whether the person has granted write access (see Settings → "Write to Apple Health").
    /// Same read-only-permission opacity applies here too — HealthKit tells us if we've never
    /// asked, but not whether a specific write type was declined, so this only ever flips to
    /// `true` once `requestWriteAuthorization()` has actually been called successfully.
    @Published private(set) var hasWriteAccess = false

    private let authorizationRequestedKey = "healthAuthorizationRequested"
    private let writeAuthorizationRequestedKey = "healthWriteAuthorizationRequested"
    #if canImport(HealthKit)
    private let healthKitStore = HKHealthStore()
    #endif

    #if canImport(HealthKit)
    private let observerService = HealthKitObserverService()
    #endif

    /// Whether this device supports HealthKit at all (false on e.g. some iPads). Exposed so views
    /// can show it in diagnostics without importing HealthKit themselves.
    var isHealthDataAvailable: Bool {
        #if canImport(HealthKit)
        HKHealthStore.isHealthDataAvailable()
        #else
        false
        #endif
    }

    func refresh() async {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            status = .unavailable
            lastErrorMessage = "This device doesn't support Health data (e.g. iPad without Health app)."
            return
        }

        refreshPendingPermissions()
        hasWriteAccess = UserDefaults.standard.bool(forKey: writeAuthorizationRequestedKey)

        guard UserDefaults.standard.bool(forKey: authorizationRequestedKey) else {
            status = .authorizationRequired
            return
        }

        if status != .ready { status = .loading }
        do {
            let service = HealthKitService()
            async let fetchedMetrics = service.fetchTodayMetrics()
            async let fetchedWorkouts = service.fetchRecentWorkouts()
            async let fetchedTrends = service.fetchWeeklyTrends()
            metrics = try await fetchedMetrics
            recentWorkouts = try await fetchedWorkouts
            weeklyTrends = try await fetchedTrends
            status = .ready
            lastUpdated = .now
            lastErrorMessage = nil
            startAutoSyncIfNeeded()
        } catch HealthKitServiceError.authorizationRequired {
            status = .authorizationRequired
        } catch {
            status = .failed
            lastErrorMessage = error.localizedDescription
        }
        #else
        status = .unavailable
        #endif
    }

    func requestAuthorization() async {
        #if canImport(HealthKit)
        do {
            try await HealthKitService().requestAuthorization()
            UserDefaults.standard.set(true, forKey: authorizationRequestedKey)
            lastErrorMessage = nil
            refreshPendingPermissions()
            await refresh()
        } catch {
            status = .denied
            lastErrorMessage = error.localizedDescription
        }
        #else
        status = .unavailable
        #endif
    }

    /// Requested only when the person turns on Settings → "Write to Apple Health" — never
    /// bundled into the read-permission flow above.
    @discardableResult
    func requestWriteAuthorization() async -> Bool {
        #if canImport(HealthKit)
        do {
            try await HealthKitService().requestWriteAuthorization()
            hasWriteAccess = true
            UserDefaults.standard.set(true, forKey: writeAuthorizationRequestedKey)
            return true
        } catch {
            hasWriteAccess = false
            lastErrorMessage = error.localizedDescription
            return false
        }
        #else
        return false
        #endif
    }

    /// Turns off write-through from the app's side. Can't revoke the actual HealthKit
    /// permission (only Settings → Privacy & Security → Health can do that) — this just stops
    /// Arovia from attempting further writes.
    func disableWriteAccess() {
        hasWriteAccess = false
        UserDefaults.standard.set(false, forKey: writeAuthorizationRequestedKey)
    }

    /// Best-effort write-through — logging in Arovia should never fail because a HealthKit write
    /// failed, so errors here are swallowed rather than surfaced. `hasWriteAccess` gates whether
    /// this even attempts anything.
    func writeToHealth(water entry: WaterEntry) async {
        #if canImport(HealthKit)
        guard hasWriteAccess else { return }
        try? await HealthKitService().writeWater(amountMl: entry.amountMl, date: entry.date, externalID: entry.id)
        #endif
    }

    func writeToHealth(meal: MealEntry) async {
        #if canImport(HealthKit)
        guard hasWriteAccess else { return }
        try? await HealthKitService().writeMeal(meal)
        #endif
    }

    func saveManualWorkout(type: ManualWorkoutType, start: Date, duration: TimeInterval) async throws {
        #if canImport(HealthKit)
        if !hasWriteAccess {
            let granted = await requestWriteAuthorization()
            guard granted else { throw HealthKitServiceError.authorizationRequired }
        }
        try await HealthKitService().saveManualWorkout(type: type, start: start, duration: duration)
        await refresh()
        #endif
    }

    /// Persists a tracked outdoor walk (see WalkTrackingService/OutdoorWalkView) as a walking
    /// workout with an attached GPS route. Same write-access gate as saveManualWorkout — walks
    /// are user-generated content, not read-only health data.
    func saveOutdoorWalk(_ walk: FinishedWalk) async throws {
        #if canImport(HealthKit)
        if !hasWriteAccess {
            let granted = await requestWriteAuthorization()
            guard granted else { throw HealthKitServiceError.authorizationRequired }
        }
        try await HealthKitService().saveOutdoorWalk(
            start: walk.start,
            end: walk.end,
            distanceMeters: walk.distanceMeters,
            route: walk.route
        )
        await refresh()
        #endif
    }

    /// Checks HealthKit's real per-type authorization status. `.notDetermined` means this exact
    /// type has never been presented to the person for this app — the only state HealthKit
    /// reliably reveals for read-only types (granted vs. denied is intentionally hidden from apps).
    private func refreshPendingPermissions() {
        #if canImport(HealthKit)
        let pending = HealthKitService.readTypes.filter {
            healthKitStore.authorizationStatus(for: $0) == .notDetermined
        }
        pendingPermissionNames = pending.map { HealthKitService.displayName(for: $0) }.sorted()
        #endif
    }

    /// Registers HealthKit observers once so new data (a workout finishing, steps updating, a
    /// night of sleep logging) automatically triggers a refresh — no manual pull-to-refresh needed.
    private func startAutoSyncIfNeeded() {
        #if canImport(HealthKit)
        observerService.startObserving { [weak self] in
            Task { await self?.refresh() }
        }
        #endif
    }
}
