//
//  AppLockScreen.swift
//  Arovia
//

import SwiftUI

struct AppLockScreen: View {
    @EnvironmentObject private var appLockManager: AppLockManager
    @State private var isAuthenticating = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "faceid")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.tint)
            Text("Arovia is locked")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)
            if let error = appLockManager.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Button(isAuthenticating ? "Checking…" : "Unlock") {
                Task {
                    isAuthenticating = true
                    await appLockManager.authenticate()
                    isAuthenticating = false
                }
            }
            .buttonStyle(.appPrimary)
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
            .disabled(isAuthenticating)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.screenBackground)
        .task {
            await appLockManager.authenticate()
        }
    }
}
