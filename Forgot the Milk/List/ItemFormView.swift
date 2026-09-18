import Foundation
import SwiftData
import SwiftUI

struct ItemFormView: View {
    enum Mode: Equatable {
        case addCatalog(CatalogItem)
        case addCustom
        case edit(ListItem)
    }

    let mode: Mode

    @Query private var lists: [HouseholdList]
    @Query private var categories: [Category]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var quantity: String
    @State private var unit: String
    @State private var note: String
    @State private var categoryID: UUID?
    @State private var saveToCatalog: Bool
    @State private var isConfirmingDelete = false

    private let catalogItemID: UUID?

    init(mode: Mode) {
        self.mode = mode

        var name0 = ""
        var quantity0 = ""
        var unit0 = ""
        var note0 = ""
        var category0: UUID?
        var catalogID: UUID?

        switch mode {
        case .addCatalog(let item):
            name0 = item.name
            quantity0 = item.defaultQuantity ?? ""
            unit0 = item.defaultUnit ?? ""
            note0 = item.defaultNote ?? ""
            category0 = item.categoryID
            catalogID = item.id
        case .addCustom:
            break
        case .edit(let item):
            name0 = item.name
            quantity0 = item.quantity ?? ""
            unit0 = item.unit ?? ""
            note0 = item.note ?? ""
            category0 = item.categoryID
            catalogID = item.catalogItemID
        }

        _name = State(initialValue: name0)
        _quantity = State(initialValue: quantity0)
        _unit = State(initialValue: unit0)
        _note = State(initialValue: note0)
        _categoryID = State(initialValue: category0)
        _saveToCatalog = State(initialValue: false)
        catalogItemID = catalogID
    }

    private var draft: ItemDraft {
        ItemDraft(
            name: name,
            quantity: blankOrNil(quantity),
            unit: blankOrNil(unit),
            note: blankOrNil(note),
            categoryID: categoryID,
            catalogItemID: catalogItemID
        )
    }

    private var validationIssues: [ItemFormValidation.Issue] {
        ItemFormValidation.issues(for: draft)
    }

    private var isValid: Bool {
        validationIssues.isEmpty
    }

    private var orderedCategories: [Category] {
        guard let list = lists.first else { return categories }
        return ListGrouping.orderedCategories(categories, order: list.categoryOrder)
    }

    private var title: String {
        switch mode {
        case .addCatalog:
            return "Add Item"
        case .addCustom:
            return "Add Custom Item"
        case .edit:
            return "Edit Item"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("item-form-name-field")
                    TextField("Quantity", text: $quantity)
                        .accessibilityIdentifier("item-form-quantity-field")
                    TextField("Unit", text: $unit)
                        .accessibilityIdentifier("item-form-unit-field")
                    TextField("Note", text: $note, axis: .vertical)
                        .accessibilityIdentifier("item-form-note-field")
                }

                Section {
                    Picker("Category", selection: $categoryID) {
                        Text("Choose a category").tag(UUID?.none)
                        ForEach(orderedCategories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                    .accessibilityIdentifier("item-form-category-picker")
                }

                if case .addCustom = mode {
                    Section {
                        Toggle("Save to catalog", isOn: $saveToCatalog)
                            .accessibilityIdentifier("save-to-catalog-toggle")
                            .accessibilityHint("Saves this item as a reusable catalog entry")
                    } footer: {
                        Text("Saves this item as a reusable catalog entry for future lists.")
                    }
                }

                if !isValid {
                    Section {
                        ForEach(validationIssues, id: \.self) { issue in
                            Text(message(for: issue))
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .accessibilityIdentifier("item-form-validation")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("item-form-cancel-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .accessibilityIdentifier("item-form-save-button")
                }
                if case .edit = mode {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Delete", role: .destructive) {
                            isConfirmingDelete = true
                        }
                        .accessibilityIdentifier("item-form-delete-button")
                        .accessibilityHint("Removes this item from the list")
                    }
                }
            }
            .confirmationDialog(
                "Delete \(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "item" : name)?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteItem() }
                    .accessibilityIdentifier("form-delete-confirm-button")
                Button("Cancel", role: .cancel) {}
                    .accessibilityIdentifier("form-delete-cancel-button")
            } message: {
                Text("This cannot be undone.")
            }
            .onAppear(perform: applyDefaultCategory)
        }
    }

    private func message(for issue: ItemFormValidation.Issue) -> String {
        switch issue {
        case .nameRequired:
            return "Name is required."
        case .nameTooLong:
            return "Name must be 120 characters or fewer."
        case .quantityTooLong:
            return "Quantity must be 40 characters or fewer."
        case .unitTooLong:
            return "Unit must be 40 characters or fewer."
        case .noteTooLong:
            return "Note must be 280 characters or fewer."
        case .categoryRequired:
            return "Choose a category."
        }
    }

    private func save() {
        guard let list = lists.first, isValid else { return }
        let useCases = ItemEntryUseCases(context: modelContext)
        switch mode {
        case .edit(let item):
            _ = useCases.update(item, with: draft)
        default:
            _ = useCases.add(draft, to: list.id, saveToCatalog: saveToCatalog)
        }
        dismiss()
    }

    private func deleteItem() {
        guard case .edit(let item) = mode else { return }
        ItemUseCases(context: modelContext).delete(item)
        dismiss()
    }

    private func applyDefaultCategory() {
        guard case .addCustom = mode, categoryID == nil else { return }
        if let other = categories.first(where: { $0.name == "Other / errands" }) {
            categoryID = other.id
        }
    }

    private func blankOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
