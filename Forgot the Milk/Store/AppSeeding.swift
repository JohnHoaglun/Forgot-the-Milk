import Foundation
import SwiftData

enum AppSeeding {
    static func seedIfNeeded(context: ModelContext) throws {
        let existingCategories = try context.fetch(FetchDescriptor<Category>())
        let existingCatalogItems = try context.fetch(FetchDescriptor<CatalogItem>())
        let existingCategoryIDs = Set(existingCategories.map(\.id))
        let existingCatalogItemIDs = Set(existingCatalogItems.map(\.id))

        let newCategories = SeedCatalog.categories.compactMap { seed -> Category? in
            let id = DeterministicID.category(seed.name)
            guard !existingCategoryIDs.contains(id) else { return nil }
            return Category(id: id, name: seed.name, defaultOrder: seed.defaultOrder, isSystem: true)
        }

        let newCatalogItems = SeedCatalog.entries.compactMap { seed -> CatalogItem? in
            let id = DeterministicID.catalogItem(category: seed.category, label: seed.label)
            guard !existingCatalogItemIDs.contains(id) else { return nil }
            return CatalogItem(
                id: id,
                name: seed.label,
                categoryID: DeterministicID.category(seed.category),
                scope: .builtIn
            )
        }

        for category in newCategories {
            context.insert(category)
        }
        for item in newCatalogItems {
            context.insert(item)
        }

        let existingLists = try context.fetch(FetchDescriptor<HouseholdList>())
        if existingLists.isEmpty {
            let categoryOrder = SeedCatalog.categories
                .sorted { $0.defaultOrder < $1.defaultOrder }
                .map { DeterministicID.category($0.name) }
            let list = HouseholdList(id: UUID(), title: "My List", categoryOrder: categoryOrder)
            context.insert(list)
        }

        if context.hasChanges {
            try context.save()
        }
    }
}
