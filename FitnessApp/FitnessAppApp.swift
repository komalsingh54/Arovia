//
//  AroviaApp.swift
//  Arovia
//
//  Created by Komal Singh on 08/08/2026.
//

import SwiftUI

@main
struct FitnessAppApp: App {
    @StateObject private var healthStore = HealthStore()
    @StateObject private var localStore = LocalStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthStore)
                .environmentObject(localStore)
                .preferredColorScheme(.dark)
        }
    }
}
