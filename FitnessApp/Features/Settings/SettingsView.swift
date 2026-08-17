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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Settings")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppTheme.primaryText)

                    NavigationLink { ProfileView() } label: {
                        SettingsRow(title: "Profile", systemImage: "person.crop.circle")
                    }
                    .buttonStyle(.plain)

                    SettingsGroup(title: "Preferences") {
                        Toggle("Use metric units", isOn: $usesMetricUnits)
                            .tint(AppTheme.tint)
                    }

                    SettingsGroup(title: "Health") {
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
                        .foregroundStyle(AppTheme.tint)
                        .font(.subheadline.weight(.semibold))
                    }

                    SettingsGroup(title: "iCloud Sync") {
                        LabeledContent("Goals, journal & meals", value: FeatureFlags.cloudKitEnabled ? "Enabled" : "Local only")
                        Button(isSyncing ? "Syncing…" : "Sync Now") {
                            Task {
                                isSyncing = true
                                await localStore.syncWithCloud()
                                isSyncing = false
                            }
                        }
                        .disabled(isSyncing || !FeatureFlags.cloudKitEnabled)
                        .foregroundStyle(FeatureFlags.cloudKitEnabled ? AppTheme.tint : AppTheme.mutedText)
                        .font(.subheadline.weight(.semibold))
                    }

                    SettingsGroup(title: "Privacy") {
                        Text("Health data is read only after you grant permission. Personal goals and journal entries stay on this device and sync privately to your iCloud account.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    SettingsGroup(title: "About") {
                        LabeledContent("App", value: "Arovia")
                        LabeledContent("Version", value: Bundle.main.releaseVersionNumber)
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .clearsFloatingTabBar()
            .navigationBarTitleDisplayMode(.inline)
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

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.mutedText)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .foregroundStyle(AppTheme.primaryText)
            .padding()
            .softCard(radius: 18)
        }
    }
}

private struct SettingsRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.tint)
                .frame(width: 34, height: 34)
                .background(AppTheme.elevatedCardBackground, in: Circle())
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.mutedText)
        }
        .padding()
        .softCard(radius: 18)
    }
}

private extension Bundle {
    var releaseVersionNumber: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
