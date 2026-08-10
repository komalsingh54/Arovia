//
//  HealthStore.swift
//  Arovia
//

import Foundation
import SwiftUI
import Combine

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

    private let authorizationRequestedKey = "healthAuthorizationRequested"

    #if canImport(HealthKit)
    private let observerService = HealthKitObserverService()
    #endif

    func refresh() async {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            status = .unavailable
            lastErrorMessage = "This device doesn't support Health data (e.g. iPad without Health app)."
            return
        }

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
            await refresh()
        } catch {
            status = .denied
            lastErrorMessage = error.localizedDescription
        }
        #else
        status = .unavailable
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
