//
//  InsightsView.swift
//  Arovia
//

import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var localStore: LocalStore

    var body: some View {
        let analytics = JournalAnalytics(entries: localStore.journalEntries)
        let maximumCount = max(analytics.categoryCounts.map(\.count).max() ?? 0, 1)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("This Week")
                    .font(.largeTitle.weight(.bold))

                HStack(spacing: 12) {
                    InsightCard(value: analytics.entriesThisWeek.count.formatted(), label: "Entries", icon: "note.text")
                    InsightCard(value: analytics.currentStreak.formatted(), label: "Day streak", icon: "flame.fill")
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Journal breakdown")
                        .font(.title3.weight(.bold))

                    ForEach(analytics.categoryCounts, id: \.category) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(item.category.title, systemImage: item.category.systemImage)
                                Spacer()
                                Text(item.count.formatted())
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            ProgressView(value: Double(item.count), total: Double(maximumCount))
                                .tint(AppTheme.tint)
                        }
                    }
                }
                .padding()
                .softCard(radius: 20)
            }
            .padding()
        }
        .background(AppTheme.screenBackground)
        .clearsFloatingTabBar()
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InsightCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.tint)
            Text(value)
                .font(.title.bold())
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .softCard(radius: 20)
    }
}
