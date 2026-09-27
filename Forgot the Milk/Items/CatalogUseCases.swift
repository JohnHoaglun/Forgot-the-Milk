import Foundation
import SwiftData

struct CatalogUseCases {
    let context: ModelContext

    @discardableResult
    func move(_ catalogItem: CatalogItem, to categoryID: UUID) -> Bool {
        guard catalogItem.scope == .household,
              catalogItem.categoryID != categoryID,
              category(categoryID) != nil else {
            return false
        }

        let linkedItems = linkedListItems(of: catalogItem.id)
        let affectedTemplates = templates(linking: catalogItem.id)

        catalogItem.categoryID = categoryID
        catalogItem.updatedAt = Date()

        for item in linkedItems {
            item.categoryID = categoryID
            item.sortOrder = nextSortOrder(listID: item.listID, categoryID: categoryID, excluding: item.id)
            item.updatedAt = Date()
        }

        for template in affectedTemplates {
            template.entries = template.entries.map { entry in
                var entry = entry
                if entry.catalogItemID == catalogItem.id {
                    entry.categoryID = categoryID
                }
                return entry
            }
            template.updatedAt = Date()
        }

        save()
        return true
    }

    private func category(_ id: UUID) -> Category? {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate {
            $0.id == id
        })
        return (try? context.fetch(descriptor))?.first
    }

    private func linkedListItems(of catalogItemID: UUID) -> [ListItem] {
        let descriptor = FetchDescriptor<ListItem>(predicate: #Predicate {
            $0.catalogItemID == catalogItemID
        })
        return ((try? context.fetch(descriptor)) ?? [])
            .sorted { ($0.listID, $0.sortOrder) < ($1.listID, $1.sortOrder) }
    }

    private func templates(linking catalogItemID: UUID) -> [Template] {
        let descriptor = FetchDescriptor<Template>()
        return ((try? context.fetch(descriptor)) ?? []).filter {
            $0.entries.contains { $0.catalogItemID == catalogItemID }
        }
    }

    private func nextSortOrder(listID: UUID, categoryID: UUID, excluding itemID: UUID) -> Int {
        let descriptor = FetchDescriptor<ListItem>(predicate: #Predicate {
            $0.listID == listID && $0.categoryID == categoryID && $0.id != itemID
        })
        let items = (try? context.fetch(descriptor)) ?? []
        return (items.map(\.sortOrder).max() ?? -1) + 1
    }

    private func save() {
        if context.hasChanges {
            try? context.save()
        }
    }
}
