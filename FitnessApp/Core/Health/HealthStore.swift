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
    @Published private(set) var status: Status = .idle
    private let authorizationRequestedKey = "healthAuthorizationRequested"

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

        status = .loading
        do {
            let service = HealthKitService()
            async let fetchedMetrics = service.fetchTodayMetrics()
            async let fetchedWorkouts = service.fetchRecentWorkouts()
            metrics = try await fetchedMetrics
            recentWorkouts = try await fetchedWorkouts
            status = .ready
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
}

#if canImport(HealthKit)
enum HealthKitServiceError: Error {
    case authorizationRequired
    case unavailableMetric
}

struct HealthKitService {
    private let healthStore = HKHealthStore()

    func requestAuthorization() async throws {
        guard let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            throw HealthKitServiceError.unavailableMetric
        }

        try await healthStore.requestAuthorization(toShare: [], read: [stepCount, activeEnergy, exerciseTime, HKObjectType.workoutType()])
    }

    func fetchTodayMetrics() async throws -> DailyMetrics {
        guard let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            throw HealthKitServiceError.unavailableMetric
        }

        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: .now), end: .now)
        async let steps = quantitySum(for: stepCount, unit: .count(), predicate: predicate)
        async let energy = quantitySum(for: activeEnergy, unit: .kilocalorie(), predicate: predicate)
        async let exercise = quantitySum(for: exerciseTime, unit: .minute(), predicate: predicate)
        async let workouts = workoutCount(predicate: predicate)

        return try await DailyMetrics(
            steps: steps,
            activeEnergy: energy,
            exerciseMinutes: exercise,
            workoutCount: workouts
        )
    }

    func fetchRecentWorkouts() async throws -> [WorkoutSummary] {
        try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: nil, limit: 10, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = (samples as? [HKWorkout] ?? []).map { workout in
                    WorkoutSummary(
                        id: workout.uuid,
                        title: workoutTitle(for: workout.workoutActivityType),
                        startDate: workout.startDate,
                        duration: workout.duration
                    )
                }
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }

    private func quantitySum(for type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            healthStore.execute(query)
        }
    }

    private func workoutCount(predicate: NSPredicate) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples?.count ?? 0)
            }
            healthStore.execute(query)
        }
    }

    private func workoutTitle(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "Run"
        case .walking: "Walk"
        case .cycling: "Cycling"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "Strength Training"
        case .yoga: "Yoga"
        case .swimming: "Swimming"
        case .hiking: "Hike"
        case .highIntensityIntervalTraining: "HIIT"
        default: "Workout"
        }
    }
}
#endif
