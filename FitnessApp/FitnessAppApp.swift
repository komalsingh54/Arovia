//
//  AroviaApp.swift
//  Arovia
//
//  Created by Komal Singh on 08/08/2026.
//

import SwiftUI

@main
struct FitnessAppApp: App {
    private let dependencies: AppDependencies

    @StateObject private var healthStore = HealthStore()
    @StateObject private var localStore: LocalStore
    @StateObject private var mealReminderScheduler = MealReminderScheduler()
    @StateObject private var wellnessReminderScheduler = WellnessReminderScheduler()
    @StateObject private var motionActivityDetector = MotionActivityDetector()

    init() {
        let dependencies = AppDependencies()
        self.dependencies = dependencies
        _localStore = StateObject(wrappedValue: LocalStore(dependencies: dependencies))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthStore)
                .environmentObject(localStore)
                .environmentObject(mealReminderScheduler)
                .environmentObject(wellnessReminderScheduler)
                .environmentObject(motionActivityDetector)
                // No forced color scheme — follows the device's Light/Dark setting.
        }
    }
}
