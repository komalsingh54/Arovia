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

            // Exactly 5 tabs on purpose — iOS auto-collapses anything past 5 into a stock
            // "More" list (that's what was rendering the undesigned overflow screen before).
            // Journal/Goals/Profile/Settings now live in our own MoreView instead.
            TabView {
                DashboardView()
                    .tabItem { Image(systemName: "square.grid.2x2.fill") }

                ActivityView()
                    .tabItem { Image(systemName: "figure.walk") }

                HealthOverviewView()
                    .tabItem { Image(systemName: "heart.fill") }

                MealsView()
                    .tabItem { Image(systemName: "fork.knife") }

                MoreView()
                    .tabItem { Image(systemName: "ellipsis") }
            }
            .tint(AppTheme.tint)
        }
        .background(AppTheme.screenBackground)
    }
}
