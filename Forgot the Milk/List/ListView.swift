import Foundation
import SwiftData
import SwiftUI

struct ListView: View {
    @Query private var lists: [HouseholdList]
    @Query private var categories: [Category]
    @Query private var items: [ListItem]

    @Environment(\.modelContext) private var modelContext
    @AppStorage("list.completedSection.expanded") private var completedExpanded = false

    @State private var deleteCandidate: ListItem?
    @State private var isConfirmingDelete = false
    @State private var isConfirmingClear = false

    private var list: HouseholdList? {
        lists.first
    }

    private var grouped: GroupedList {
        guard let list else {
            return GroupedList(sections: [], completed: [])
        }
        return ListGrouping.group(categories: categories, items: items, categoryOrder: list.categoryOrder)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Forgot the Milk")
        }
    }

    @ViewBuilder
    private var content: some View {
        if list == nil {
            Text("No list found")
                .foregroundStyle(.secondary)
        } else {
            listContent
        }
    }

    private var listContent: some View {
        List {
            ForEach(grouped.sections) { section in
                Section {
                    ForEach(section.items) { item in
                        neededRow(for: item)
                    }
                } header: {
                    Text("\(section.name) (\(section.neededCount))")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }

            if grouped.sections.isEmpty && grouped.completed.isEmpty {
                ContentUnavailableView(
                    "Your list is empty",
                    systemImage: "cart",
                    description: Text("Items will appear here once they are added.")
                )
            }

            if !grouped.completed.isEmpty {
                completedSection
            }
        }
        .accessibilityIdentifier("list-view")
        .confirmationDialog(
            deleteDialogMessage,
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                confirmDelete()
            }
            Button("Cancel", role: .cancel) {
                deleteCandidate = nil
            }
        }
        .confirmationDialog(
            "Clear \(grouped.completed.count) completed items?",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                if let list {
                    mutate { $0.clearCompleted(listID: list.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func neededRow(for item: ListItem) -> some View {
        ListRow(item: item) {
            mutate { $0.complete(item) }
        }
        .swipeActions(edge: .trailing) {
            Button {
                mutate { $0.complete(item) }
            } label: {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(.green)

            Button(role: .destructive) {
                pendingDelete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func completedRow(for item: ListItem) -> some View {
        ListRow(item: item) {
            mutate { $0.restore(item) }
        }
        .swipeActions(edge: .leading) {
            Button {
                mutate { $0.restore(item) }
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(.blue)
        }
    }

    private var completedSection: some View {
        Section {
            if completedExpanded {
                ForEach(grouped.completed) { item in
                    completedRow(for: item)
                }
            }
        } header: {
            Button {
                completedExpanded.toggle()
            } label: {
                HStack {
                    Text("Completed (\(grouped.completed.count))")
                        .font(.title3)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(completedExpanded ? 0 : -90))
                }
                .foregroundStyle(.secondary)
                .textCase(nil)
            }
            .accessibilityLabel("Completed items, \(grouped.completed.count)")
            .accessibilityHint(completedExpanded ? "Collapse completed items" : "Expand completed items")
            .accessibilityIdentifier("completed-section-toggle")
        } footer: {
            if grouped.completed.count > 0 {
                Button(role: .destructive) {
                    isConfirmingClear = true
                } label: {
                    Text("Clear completed")
                }
                .accessibilityIdentifier("clear-completed-button")
                .accessibilityHint("Permanently removes all completed items")
            }
        }
    }

    private var deleteDialogMessage: String {
        if let name = deleteCandidate?.name {
            return "Delete \(name)?"
        }
        return "Delete item?"
    }

    private func pendingDelete(_ item: ListItem) {
        deleteCandidate = item
        isConfirmingDelete = true
    }

    private func confirmDelete() {
        if let item = deleteCandidate {
            mutate { $0.delete(item) }
        }
        deleteCandidate = nil
    }

    private func mutate(_ body: (ItemUseCases) -> Void) {
        let useCases = ItemUseCases(context: modelContext)
        body(useCases)
    }
}
