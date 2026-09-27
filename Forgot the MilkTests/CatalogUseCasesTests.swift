import Foundation
import SwiftData
import Testing

@testable import Forgot_the_Milk

@Suite("Catalog move")
struct CatalogMoveTests {
    private func makeStore() throws -> (ModelContainer, ModelContext, HouseholdList, [Category]) {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context)
        return (container, context, list, categories)
    }

    @Test func moveHouseholdItemRehomesLinkedItemsAndTemplateEntries() throws {
        let (container, context, list, categories) = try makeStore()
        defer { _ = container }
        let (source, target) = (categories[0], categories[1])
        let catalogItem = TestFixtures.makeCatalogItem(in: context, category: source, name: "Tofu", scope: .household)

        let linked = TestFixtures.makeItem(in: context, list: list, category: source, name: "Tofu", sortOrder: 4)
        linked.catalogItemID = catalogItem.id

        let existingInTarget = TestFixtures.makeItem(in: context, list: list, category: target, name: "Milk", sortOrder: 0)
        let oneOffInTarget = TestFixtures.makeItem(in: context, list: list, category: target, name: "Sticky note", sortOrder: 1)

        let secondList = HouseholdList(id: UUID(), title: "Partner list")
        context.insert(secondList)
        let linkedInSecond = TestFixtures.makeItem(in: context, list: secondList, category: source, name: "Tofu", sortOrder: 2, state: .completed)
        linkedInSecond.catalogItemID = catalogItem.id

        let template = Template(
            id: UUID(),
            listID: list.id,
            name: "Weekly",
            entries: [
                TemplateEntry(catalogItemID: catalogItem.id, name: "Tofu", categoryID: source.id, quantity: "2", unit: "blocks", note: nil),
                TemplateEntry(catalogItemID: nil, name: "Milk", categoryID: target.id, quantity: nil, unit: nil, note: nil)
            ]
        )
        context.insert(template)
        try context.save()

        #expect(CatalogUseCases(context: context).move(catalogItem, to: target.id))

        #expect(catalogItem.categoryID == target.id)

        let linkedID = linked.id
        let moved = try context.fetch(FetchDescriptor<ListItem>(predicate: #Predicate { $0.id == linkedID }))[0]
        #expect(moved.categoryID == target.id)
        #expect(moved.sortOrder == 2)
        #expect(moved.state == .needed)

        let linkedInSecondID = linkedInSecond.id
        let movedInSecond = try context.fetch(FetchDescriptor<ListItem>(predicate: #Predicate { $0.id == linkedInSecondID }))[0]
        #expect(movedInSecond.categoryID == target.id)
        #expect(movedInSecond.sortOrder == 0)
        #expect(movedInSecond.state == .completed)

        let oneOffInTargetID = oneOffInTarget.id
        let untouchedOneOff = try context.fetch(FetchDescriptor<ListItem>(predicate: #Predicate { $0.id == oneOffInTargetID }))[0]
        #expect(untouchedOneOff.catalogItemID == nil)
        #expect(untouchedOneOff.sortOrder == 1)

        let existingInTargetID = existingInTarget.id
        #expect(try context.fetch(FetchDescriptor<ListItem>(predicate: #Predicate { $0.id == existingInTargetID }))[0].sortOrder == 0)

        let templateID = template.id
        let reloaded = try context.fetch(FetchDescriptor<Template>(predicate: #Predicate { $0.id == templateID }))[0]
        let entries = reloaded.entries
        #expect(entries.count == 2)
        #expect(entries[0].catalogItemID == catalogItem.id)
        #expect(entries[0].categoryID == target.id)
        #expect(entries[0].quantity == "2")
        #expect(entries[1].catalogItemID == nil)
        #expect(entries[1].categoryID == target.id)
    }

    @Test func moveBuiltInItemIsRefused() throws {
        let (container, context, _, categories) = try makeStore()
        defer { _ = container }
        let (source, target) = (categories[0], categories[1])
        let builtIn = TestFixtures.makeCatalogItem(in: context, category: source, name: "Milk", scope: .builtIn)

        #expect(!CatalogUseCases(context: context).move(builtIn, to: target.id))
        #expect(builtIn.categoryID == source.id)
    }

    @Test func moveToSameCategoryIsRefused() throws {
        let (container, context, _, categories) = try makeStore()
        defer { _ = container }
        let catalogItem = TestFixtures.makeCatalogItem(in: context, category: categories[0], name: "Tofu", scope: .household)

        #expect(!CatalogUseCases(context: context).move(catalogItem, to: categories[0].id))
        #expect(catalogItem.categoryID == categories[0].id)
    }

    @Test func moveWithUnknownCategoryIsRefused() throws {
        let (container, context, _, categories) = try makeStore()
        defer { _ = container }
        let catalogItem = TestFixtures.makeCatalogItem(in: context, category: categories[0], name: "Tofu", scope: .household)

        #expect(!CatalogUseCases(context: context).move(catalogItem, to: UUID()))
        #expect(catalogItem.categoryID == categories[0].id)
    }
}
