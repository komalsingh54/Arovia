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

    private let authorizationRequestedKey = "healthAuthorizationRequested"

    #if canImport(HealthKit)
    private let observerService = HealthKitObserverService()
    #endif

    func refresh() async {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            status = .unavailable
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
            startAutoSyncIfNeeded()
        } catch HealthKitServiceError.authorizationRequired {
            status = .authorizationRequired
        } catch {
            status = .failed
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
            await refresh()
        } catch {
            status = .denied
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
