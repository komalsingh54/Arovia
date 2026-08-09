//
//  HealthKitObserverService.swift
//  Arovia
//
//  Registers HKObserverQuery for every metric the app reads and enables background delivery,
//  so HealthStore refreshes automatically whenever new data lands in Health/Fitness — no manual
//  pull-to-refresh required. Requires the "Background Delivery" toggle under the HealthKit
//  capability in Signing & Capabilities (adds com.apple.developer.healthkit.background-delivery).
//

import Foundation

#if canImport(HealthKit)
import HealthKit

@MainActor
final class HealthKitObserverService {
    private let healthStore: HKHealthStore
    private var activeQueries: [HKObserverQuery] = []
    private var onChange: (() -> Void)?
    private var isObserving = false

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    /// Idempotent — safe to call every time authorization succeeds; only registers once.
    func startObserving(onChange: @escaping () -> Void) {
        guard !isObserving else { return }
        isObserving = true
        self.onChange = onChange

        for type in HealthKitService.observableSampleTypes {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
                defer { completionHandler() }
                guard error == nil else { return }
                Task { @MainActor in
                    self?.onChange?()
                }
            }
            healthStore.execute(query)
            activeQueries.append(query)

            healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if !success {
                    // Background delivery couldn't be enabled (e.g. capability not configured yet).
                    // The app still updates on foreground refresh / pull-to-refresh either way.
                }
            }
        }
    }

    func stopObserving() {
        for query in activeQueries {
            healthStore.stop(query)
        }
        activeQueries.removeAll()
        isObserving = false
    }
}
#endif
