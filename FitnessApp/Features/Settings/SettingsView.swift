//
//  SettingsView.swift
//  Arovia
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("usesMetricUnits") private var usesMetricUnits = true
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var localStore: LocalStore
    @State private var isSyncing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
                }
                Section("Preferences") {
                    Toggle("Use metric units", isOn: $usesMetricUnits)
                }
                Section("Health") {
                    LabeledContent("Connection", value: healthStatus)
                    if let error = healthStore.lastErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(AppTheme.energy)
                    }
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
                Section("iCloud Sync") {
                    LabeledContent("Goals, journal & meals", value: FeatureFlags.cloudKitEnabled ? "Enabled" : "Local only")
                    Button(isSyncing ? "Syncing…" : "Sync Now") {
                        Task {
                            isSyncing = true
                            await localStore.syncWithCloud()
                            isSyncing = false
                        }
                    }
                    .disabled(isSyncing || !FeatureFlags.cloudKitEnabled)
                }
                Section("Privacy") {
                    Text("Health data is read only after you grant permission. Personal goals and journal entries stay on this device and sync privately to your iCloud account.")
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
