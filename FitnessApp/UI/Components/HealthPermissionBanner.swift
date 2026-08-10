//
//  HealthPermissionBanner.swift
//  Arovia
//
//  A persistent, app-wide banner (not buried in Settings) that names exactly which HealthKit
//  types haven't been granted yet and offers a one-tap fix. This is what "some health data isn't
//  allowed to connect" actually looks like from HealthKit's API — see HealthStore.refreshPendingPermissions.
//

import SwiftUI

struct HealthPermissionBanner: View {
    @EnvironmentObject private var healthStore: HealthStore
    @State private var isRequesting = false

    var body: some View {
        if !healthStore.pendingPermissionNames.isEmpty {
            Button {
                Task {
                    isRequesting = true
                    await healthStore.requestAuthorization()
                    isRequesting = false
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundStyle(AppTheme.energy)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(healthStore.pendingPermissionNames.count) health permission\(healthStore.pendingPermissionNames.count == 1 ? "" : "s") not connected")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(healthStore.pendingPermissionNames.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    if isRequesting {
                        ProgressView().tint(AppTheme.tint)
                    } else {
                        Text("Grant")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.screenBackground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.tint, in: Capsule())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .disabled(isRequesting)
            .background(AppTheme.cardBackground)
            .overlay(alignment: .bottom) {
                Rectangle().fill(AppTheme.border).frame(height: 0.5)
            }
        }
    }
}
