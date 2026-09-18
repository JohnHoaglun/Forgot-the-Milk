import Foundation
import SwiftData

@testable import Forgot_the_Milk

enum TestFixtures {
    static func makeList(
        in context: ModelContext,
        title: String = "Test List",
        categoryNames: [String] = ["Alpha", "Beta"]
    ) -> (list: HouseholdList, categories: [Category]) {
        var categories: [Category] = []
        for (index, name) in categoryNames.enumerated() {
            let category = Category(id: UUID(), name: name, defaultOrder: index, isSystem: true)
            context.insert(category)
            categories.append(category)
        }
        let list = HouseholdList(id: UUID(), title: title, categoryOrder: categories.map(\.id))
        context.insert(list)
        try? context.save()
        return (list, categories)
    }

    static func makeItem(
        in context: ModelContext,
        list: HouseholdList,
        category: Category,
        name: String,
        sortOrder: Int,
        quantity: String? = nil,
        unit: String? = nil,
        note: String? = nil,
        state: ListItemState = .needed
    ) -> ListItem {
        let item = ListItem(
            id: UUID(),
            listID: list.id,
            catalogItemID: nil,
            name: name,
            categoryID: category.id,
            quantity: quantity,
            unit: unit,
            note: note,
            state: state,
            sortOrder: sortOrder
        )
        context.insert(item)
        try? context.save()
        return item
    }

    static func makeCatalogItem(
        in context: ModelContext,
        category: Category,
        name: String,
        defaultQuantity: String? = nil,
        defaultUnit: String? = nil,
        defaultNote: String? = nil,
        scope: CatalogScope = .builtIn
    ) -> CatalogItem {
        let item = CatalogItem(
            id: UUID(),
            name: name,
            categoryID: category.id,
            defaultQuantity: defaultQuantity,
            defaultUnit: defaultUnit,
            defaultNote: defaultNote,
            scope: scope
        )
        context.insert(item)
        try? context.save()
        return item
    }
}
