import Foundation
import SwiftData
import SwiftUI

struct MoveCatalogItemSheet: View {
    let item: CatalogItem
    let list: HouseholdList?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var categories: [Category]

    var body: some View {
        NavigationStack {
            List {
                ForEach(orderedCategories) { category in
                    let isCurrent = category.id == item.categoryID
                    Button {
                        guard !isCurrent else { return }
                        CatalogUseCases(context: modelContext).move(item, to: category.id)
                        dismiss()
                    } label: {
                        HStack {
                            Text(category.name)
                            Spacer()
                            if isCurrent {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .disabled(isCurrent)
                    .accessibilityIdentifier("move-category-\(category.name)")
                    .accessibilityHint(isCurrent ? "Current category" : "Move this item to \(category.name)")
                }
            }
            .navigationTitle("Move to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("move-category-cancel-button")
                }
            }
        }
    }

    private var orderedCategories: [Category] {
        ListGrouping.orderedCategories(categories, order: list?.categoryOrder ?? [])
    }
}
