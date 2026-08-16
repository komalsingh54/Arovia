//
//  LiveMotion.swift
//  Arovia
//
//  Shared motion primitives so "alive" feels consistent across the app rather than one-off
//  animations bolted onto individual screens. The heartbeat pulse motif echoes the app icon.
//

import SwiftUI
import UIKit

// MARK: - Animated progress ring

/// A progress ring that springs to its new value instead of snapping — used everywhere a ring
/// shows progress (Meals goal rings, Trends activity rings, Health metric rings).
struct AnimatedRing: View {
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 8
    /// Briefly scales and glows when progress crosses 100% — a small reward moment.
    var celebratesCompletion: Bool = false

    @State private var animatedProgress: Double = 0
    @State private var didCelebrate = false
    @State private var celebrationScale: CGFloat = 1

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .scaleEffect(celebrationScale)
        .onAppear { animatedProgress = min(max(progress, 0), 1) }
        .onChange(of: progress) { _, newValue in
            let clamped = min(max(newValue, 0), 1)
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                animatedProgress = clamped
            }
            if celebratesCompletion && clamped >= 1 && !didCelebrate {
                didCelebrate = true
                celebrate()
            } else if clamped < 1 {
                didCelebrate = false
            }
        }
    }

    private func celebrate() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
            celebrationScale = 1.15
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.15)) {
            celebrationScale = 1
        }
    }
}

// MARK: - Counting numbers

/// Rolling "odometer" number animation using SwiftUI's built-in numeric content transition —
/// values tick up/down smoothly instead of snapping whenever the underlying data changes.
struct AnimatedNumberText: View {
    let value: Double
    var precision: Int = 0
    var suffix: String = ""

    var body: some View {
        Text("\(value.formatted(.number.precision(.fractionLength(precision))))\(suffix)")
            .contentTransition(.numericText(value: value))
            .animation(.snappy(duration: 0.6), value: value)
    }
}

struct AnimatedIntText: View {
    let value: Int
    var suffix: String = ""

    var body: some View {
        Text("\(value)\(suffix)")
            .contentTransition(.numericText(value: Double(value)))
            .animation(.snappy(duration: 0.6), value: value)
    }
}

// MARK: - Heartbeat pulse indicator

/// A small pulsing dot echoing the app icon's heartbeat motif — used to mark "live"/auto-syncing
/// data so the connection to Health feels active rather than static.
struct PulseIndicator: View {
    var color: Color = AppTheme.tint
    var size: CGFloat = 7

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.4))
                .frame(width: size, height: size)
                .scaleEffect(isPulsing ? 2.6 : 1)
                .opacity(isPulsing ? 0 : 0.9)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Pressable feedback

/// Subtle scale+fade press feedback for buttons and cards — makes tapping feel tactile instead
/// of purely functional. Apply with `.buttonStyle(.pressable)`.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Staggered entrance

/// Fades + slides a view in on appear, delayed by index — applied to grids/lists so content
/// arrives in a cascade rather than popping in all at once.
private struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(Double(index) * 0.06)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredAppear(_ index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}

// MARK: - Haptics

enum Haptic {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
