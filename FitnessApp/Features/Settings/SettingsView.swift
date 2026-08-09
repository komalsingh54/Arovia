//
//  SettingsView.swift
//  Arovia
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("usesMetricUnits") private var usesMetricUnits = true
    @EnvironmentObject private var healthStore: HealthStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Toggle("Use metric units", isOn: $usesMetricUnits)
                }
                Section("Health") {
                    LabeledContent("Connection", value: healthStatus)
                    Button(healthStore.status == .ready ? "Refresh Health Data" : "Connect Health") {
                        Task {
                            if healthStore.status == .ready {
                                await healthStore.refresh()
                            } else {
                                await healthStore.requestAuthorization()
                            }
                        }
                    }
                }
                Section("Privacy") {
                    Text("Health data is read only after you grant permission. Personal goals and journal entries stay on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("About") {
                    LabeledContent("App", value: "Arovia")
                    LabeledContent("Version", value: Bundle.main.releaseVersionNumber)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
            .navigationTitle("Settings")
        }
    }

    private var healthStatus: String {
        switch healthStore.status {
        case .ready: "Connected"
        case .loading: "Refreshing"
        case .unavailable: "Unavailable"
        case .denied: "Access needed"
        case .authorizationRequired: "Not connected"
        case .failed: "Try again"
        case .idle: "Not connected"
        }
    }
}

private extension Bundle {
    var releaseVersionNumber: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
