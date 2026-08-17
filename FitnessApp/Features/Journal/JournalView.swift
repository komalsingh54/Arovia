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
                    List {
                        ForEach(localStore.journalEntries) { entry in
                            Button {
                                entryToEdit = entry
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Label(entry.category.title, systemImage: entry.category.systemImage)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.tint)
                                        Spacer()
                                        Text(entry.date, format: .dateTime.day().month().year().hour().minute())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(entry.title).font(.headline).foregroundStyle(.primary)
                                    if !entry.details.isEmpty { Text(entry.details).foregroundStyle(.secondary) }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: localStore.deleteJournalEntries)
                    }
                    .scrollContentBackground(.hidden)
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
