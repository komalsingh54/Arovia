//
//  OnboardingView.swift
//  Arovia
//
//  First-launch flow only — gated by @AppStorage("hasCompletedOnboarding") in ContentView.
//  Four short steps rather than a long form: welcome, connect Health (optional, skippable),
//  set starting targets (with a nudge toward personalized suggestions once Health is connected
//  since that unlocks the same 7-day-average calculation Goals already uses), done.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var localStore: LocalStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("dailyCalorieTarget") private var dailyCalorieTarget = 2_000.0
    @AppStorage("dailyWaterTargetMl") private var dailyWaterTarget = 2_000.0

    @State private var page = 0
    @State private var stepGoal = 10_000.0
    @State private var isConnectingHealth = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                connectHealthPage.tag(1)
                goalsPage.tag(2)
                donePage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .background(AppTheme.screenBackground)
    }

    private var welcomePage: some View {
        OnboardingPage(
            systemImage: "sparkles",
            title: "Welcome to Arovia",
            subtitle: "Your activity, nutrition, and journal, brought together with insights that actually tell you what to do next.",
            primaryTitle: "Get Started",
            primaryAction: { withAnimation { page = 1 } }
        )
    }

    private var connectHealthPage: some View {
        OnboardingPage(
            systemImage: "heart.text.square.fill",
            title: "Connect Apple Health",
            subtitle: "Arovia reads your steps, workouts, heart rate, and sleep from Health to build your dashboard. You can change this anytime in Settings.",
            primaryTitle: isConnectingHealth ? "Connecting…" : "Connect Health",
            primaryAction: {
                Task {
                    isConnectingHealth = true
                    await healthStore.requestAuthorization()
                    isConnectingHealth = false
                    withAnimation { page = 2 }
                }
            },
            secondaryTitle: "Skip for now",
            secondaryAction: { withAnimation { page = 2 } }
        )
    }

    private var goalsPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "target")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.tint)
            Text("Set your starting targets")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)
            Text("Rough numbers are fine — everything here can be changed later, and goals get smarter suggestions once Arovia has a week of your data.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 16) {
                targetRow(icon: "figure.walk", title: "Daily steps", value: $stepGoal, step: 500, unit: "steps")
                targetRow(icon: "flame.fill", title: "Daily calories", value: $dailyCalorieTarget, step: 50, unit: "kcal")
                targetRow(icon: "drop.fill", title: "Daily water", value: $dailyWaterTarget, step: 250, unit: "ml")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button("Continue") {
                localStore.add(goal: FitnessGoal(title: "Daily Steps", targetValue: stepGoal, unit: "steps", metric: .steps))
                withAnimation { page = 3 }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.tint)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private var donePage: some View {
        OnboardingPage(
            systemImage: "checkmark.circle.fill",
            title: "You're all set",
            subtitle: "Log a meal, add a journal entry, or just check the Dashboard — everything updates as you go.",
            primaryTitle: "Start Using Arovia",
            primaryAction: { hasCompletedOnboarding = true }
        )
    }

    private func targetRow(icon: String, title: String, value: Binding<Double>, step: Double, unit: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Stepper(value: value, in: step...(step * 100), step: step) {
                Text("\(Int(value.wrappedValue)) \(unit)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .fixedSize()
        }
        .padding()
        .softCard(radius: 16)
    }
}

private struct OnboardingPage: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let primaryTitle: String
    let primaryAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.tint)
            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button(primaryTitle, action: primaryAction)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.tint)
                .padding(.horizontal, 32)

            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(.bottom, 40)
    }
}
