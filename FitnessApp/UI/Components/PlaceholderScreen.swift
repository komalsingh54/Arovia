//
//  PlaceholderScreen.swift
//  Arovia
//

import SwiftUI

struct PlaceholderScreen: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text(message)
            )
            .navigationTitle(title)
        }
    }
}

struct SectionCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .softCard()
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.tint)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.primaryText)
            Text(unit)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .softCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value) \(unit)")
    }
}
