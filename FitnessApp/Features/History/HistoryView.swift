//
//  HistoryView.swift
//  Arovia
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var localStore: LocalStore
    @State private var searchText = ""

    var body: some View {
        List {
            if filteredEntries.isEmpty {
                ContentUnavailableView("No history yet", systemImage: "clock.arrow.circlepath", description: Text("Journal entries will appear here."))
            } else {
                ForEach(filteredEntries) { entry in
                    HStack {
                        Label(entry.title, systemImage: entry.category.systemImage)
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer()
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(AppTheme.mutedText)
                    }
                    .listRowBackground(AppTheme.cardBackground)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenBackground)
        .clearsFloatingTabBar()
        .navigationTitle("History")
        .searchable(text: $searchText, prompt: "Search journal")
    }

    private var filteredEntries: [JournalEntry] {
        guard !searchText.isEmpty else { return localStore.journalEntries }
        return localStore.journalEntries.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.details.localizedCaseInsensitiveContains(searchText) ||
            $0.category.title.localizedCaseInsensitiveContains(searchText)
        }
    }
}
