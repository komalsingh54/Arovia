//
//  OnboardingView.swift
//  Arovia
//
//  First-launch flow only — gated by @AppStorage("hasCompletedOnboarding") in ContentView.
//  A short feature tour (Welcome, Health, Activity, Meals, Sleep, Insights) using the app's
//  own illustration set, then the two functional steps: connect Health, set starting targets.
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
                tourPage(image: "Health", title: "Know your health", subtitle: "Steps, heart rate, sleep, and more — synced automatically from Apple Health.", next: 2).tag(1)
                tourPage(image: "Activity", title: "Move with purpose", subtitle: "Every workout counted, whether it's from your Watch or logged by hand.", next: 3).tag(2)
                tourPage(image: "Meals", title: "Fuel your day", subtitle: "Log meals in seconds and see how they add up against your targets.", next: 4).tag(3)
                tourPage(image: "Sleep", title: "Rest and recover", subtitle: "Sleep is part of the picture too, not an afterthought.", next: 5).tag(4)
                tourPage(image: "Insights", title: "Insights that guide you", subtitle: "Not just charts — plain-language suggestions for what to do next.", next: 6).tag(5)
                connectHealthPage.tag(6)
                goalsPage.tag(7)
                donePage.tag(8)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .background(AppTheme.screenBackground)
        .fontDesign(.rounded)
    }

    private var welcomePage: some View {
        OnboardingPage(
            imageName: "Welcome",
            title: "Welcome to Arovia",
            subtitle: "Your activity, nutrition, and journal, brought together with insights that actually tell you what to do next.",
            primaryTitle: "Get Started",
            primaryAction: { withAnimation { page = 1 } }
        )
    }

    private func tourPage(image: String, title: String, subtitle: String, next: Int) -> some View {
        OnboardingPage(
            imageName: image,
            title: title,
            subtitle: subtitle,
            primaryTitle: "Next",
            primaryAction: { withAnimation { page = next } }
        )
    }

    private var connectHealthPage: some View {
        OnboardingPage(
            imageName: "Health",
            title: "Connect Apple Health",
            subtitle: "Arovia reads your steps, workouts, heart rate, and sleep from Health to build your dashboard. You can change this anytime in Settings.",
            primaryTitle: isConnectingHealth ? "Connecting…" : "Connect Health",
            primaryAction: {
                Task {
                    isConnectingHealth = true
                    await healthStore.requestAuthorization()
                    isConnectingHealth = false
                    withAnimation { page = 7 }
                }
            },
            secondaryTitle: "Skip for now",
            secondaryAction: { withAnimation { page = 7 } }
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
                withAnimation { page = 8 }
            }
            .buttonStyle(.appPrimary)
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

/// Either a real illustration (`imageName`, from Assets.xcassets/Onboarding) or an SF Symbol
/// fallback (`systemImage`, used for the Done page which has no matching illustration) —
/// exactly one should be provided.
private struct OnboardingPage: View {
    var imageName: String?
    var systemImage: String?
    let title: String
    let subtitle: String
    let primaryTitle: String
    let primaryAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.tint)
            }
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
                .buttonStyle(.appPrimary)
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
