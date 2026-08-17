//
//  MoreView.swift
//  Arovia
//
//  Replaces iOS's automatic "More" overflow list (which is what was actually rendering the
//  plain, undesigned screen in the last review — TabView auto-generates it once there are more
//  than 5 tabItems). This is a real, designed screen instead.
//

import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("More")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("Everything else, in one place.")
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    VStack(spacing: 10) {
                        MoreRow(title: "Journal", subtitle: "Notes on how workouts and days felt", systemImage: "note.text", tint: AppTheme.glowExercise) { JournalView() }
                        MoreRow(title: "Goals", subtitle: "Targets you're tracking toward", systemImage: "target", tint: AppTheme.glowSteps) { GoalsView() }
                        MoreRow(title: "Profile", subtitle: "Streaks and account details", systemImage: "person.crop.circle", tint: AppTheme.glowEnergy) { ProfileView() }
                        MoreRow(title: "Settings", subtitle: "Units, Health connection, privacy", systemImage: "gearshape", tint: AppTheme.secondaryText) { SettingsView() }
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .clearsFloatingTabBar()
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct MoreRow<Destination: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(tint.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedText)
            }
            .padding(14)
            .softCard(radius: 18)
        }
        .buttonStyle(.pressable)
        .simultaneousGesture(TapGesture().onEnded { Haptic.light() })
    }
}
