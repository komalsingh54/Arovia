//
//  HealthKitService.swift
//  Arovia
//
//  Small, focused HealthKit query components per skills.md — one method per concern,
//  domain-model output only (no HK types leak past this file).
//

import Foundation

#if canImport(HealthKit)
import HealthKit

enum HealthKitServiceError: Error {
    case authorizationRequired
    case unavailableMetric
}

struct HealthKitService {
    let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    // MARK: Type registry

    static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .basalEnergyBurned, .appleExerciseTime,
            .distanceWalkingRunning, .flightsClimbed, .heartRate, .restingHeartRate, .bodyMass
        ]
        for identifier in quantityIdentifiers {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }

    /// Write access is opt-in (see Settings → "Write to Apple Health") and deliberately narrow —
    /// only the nutrition/water/workout data this app itself generates, never anything read-only
    /// like heart rate. Keeps the write side minimal and easy to reason about.
    static var shareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [HKObjectType.workoutType()]
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .dietaryWater, .dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal
        ]
        for identifier in quantityIdentifiers {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        return types
    }

    /// Sample types only (subset of `readTypes`, since `HKObserverQuery` needs `HKSampleType`).
    static var observableSampleTypes: Set<HKSampleType> {
        Set(readTypes.compactMap { $0 as? HKSampleType })
    }

    private static let friendlyNames: [String: String] = [
        HKQuantityTypeIdentifier.stepCount.rawValue: "Steps",
        HKQuantityTypeIdentifier.activeEnergyBurned.rawValue: "Active Energy",
        HKQuantityTypeIdentifier.basalEnergyBurned.rawValue: "Resting Energy",
        HKQuantityTypeIdentifier.appleExerciseTime.rawValue: "Exercise Time",
        HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue: "Distance",
        HKQuantityTypeIdentifier.flightsClimbed.rawValue: "Flights Climbed",
        HKQuantityTypeIdentifier.heartRate.rawValue: "Heart Rate",
        HKQuantityTypeIdentifier.restingHeartRate.rawValue: "Resting Heart Rate",
        HKQuantityTypeIdentifier.bodyMass.rawValue: "Weight",
        HKCategoryTypeIdentifier.sleepAnalysis.rawValue: "Sleep",
        HKObjectType.workoutType().identifier: "Workouts"
    ]

    /// Human-readable name for a HealthKit type, used in the permission banner so the person can
    /// see exactly what's missing instead of a generic "Health access needed."
    static func displayName(for type: HKObjectType) -> String {
        friendlyNames[type.identifier] ?? type.identifier
    }

    func requestAuthorization() async throws {
        try await healthStore.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    /// Requested separately from read access, only when the person turns on
    /// Settings → "Write to Apple Health" — never bundled into the initial read-permission
    /// prompt, so turning Arovia on doesn't silently ask to write data nobody agreed to yet.
    func requestWriteAuthorization() async throws {
        try await healthStore.requestAuthorization(toShare: Self.shareTypes, read: [])
    }

    // MARK: Writing (opt-in — see Settings → "Write to Apple Health")

    /// Writes a water sample. `externalID` (the app's own UUID for this entry) is stored in
    /// metadata so a future edit/delete could look the sample back up — HealthKit samples are
    /// otherwise immutable once written.
    func writeWater(amountMl: Double, date: Date, externalID: UUID) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: amountMl)
        let sample = HKQuantitySample(
            type: type, quantity: quantity, start: date, end: date,
            metadata: [HKMetadataKeyExternalUUID: externalID.uuidString]
        )
        try await healthStore.save(sample)
    }

    /// Writes a meal as several dietary samples sharing one `HKCorrelation` — this is what makes
    /// it show up as a single grouped entry in Apple Health's own Nutrition log instead of four
    /// disconnected numbers.
    func writeMeal(_ meal: MealEntry) async throws {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed),
              let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein),
              let carbType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates),
              let fatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal),
              let foodCorrelationType = HKObjectType.correlationType(forIdentifier: .food) else { return }

        let metadata = [HKMetadataKeyExternalUUID: meal.id.uuidString, HKMetadataKeyFoodType: meal.name]
        let samples: Set<HKSample> = [
            HKQuantitySample(type: energyType, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: meal.calories), start: meal.date, end: meal.date, metadata: metadata),
            HKQuantitySample(type: proteinType, quantity: HKQuantity(unit: .gram(), doubleValue: meal.proteinGrams), start: meal.date, end: meal.date, metadata: metadata),
            HKQuantitySample(type: carbType, quantity: HKQuantity(unit: .gram(), doubleValue: meal.carbohydratesGrams), start: meal.date, end: meal.date, metadata: metadata),
            HKQuantitySample(type: fatType, quantity: HKQuantity(unit: .gram(), doubleValue: meal.fatGrams), start: meal.date, end: meal.date, metadata: metadata),
        ]
        let correlation = HKCorrelation(type: foodCorrelationType, start: meal.date, end: meal.date, objects: samples, metadata: metadata)
        try await healthStore.save(correlation)
    }

    /// A simple manually-logged workout (no route/samples, just type + timing) — written to
    /// HealthKit rather than kept as a separate in-app model so it shows up in "Recent Workouts"
    /// through the exact same `fetchRecentWorkouts()` query as Watch-recorded workouts, with no
    /// merge logic needed anywhere in the app.
    func saveManualWorkout(type: ManualWorkoutType, start: Date, duration: TimeInterval) async throws {
        let workout = HKWorkout(
            activityType: hkActivityType(for: type),
            start: start,
            end: start.addingTimeInterval(duration),
            metadata: [HKMetadataKeyWasUserEntered: true]
        )
        try await healthStore.save(workout)
    }

    private func hkActivityType(for type: ManualWorkoutType) -> HKWorkoutActivityType {
        switch type {
        case .walk: .walking
        case .run: .running
        case .cycling: .cycling
        case .strengthTraining: .traditionalStrengthTraining
        case .yoga: .yoga
        case .swimming: .swimming
        case .hiking: .hiking
        case .hiit: .highIntensityIntervalTraining
        case .other: .other
        }
    }

    // MARK: Today's snapshot

    func fetchTodayMetrics() async throws -> DailyMetrics {
        guard let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let basalEnergy = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned),
              let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime),
              let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
              let flights = HKQuantityType.quantityType(forIdentifier: .flightsClimbed),
              let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let restingHeartRate = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthKitServiceError.unavailableMetric
        }

        let dayPredicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: .now), end: .now)

        async let steps = quantitySum(for: stepCount, unit: .count(), predicate: dayPredicate)
        async let energy = quantitySum(for: activeEnergy, unit: .kilocalorie(), predicate: dayPredicate)
        async let resting = quantitySum(for: basalEnergy, unit: .kilocalorie(), predicate: dayPredicate)
        async let exercise = quantitySum(for: exerciseTime, unit: .minute(), predicate: dayPredicate)
        async let distanceValue = quantitySum(for: distance, unit: .meter(), predicate: dayPredicate)
        async let flightsValue = quantitySum(for: flights, unit: .count(), predicate: dayPredicate)
        async let avgHeartRate = quantityAverage(for: heartRate, unit: HKUnit.count().unitDivided(by: .minute()), predicate: dayPredicate)
        async let restingHR = quantityAverage(for: restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), predicate: dayPredicate)
        async let workouts = workoutCount(predicate: dayPredicate)
        async let lastNightSleep = sleepHours(endingBefore: .now)
        async let weight = latestBodyMassKg()

        return try await DailyMetrics(
            steps: steps,
            activeEnergy: energy,
            restingEnergy: resting,
            exerciseMinutes: exercise,
            workoutCount: workouts,
            distanceMeters: distanceValue,
            flightsClimbed: flightsValue,
            averageHeartRate: avgHeartRate,
            restingHeartRate: restingHR,
            sleepHours: lastNightSleep,
            latestWeightKg: weight
        )
    }

    func fetchRecentWorkouts() async throws -> [WorkoutSummary] {
        try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: nil, limit: 10, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error {
                    if isNoDataError(error) {
                        continuation.resume(returning: [])
                        return
                    }
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

    // MARK: Weekly trends (feeds every chart in the Health tab, Dashboard, and Trends screens)

    func fetchWeeklyTrends() async throws -> WeeklyHealthTrends {
        async let activeEnergy = weeklyCumulativeSeries(identifier: .activeEnergyBurned, unit: .kilocalorie())
        async let steps = weeklyCumulativeSeries(identifier: .stepCount, unit: .count())
        async let exerciseMinutes = weeklyCumulativeSeries(identifier: .appleExerciseTime, unit: .minute())
        async let distance = weeklyCumulativeSeries(identifier: .distanceWalkingRunning, unit: .meter())
        async let restingHR = weeklyAverageSeries(identifier: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let sleep = weeklySleepSeries()
        async let weight = weeklyWeightSeries()

        return try await WeeklyHealthTrends(
            activeEnergy: activeEnergy,
            steps: steps,
            exerciseMinutes: exerciseMinutes,
            distanceMeters: distance,
            restingHeartRate: restingHR,
            sleepHours: sleep,
            weightKg: weight
        )
    }

    private func weekWindow() -> (start: Date, end: Date, calendar: Calendar) {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? end
        return (start, end, calendar)
    }

    private func weeklyCumulativeSeries(identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> [DailyMetricPoint] {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }
        let (start, end, _) = weekWindow()
        return try await dailyStatisticsSeries(type: type, unit: unit, option: .cumulativeSum, start: start, end: end)
    }

    private func weeklyAverageSeries(identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> [DailyMetricPoint] {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }
        let (start, end, _) = weekWindow()
        return try await dailyStatisticsSeries(type: type, unit: unit, option: .discreteAverage, start: start, end: end)
    }

    private func dailyStatisticsSeries(type: HKQuantityType, unit: HKUnit, option: HKStatisticsOptions, start: Date, end: Date) async throws -> [DailyMetricPoint] {
        var interval = DateComponents()
        interval.day = 1

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end),
                options: option,
                anchorDate: start,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, error in
                if let error {
                    if isNoDataError(error) {
                        continuation.resume(returning: [])
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                guard let results else {
                    continuation.resume(returning: [])
                    return
                }
                var points: [DailyMetricPoint] = []
                results.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let value = option == .discreteAverage
                        ? (statistics.averageQuantity()?.doubleValue(for: unit) ?? 0)
                        : (statistics.sumQuantity()?.doubleValue(for: unit) ?? 0)
                    points.append(DailyMetricPoint(date: statistics.startDate, value: value))
                }
                continuation.resume(returning: points)
            }
            healthStore.execute(query)
        }
    }

    private func weeklySleepSeries() async throws -> [DailyMetricPoint] {
        let (start, _, calendar) = weekWindow()
        var points: [DailyMetricPoint] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
            let hours = try await sleepHours(endingBefore: dayEnd)
            points.append(DailyMetricPoint(date: day, value: hours ?? 0))
        }
        return points
    }

    private func weeklyWeightSeries() async throws -> [DailyMetricPoint] {
        let (start, _, calendar) = weekWindow()
        var points: [DailyMetricPoint] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
            if let weight = try await latestBodyMassKg(before: dayEnd) {
                points.append(DailyMetricPoint(date: day, value: weight))
            }
        }
        return points
    }

    // MARK: Sleep

    /// Sums "asleep" duration in the ~20-hour window ending at `date`, so calling it with `.now`
    /// captures last night's sleep regardless of what time the person wakes up.
    private func sleepHours(endingBefore date: Date) async throws -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let windowStart = Calendar.current.date(byAdding: .hour, value: -20, to: date) ?? date
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: date)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    if isNoDataError(error) {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                let asleepSamples = (samples as? [HKCategorySample] ?? []).filter { sample in
                    isAsleepValue(sample.value)
                }
                guard !asleepSamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let totalSeconds = asleepSamples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds / 3600)
            }
            healthStore.execute(query)
        }
    }

    private func isAsleepValue(_ rawValue: Int) -> Bool {
        // HKCategoryValueSleepAnalysis: inBed = 0, asleepUnspecified = 1, awake = 2,
        // asleepCore = 3, asleepDeep = 4, asleepREM = 5. Anything "asleep*" counts; inBed/awake don't.
        [1, 3, 4, 5].contains(rawValue)
    }

    // MARK: Weight

    private func latestBodyMassKg(before date: Date = .now) async throws -> Double? {
        guard let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: nil, end: date)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: bodyMass, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    if isNoDataError(error) {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                let value = (samples as? [HKQuantitySample])?.first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    /// HealthKit throws HKError.errorNoData ("No data available for the specified predicate") for
    /// several query types — most commonly discrete statistics (average/min/max) — when literally
    /// zero samples match, e.g. no Apple Watch worn today so there's no heart rate data. This is
    /// an entirely normal, expected state, not a failure; every query below treats it as "no
    /// reading" rather than letting it fail the whole fetch (which is the bug that caused Health
    /// status to show "failed" with every metric blanked out, even ones with real data).
    private func isNoDataError(_ error: Error) -> Bool {
        (error as? HKError)?.code == .errorNoData
    }

    // MARK: Low-level helpers

    private func quantitySum(for type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error {
                    if isNoDataError(error) {
                        continuation.resume(returning: 0)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            healthStore.execute(query)
        }
    }

    private func quantityAverage(for type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error {
                    if isNoDataError(error) {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result?.averageQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func workoutCount(predicate: NSPredicate) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    if isNoDataError(error) {
                        continuation.resume(returning: 0)
                        return
                    }
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
