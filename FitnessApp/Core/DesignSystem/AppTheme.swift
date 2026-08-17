//
//  AppTheme.swift
//  Arovia
//

import SwiftUI
import UIKit

/// "Calm" direction — adaptive to the system's Light/Dark setting, patterned after soft,
/// glowy health-app references: near-white (or near-black) canvas, cards defined by a soft
/// shadow rather than a border, one quiet accent for everyday UI, and three warm "glow"
/// colors reserved for hero stats (steps, energy, exercise) so they read like the glucose
/// blob in the reference — a focal point, not another flat card.
enum AppTheme {

    private static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    // MARK: Surfaces

    static let screenBackground = adaptive(
        light: Color(red: 0.965, green: 0.963, blue: 0.976),
        dark: Color(red: 0.055, green: 0.043, blue: 0.102)
    )
    static let cardBackground = adaptive(
        light: Color.white,
        dark: Color(red: 0.118, green: 0.090, blue: 0.208)
    )
    static let elevatedCardBackground = adaptive(
        light: Color(red: 0.945, green: 0.941, blue: 0.965),
        dark: Color(red: 0.157, green: 0.122, blue: 0.271)
    )

    /// Card shadow — the thing that actually separates a card from the page in the reference,
    /// standing in for the border most screens used before.
    static let cardShadow = adaptive(
        light: Color.black.opacity(0.08),
        dark: Color.black.opacity(0.35)
    )

    // MARK: Text

    static let primaryText = adaptive(
        light: Color(red: 0.11, green: 0.10, blue: 0.13),
        dark: Color(red: 0.957, green: 0.949, blue: 0.980)
    )
    static let secondaryText = adaptive(
        light: Color(red: 0.42, green: 0.41, blue: 0.46),
        dark: Color(red: 0.612, green: 0.576, blue: 0.722)
    )
    static let mutedText = secondaryText.opacity(0.65)

    static let border = adaptive(light: Color.black.opacity(0.05), dark: Color.white.opacity(0.07))

    // MARK: Accent

    /// The one everyday accent — buttons, links, selected states. Kept quiet on purpose so it
    /// doesn't compete with the glow colors below.
    static let tint = adaptive(
        light: Color(red: 0.435, green: 0.635, blue: 0.145),
        dark: Color(red: 0.776, green: 0.949, blue: 0.306)
    )
    static let borderStrong = tint.opacity(0.35)

    // MARK: Glow colors — reserved for hero stats only (Dashboard carousel, ring accents)

    static let glowSteps = tint
    static let glowEnergy = Color(red: 1.00, green: 0.478, blue: 0.271)
    static let glowExercise = adaptive(
        light: Color(red: 0.435, green: 0.373, blue: 0.827),
        dark: Color(red: 0.596, green: 0.541, blue: 0.878)
    )
    /// Kept for any screen still referencing the old "energy" name.
    static let energy = glowEnergy
    static let secondaryAccent = glowExercise

    // MARK: Activity rings — matches Apple Fitness' canonical Move/Exercise/Stand mapping
    // (red outer, green middle, blue inner) so the rings read instantly instead of needing
    // a legend to figure out which color means what.
    static let ringMove = Color(red: 1.00, green: 0.176, blue: 0.333)
    static let ringExercise = Color(red: 0.635, green: 0.910, blue: 0.169)
    static let ringStand = Color(red: 0.106, green: 0.910, blue: 0.910)

    /// Soft radial glow behind a hero stat, echoing the blurred blob in the reference.
    static func glow(_ color: Color) -> RadialGradient {
        RadialGradient(
            colors: [color.opacity(0.35), color.opacity(0.05), .clear],
            center: .center, startRadius: 4, endRadius: 140
        )
    }

    /// Extra bottom clearance so scroll content never sits under the iOS 26 floating tab bar.
    static let tabBarClearance: CGFloat = 96
}

extension View {
    /// Apply to the outermost ScrollView/List of every tab root so content isn't clipped by
    /// the floating pill tab bar (the bug visible on Trends, Nutrition, and More today).
    func clearsFloatingTabBar() -> some View {
        safeAreaInset(edge: .bottom) { Color.clear.frame(height: AppTheme.tabBarClearance) }
    }

    /// Standard quiet card treatment — soft shadow instead of a border, matching the reference.
    func softCard(radius: CGFloat = 20) -> some View {
        self
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: AppTheme.cardShadow, radius: 16, x: 0, y: 6)
    }
}
