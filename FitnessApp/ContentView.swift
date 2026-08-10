//
//  ContentView.swift
//  Arovia
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var healthStore: HealthStore

    var body: some View {
        VStack(spacing: 0) {
            HealthPermissionBanner()

            TabView {
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "square.grid.2x2.fill")
                    }

                ActivityView()
                    .tabItem {
                        Label("Activity", systemImage: "figure.walk")
                    }

                HealthOverviewView()
                    .tabItem {
                        Label("Health", systemImage: "heart.fill")
                    }

                MealsView()
                    .tabItem {
                        Label("Meals", systemImage: "fork.knife")
                    }

                JournalView()
                    .tabItem {
                        Label("Journal", systemImage: "note.text")
                    }

                GoalsView()
                    .tabItem {
                        Label("Goals", systemImage: "target")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            .tint(AppTheme.tint)
        }
        .background(AppTheme.screenBackground)
    }
}
