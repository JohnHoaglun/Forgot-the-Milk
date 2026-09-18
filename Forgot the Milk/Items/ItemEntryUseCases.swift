import Foundation
import SwiftData

struct ItemEntryUseCases {
    let context: ModelContext

    @discardableResult
    func add(_ draft: ItemDraft, to listID: UUID, saveToCatalog: Bool = false) -> AddResult {
        guard ItemFormValidation.isValid(draft), let categoryID = draft.categoryID else {
            return .invalid
        }

        var catalogItemID = draft.catalogItemID
        if saveToCatalog, catalogItemID == nil {
            let catalogItem = CatalogItem(
                id: UUID(),
                name: draft.name,
                categoryID: categoryID,
                defaultQuantity: draft.quantity,
                defaultUnit: draft.unit,
                defaultNote: draft.note,
                scope: .household
            )
            context.insert(catalogItem)
            catalogItemID = catalogItem.id
        }

        if let catalogItemID {
            let existing = items(in: listID, catalogItemID: catalogItemID)
            if let item = existing.first {
                return item.state == .completed ? reopen(item) : .alreadyNeeded
            }
        } else {
            let normalized = ItemLabel.normalize(draft.name)
            let siblings = items(in: listID, categoryID: categoryID)
            let matching = siblings.filter {
                $0.catalogItemID == nil && ItemLabel.normalize($0.name) == normalized
            }
            if let item = matching.first {
                return item.state == .completed ? reopen(item) : .alreadyNeeded
            }
        }

        let item = ListItem(
            id: UUID(),
            listID: listID,
            catalogItemID: catalogItemID,
            name: draft.name,
            categoryID: categoryID,
            quantity: trimmedOrNil(draft.quantity),
            unit: trimmedOrNil(draft.unit),
            note: trimmedOrNil(draft.note),
            state: .needed,
            sortOrder: nextSortOrder(listID: listID, categoryID: categoryID)
        )
        context.insert(item)
        save()
        return .added
    }

    @discardableResult
    func update(_ item: ListItem, with draft: ItemDraft) -> Bool {
        guard ItemFormValidation.isValid(draft), let categoryID = draft.categoryID else {
            return false
        }
        item.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.quantity = trimmedOrNil(draft.quantity)
        item.unit = trimmedOrNil(draft.unit)
        item.note = trimmedOrNil(draft.note)
        if item.categoryID != categoryID {
            item.categoryID = categoryID
            item.sortOrder = nextSortOrder(listID: item.listID, categoryID: categoryID)
        }
        item.updatedAt = Date()
        save()
        return true
    }

    private func items(in listID: UUID, catalogItemID: UUID) -> [ListItem] {
        let descriptor = FetchDescriptor<ListItem>(predicate: #Predicate {
            $0.listID == listID && $0.catalogItemID == catalogItemID
        })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func items(in listID: UUID, categoryID: UUID) -> [ListItem] {
        let descriptor = FetchDescriptor<ListItem>(predicate: #Predicate {
            $0.listID == listID && $0.categoryID == categoryID
        })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func reopen(_ item: ListItem) -> AddResult {
        item.state = .needed
        item.updatedAt = Date()
        save()
        return .reopened
    }

    private func nextSortOrder(listID: UUID, categoryID: UUID) -> Int {
        let items = items(in: listID, categoryID: categoryID)
        return (items.map(\.sortOrder).max() ?? -1) + 1
    }

    private func trimmedOrNil(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func save() {
        if context.hasChanges {
            try? context.save()
        }
    }
}
