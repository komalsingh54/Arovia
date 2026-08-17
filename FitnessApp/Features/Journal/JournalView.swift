//
//  JournalView.swift
//  Arovia
//

import SwiftUI

struct JournalView: View {
    @EnvironmentObject private var localStore: LocalStore
    @State private var isAddingEntry = false
    @State private var entryToEdit: JournalEntry?

    var body: some View {
        NavigationStack {
            Group {
                if localStore.journalEntries.isEmpty {
                    ContentUnavailableView("No journal entries", systemImage: "note.text", description: Text("Record how a workout or day felt."))
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(localStore.journalEntries) { entry in
                                Button {
                                    entryToEdit = entry
                                } label: {
                                    JournalEntryRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        if let index = localStore.journalEntries.firstIndex(where: { $0.id == entry.id }) {
                                            localStore.deleteJournalEntries(at: IndexSet(integer: index))
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .background(AppTheme.screenBackground)
                    .clearsFloatingTabBar()
                }
            }
            .navigationTitle("Journal")
            .background(AppTheme.screenBackground)
            .toolbar { Button("Add", systemImage: "plus") { isAddingEntry = true } }
            .sheet(isPresented: $isAddingEntry) { JournalEditorView(entry: nil) }
            .sheet(item: $entryToEdit) { entry in JournalEditorView(entry: entry) }
        }
    }
}

private struct JournalEntryRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(entry.category.title, systemImage: entry.category.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.tint)
                Spacer()
                Text(entry.date, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
            }
            Text(entry.title)
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)
            if !entry.details.isEmpty {
                Text(entry.details)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .softCard(radius: 20)
    }
}

private struct JournalEditorView: View {
    let entry: JournalEntry?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localStore: LocalStore
    @State private var title: String
    @State private var details: String
    @State private var category: JournalCategory

    init(entry: JournalEntry?) {
        self.entry = entry
        _title = State(initialValue: entry?.title ?? "")
        _details = State(initialValue: entry?.details ?? "")
        _category = State(initialValue: entry?.category ?? .workout)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                Picker("Category", selection: $category) {
                    ForEach(JournalCategory.allCases) { category in
                        Label(category.title, systemImage: category.systemImage).tag(category)
                    }
                }
                TextField("Notes", text: $details, axis: .vertical)
                    .lineLimit(3...8)
            }
            .navigationTitle(entry == nil ? "New Entry" : "Edit Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let entry {
                            localStore.update(entry: entry.updating(title: title, details: details, category: category))
                        } else {
                            localStore.add(entry: JournalEntry(title: title, details: details, category: category))
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
