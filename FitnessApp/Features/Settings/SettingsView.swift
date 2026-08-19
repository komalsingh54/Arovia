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

                    MealRemindersSection()

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

private struct MealRemindersSection: View {
    @EnvironmentObject private var mealReminderScheduler: MealReminderScheduler
    @EnvironmentObject private var localStore: LocalStore

    @AppStorage(MealReminderSettings.Keys.masterEnabled) private var isEnabled = false
    @AppStorage(MealReminderSettings.Keys.enabled(.breakfast)) private var breakfastEnabled = true
    @AppStorage(MealReminderSettings.Keys.enabled(.lunch)) private var lunchEnabled = true
    @AppStorage(MealReminderSettings.Keys.enabled(.dinner)) private var dinnerEnabled = true
    @AppStorage(MealReminderSettings.Keys.hour(.breakfast)) private var breakfastHour = MealReminderSettings.defaultHours[.breakfast]!
    @AppStorage(MealReminderSettings.Keys.minute(.breakfast)) private var breakfastMinute = 0
    @AppStorage(MealReminderSettings.Keys.hour(.lunch)) private var lunchHour = MealReminderSettings.defaultHours[.lunch]!
    @AppStorage(MealReminderSettings.Keys.minute(.lunch)) private var lunchMinute = 0
    @AppStorage(MealReminderSettings.Keys.hour(.dinner)) private var dinnerHour = MealReminderSettings.defaultHours[.dinner]!
    @AppStorage(MealReminderSettings.Keys.minute(.dinner)) private var dinnerMinute = 0

    var body: some View {
        SettingsGroup(title: "Meal Reminders") {
            Toggle("Remind me to log meals", isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    isEnabled = newValue
                    if newValue {
                        Task {
                            if mealReminderScheduler.authorizationStatus != .authorized {
                                await mealReminderScheduler.requestAuthorization()
                            }
                            await refreshSchedule()
                        }
                    } else {
                        Task { await refreshSchedule() }
                    }
                }
            ))
            .tint(AppTheme.tint)

            if isEnabled {
                if mealReminderScheduler.authorizationStatus == .denied {
                    Text("Notifications are turned off for Arovia in iOS Settings, so reminders won't appear. Enable them in Settings → Notifications → Arovia.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.energy)
                }

                mealRow(title: "Breakfast", enabled: $breakfastEnabled, hour: $breakfastHour, minute: $breakfastMinute)
                mealRow(title: "Lunch", enabled: $lunchEnabled, hour: $lunchHour, minute: $lunchMinute)
                mealRow(title: "Dinner", enabled: $dinnerEnabled, hour: $dinnerHour, minute: $dinnerMinute)

                Text("Reminders only fire for meals you haven't logged yet — log breakfast and today's breakfast reminder won't appear.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .task { await refreshSchedule() }
    }

    private func mealRow(title: String, enabled: Binding<Bool>, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack {
            Toggle(title, isOn: Binding(
                get: { enabled.wrappedValue },
                set: { enabled.wrappedValue = $0; Task { await refreshSchedule() } }
            ))
            .tint(AppTheme.tint)

            if enabled.wrappedValue {
                DatePicker(
                    "",
                    selection: timeBinding(hour: hour, minute: minute),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .fixedSize()
                .onChange(of: hour.wrappedValue) { Task { await refreshSchedule() } }
                .onChange(of: minute.wrappedValue) { Task { await refreshSchedule() } }
            }
        }
    }

    /// AppStorage doesn't support Date directly, so hour/minute are stored as separate Ints
    /// and this bridges them to the Date binding DatePicker needs.
    private func timeBinding(hour: Binding<Int>, minute: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = hour.wrappedValue
                components.minute = minute.wrappedValue
                return Calendar.current.date(from: components) ?? .now
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                hour.wrappedValue = components.hour ?? hour.wrappedValue
                minute.wrappedValue = components.minute ?? minute.wrappedValue
            }
        )
    }

    private func refreshSchedule() async {
        await mealReminderScheduler.refreshAuthorizationStatus()
        let settings = MealReminderSettings.current()
        let todaysTypes = Set(
            localStore.mealEntries
                .filter { Calendar.current.isDateInToday($0.date) }
                .map(\.mealType)
        )
        await mealReminderScheduler.refreshSchedule(settings: settings, todaysLoggedMealTypes: todaysTypes)
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
