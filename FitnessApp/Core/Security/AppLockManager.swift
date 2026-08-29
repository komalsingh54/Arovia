//
//  AppLockManager.swift
//  Arovia
//
//  Optional Face ID/passcode gate (Settings > "Require Face ID to open Arovia", off by
//  default) — Arovia now holds weight, meals, and journal entries, which can be more personal
//  than people expect when they start a fitness app, and nothing previously stopped anyone
//  who picked up an unlocked phone from opening it straight to that data.
//

import Foundation
import Combine
import LocalAuthentication

@MainActor
final class AppLockManager: ObservableObject {
    @Published var isUnlocked = false
    @Published private(set) var lastError: String?

    /// Whether this device can even do device-owner authentication (biometrics or a passcode).
    var isAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func authenticate(reason: String = "Unlock Arovia") async {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode or biometrics set up on this device at all — don't lock the person
            // out of their own data over a device configuration Arovia can't fix for them.
            isUnlocked = true
            return
        }

        let success = await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }

        isUnlocked = success
        lastError = success ? nil : "Authentication was cancelled or failed."
    }

    /// Called when the app backgrounds — the next foreground will need a fresh authenticate().
    func lock() {
        isUnlocked = false
    }
}
