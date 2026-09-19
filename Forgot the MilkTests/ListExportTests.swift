import Foundation
import SwiftData
import Testing

@testable import Forgot_the_Milk

private func fetchItems(in context: ModelContext, listID: UUID) throws -> [ListItem] {
    let descriptor = FetchDescriptor<ListItem>(predicate: #Predicate { $0.listID == listID })
    return try context.fetch(descriptor)
}

@Suite("List export text")
struct ListExportTests {
    @Test func exportGroupsNeededItemsByCategoryOrder() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context, categoryNames: ["Zeta", "Alpha"])
        _ = TestFixtures.makeItem(in: context, list: list, category: categories[0], name: "Plum", sortOrder: 0)
        _ = TestFixtures.makeItem(
            in: context, list: list, category: categories[1], name: "Milk", sortOrder: 0,
            quantity: "2", unit: "liters", note: "whole"
        )
        let items = try fetchItems(in: context, listID: list.id)

        let text = ListExport.text(categories: categories, items: items, categoryOrder: list.categoryOrder)

        #expect(text == """
            Zeta
              Plum

            Alpha
              Milk \u{2014} 2 liters \u{2014} whole
            """)
    }

    @Test func exportExcludesCompletedItems() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context)
        _ = TestFixtures.makeItem(in: context, list: list, category: categories[0], name: "Milk", sortOrder: 0)
        _ = TestFixtures.makeItem(in: context, list: list, category: categories[0], name: "Done", sortOrder: 1, state: .completed)
        let items = try fetchItems(in: context, listID: list.id)

        let text = ListExport.text(categories: categories, items: items, categoryOrder: list.categoryOrder)

        #expect(text == """
            Alpha
              Milk
            """)
    }

    @Test func exportFollowsPersistedOrderNotDefaultOrder() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context, categoryNames: ["Zeta", "Alpha"])
        _ = TestFixtures.makeItem(in: context, list: list, category: categories[0], name: "Plum", sortOrder: 0)
        _ = TestFixtures.makeItem(in: context, list: list, category: categories[1], name: "Milk", sortOrder: 0)
        list.categoryOrder = [categories[1].id, categories[0].id]
        let items = try fetchItems(in: context, listID: list.id)

        let text = ListExport.text(categories: categories, items: items, categoryOrder: list.categoryOrder)

        #expect(text == """
            Alpha
              Milk

            Zeta
              Plum
            """)
    }

    @Test func exportOmitsMissingMetadata() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context)
        _ = TestFixtures.makeItem(in: context, list: list, category: categories[0], name: "Plum", sortOrder: 0)
        _ = TestFixtures.makeItem(in: context, list: list, category: categories[0], name: "Milk", sortOrder: 1, quantity: "2")
        _ = TestFixtures.makeItem(in: context, list: list, category: categories[0], name: "Oat", sortOrder: 2, unit: "carton")
        let items = try fetchItems(in: context, listID: list.id)

        let text = ListExport.text(categories: categories, items: items, categoryOrder: list.categoryOrder)

        #expect(text == """
            Alpha
              Plum
              Milk \u{2014} 2
              Oat \u{2014} carton
            """)
    }

    @Test func exportOfEmptyListIsEmpty() {
        #expect(ListExport.text(sections: []).isEmpty)
    }
}
