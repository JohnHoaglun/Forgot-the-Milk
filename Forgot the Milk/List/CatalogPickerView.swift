import Foundation
import SwiftData
import SwiftUI

struct CatalogPickerView: View {
    @Query private var lists: [HouseholdList]
    @Query private var categories: [Category]
    @Query private var catalogItems: [CatalogItem]
    @Query private var items: [ListItem]

    @State private var searchQuery = ""

    private struct PickerEntry: Identifiable {
        enum Status {
            case notAdded
            case alreadyNeeded
            case completed
        }

        let catalogItem: CatalogItem
        let status: Status

        var id: UUID { catalogItem.id }
    }

    private var list: HouseholdList? {
        lists.first
    }

    var body: some View {
        List {
            if let list {
                NavigationLink {
                    ItemFormView(mode: .addCustom)
                } label: {
                    Label("Add a custom item", systemImage: "plus.circle")
                        .accessibilityIdentifier("custom-item-entry")
                }
            }

            ForEach(sections(in: list)) { section in
                Section(section.name) {
                    ForEach(section.entries) { entry in
                        entryRow(for: entry)
                    }
                }
            }

            if let list, allSections(in: list).isEmpty {
                ContentUnavailableView.search
            }
        }
        .searchable(text: $searchQuery, prompt: "Search the catalog")
        .navigationTitle("Add Item")
        .accessibilityIdentifier("catalog-picker")
    }

    private struct PickerSection: Identifiable {
        let name: String
        let entries: [PickerEntry]

        var id: String { name }
    }

    private func sections(in list: HouseholdList?) -> [PickerSection] {
        allSections(in: list).filter { section in
            section.entries.contains { CatalogSearch.matches(query: searchQuery, label: $0.catalogItem.name) }
        }
    }

    private func allSections(in list: HouseholdList?) -> [PickerSection] {
        guard let list else { return [] }
        let ordered = ListGrouping.orderedCategories(categories, order: list.categoryOrder)
        let listItems = items.filter { $0.listID == list.id }

        let statusByID: [UUID: PickerEntry.Status] = Dictionary(
            uniqueKeysWithValues: catalogItems.map { catalogItem in
                let matches = listItems.filter { $0.catalogItemID == catalogItem.id }
                let status: PickerEntry.Status
                if matches.contains(where: { $0.state == .needed }) {
                    status = .alreadyNeeded
                } else if matches.contains(where: { $0.state == .completed }) {
                    status = .completed
                } else {
                    status = .notAdded
                }
                return (catalogItem.id, status)
            }
        )

        let entriesByCategory = Dictionary(grouping: catalogItems, by: \.categoryID)

        return ordered.compactMap { category -> PickerSection? in
            guard let bucket = entriesByCategory[category.id], !bucket.isEmpty else { return nil }
            let sorted = bucket.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return PickerSection(
                name: category.name,
                entries: sorted.map { PickerEntry(catalogItem: $0, status: statusByID[$0.id] ?? .notAdded) }
            )
        }
    }

    @ViewBuilder
    private func entryRow(for entry: PickerEntry) -> some View {
        switch entry.status {
        case .alreadyNeeded:
            rowContent(for: entry)
                .accessibilityIdentifier("picker-row-\(entry.id)")
        case .notAdded, .completed:
            NavigationLink {
                ItemFormView(mode: .addCatalog(entry.catalogItem))
            } label: {
                rowContent(for: entry)
                    .accessibilityIdentifier("picker-row-\(entry.id)")
            }
        }
    }

    private func rowContent(for entry: PickerEntry) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.catalogItem.name)

                if let summary = summary(for: entry.catalogItem) {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            switch entry.status {
            case .alreadyNeeded:
                Text("Added")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            case .completed:
                Text("Completed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            case .notAdded:
                EmptyView()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: entry))
    }

    private func accessibilityLabel(for entry: PickerEntry) -> String {
        let base = entry.catalogItem.name
        switch entry.status {
        case .alreadyNeeded:
            return "\(base), already added"
        case .completed:
            return "\(base), completed, tap to add again"
        case .notAdded:
            return base
        }
    }

    private func summary(for catalogItem: CatalogItem) -> String? {
        var parts: [String] = []
        let quantityPart = [catalogItem.defaultQuantity, catalogItem.defaultUnit].compactMap { $0 }.joined(separator: " ")
        if !quantityPart.isEmpty {
            parts.append(quantityPart)
        }
        if let note = catalogItem.defaultNote, !note.isEmpty {
            parts.append(note)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }
}
