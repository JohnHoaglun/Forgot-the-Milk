import Foundation
import SwiftData
import Testing

@testable import Forgot_the_Milk

private func listItems(in context: ModelContext, listID: UUID) throws -> [ListItem] {
    let descriptor = FetchDescriptor<ListItem>(predicate: #Predicate { $0.listID == listID })
    return try context.fetch(descriptor).sorted { $0.sortOrder < $1.sortOrder }
}

@Suite("Item form validation")
struct ItemFormValidationTests {
    @Test func validDraftHasNoIssues() {
        let draft = ItemDraft(name: "Milk", quantity: "1", unit: "gal", note: "2%", categoryID: UUID(), catalogItemID: nil)
        #expect(ItemFormValidation.issues(for: draft).isEmpty)
        #expect(ItemFormValidation.isValid(draft))
    }

    @Test func blankNameIsRejected() {
        let draft = ItemDraft(name: "   ", quantity: nil, unit: nil, note: nil, categoryID: UUID(), catalogItemID: nil)
        #expect(ItemFormValidation.issues(for: draft) == [.nameRequired])
    }

    @Test func missingCategoryIsRejected() {
        let draft = ItemDraft(name: "Milk", quantity: nil, unit: nil, note: nil, categoryID: nil, catalogItemID: nil)
        #expect(ItemFormValidation.issues(for: draft) == [.categoryRequired])
    }

    @Test func nameOverLimitIsRejected() {
        let draft = ItemDraft(name: String(repeating: "a", count: ItemFormValidation.nameLimit + 1), quantity: nil, unit: nil, note: nil, categoryID: UUID(), catalogItemID: nil)
        #expect(ItemFormValidation.issues(for: draft).contains(.nameTooLong))
    }

    @Test func nameAtLimitIsAccepted() {
        let draft = ItemDraft(name: String(repeating: "a", count: ItemFormValidation.nameLimit), quantity: nil, unit: nil, note: nil, categoryID: UUID(), catalogItemID: nil)
        #expect(ItemFormValidation.isValid(draft))
    }

    @Test func limitsCountGraphemeClusters() {
        let draft = ItemDraft(name: String(repeating: "🥛", count: ItemFormValidation.nameLimit + 1), quantity: nil, unit: nil, note: nil, categoryID: UUID(), catalogItemID: nil)
        #expect(ItemFormValidation.issues(for: draft).contains(.nameTooLong))
    }

    @Test func quantityOverLimitIsRejected() {
        let draft = ItemDraft(name: "Milk", quantity: String(repeating: "9", count: ItemFormValidation.quantityLimit + 1), unit: nil, note: nil, categoryID: UUID(), catalogItemID: nil)
        #expect(ItemFormValidation.issues(for: draft).contains(.quantityTooLong))
    }

    @Test func unitOverLimitIsRejected() {
        let draft = ItemDraft(name: "Milk", quantity: nil, unit: String(repeating: "g", count: ItemFormValidation.unitLimit + 1), note: nil, categoryID: UUID(), catalogItemID: nil)
        #expect(ItemFormValidation.issues(for: draft).contains(.unitTooLong))
    }

    @Test func noteOverLimitIsRejected() {
        let draft = ItemDraft(name: "Milk", quantity: nil, unit: nil, note: String(repeating: "n", count: ItemFormValidation.noteLimit + 1), categoryID: UUID(), catalogItemID: nil)
        #expect(ItemFormValidation.issues(for: draft).contains(.noteTooLong))
    }

    @Test func optionalFieldsCanBeBlank() {
        let draft = ItemDraft(name: "Milk", quantity: "", unit: "  ", note: nil, categoryID: UUID(), catalogItemID: nil)
        #expect(ItemFormValidation.isValid(draft))
    }
}

@Suite("Item label normalization")
struct ItemLabelTests {
    @Test func normalizationIsCaseInsensitive() {
        #expect(ItemLabel.normalize("SAKE") == ItemLabel.normalize("Sake"))
    }

    @Test func normalizationIsDiacriticInsensitive() {
        #expect(ItemLabel.normalize("Saké") == ItemLabel.normalize("Sake"))
    }

    @Test func normalizationCollapsesWhitespace() {
        #expect(ItemLabel.normalize("  Milk   of   Magnesia ") == ItemLabel.normalize("Milk of Magnesia"))
    }

    @Test func distinctLabelsStayDistinct() {
        #expect(ItemLabel.normalize("Sake") != ItemLabel.normalize("Soda"))
    }
}

@Suite("Adding items")
struct ItemEntryAddTests {
    private func makeStore() throws -> (ModelContainer, ModelContext, HouseholdList, Category) {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context)
        return (container, context, list, categories[0])
    }

    @Test func addCatalogItemInsertsOneRowWithMetadata() throws {
        let (container, context, list, category) = try makeStore()
        defer { _ = container }
        let catalogItem = TestFixtures.makeCatalogItem(in: context, category: category, name: "Milk", defaultQuantity: "1", defaultUnit: "gal")
        let useCases = ItemEntryUseCases(context: context)

        let result = useCases.add(
            ItemDraft(name: "Milk", quantity: "1", unit: "gal", note: "2%", categoryID: category.id, catalogItemID: catalogItem.id),
            to: list.id
        )

        #expect(result == .added)
        let items = try listItems(in: context, listID: list.id)
        #expect(items.count == 1)
        #expect(items[0].name == "Milk")
        #expect(items[0].quantity == "1")
        #expect(items[0].unit == "gal")
        #expect(items[0].note == "2%")
        #expect(items[0].state == .needed)
        #expect(items[0].catalogItemID == catalogItem.id)
    }

    @Test func addingSameCatalogItemAgainIsNoOp() throws {
        let (container, context, list, category) = try makeStore()
        defer { _ = container }
        let catalogItem = TestFixtures.makeCatalogItem(in: context, category: category, name: "Milk")
        let useCases = ItemEntryUseCases(context: context)
        let draft = ItemDraft(name: "Milk", quantity: nil, unit: nil, note: nil, categoryID: category.id, catalogItemID: catalogItem.id)

        #expect(useCases.add(draft, to: list.id) == .added)
        #expect(useCases.add(draft, to: list.id) == .alreadyNeeded)
        #expect(try listItems(in: context, listID: list.id).count == 1)
    }

    @Test func addingCompletedCatalogItemReopensIt() throws {
        let (container, context, list, category) = try makeStore()
        defer { _ = container }
        let catalogItem = TestFixtures.makeCatalogItem(in: context, category: category, name: "Milk")
        let useCases = ItemEntryUseCases(context: context)
        let draft = ItemDraft(name: "Milk", quantity: nil, unit: nil, note: nil, categoryID: category.id, catalogItemID: catalogItem.id)
        #expect(useCases.add(draft, to: list.id) == .added)

        let item = try listItems(in: context, listID: list.id)[0]
        ItemUseCases(context: context).complete(item)
        #expect(useCases.add(draft, to: list.id) == .reopened)

        let items = try listItems(in: context, listID: list.id)
        #expect(items.count == 1)
        #expect(items[0].state == .needed)
    }

    @Test func addingCustomItemInsertsRowWithoutCatalogLink() throws {
        let (container, context, list, category) = try makeStore()
        defer { _ = container }
        let useCases = ItemEntryUseCases(context: context)

        #expect(useCases.add(ItemDraft(name: "Tofu", quantity: "2", unit: "pkg", note: nil, categoryID: category.id, catalogItemID: nil), to: list.id) == .added)

        let items = try listItems(in: context, listID: list.id)
        #expect(items.count == 1)
        #expect(items[0].catalogItemID == nil)
        #expect(items[0].quantity == "2")
    }

    @Test func addingNormalizedVariantOfCustomItemIsNoOp() throws {
        let (container, context, list, category) = try makeStore()
        defer { _ = container }
        let useCases = ItemEntryUseCases(context: context)

        #expect(useCases.add(ItemDraft(name: "Sake", quantity: nil, unit: nil, note: nil, categoryID: category.id, catalogItemID: nil), to: list.id) == .added)
        #expect(useCases.add(ItemDraft(name: "  SAKE ", quantity: nil, unit: nil, note: nil, categoryID: category.id, catalogItemID: nil), to: list.id) == .alreadyNeeded)
        #expect(try listItems(in: context, listID: list.id).count == 1)
    }

    @Test func addingCompletedCustomItemReopensIt() throws {
        let (container, context, list, category) = try makeStore()
        defer { _ = container }
        let useCases = ItemEntryUseCases(context: context)
        let draft = ItemDraft(name: "Sake", quantity: nil, unit: nil, note: nil, categoryID: category.id, catalogItemID: nil)
        #expect(useCases.add(draft, to: list.id) == .added)

        let item = try listItems(in: context, listID: list.id)[0]
        ItemUseCases(context: context).complete(item)
        #expect(useCases.add(draft, to: list.id) == .reopened)

        let items = try listItems(in: context, listID: list.id)
        #expect(items.count == 1)
        #expect(items[0].state == .needed)
    }

    @Test func saveToCatalogCreatesHouseholdCatalogItemAndLinksIt() throws {
        let (container, context, list, category) = try makeStore()
        defer { _ = container }
        let useCases = ItemEntryUseCases(context: context)
        let draft = ItemDraft(name: "Miso Soup", quantity: "4", unit: "cups", note: "low salt", categoryID: category.id, catalogItemID: nil)

        #expect(useCases.add(draft, to: list.id, saveToCatalog: true) == .added)

        let catalogDescriptor = FetchDescriptor<CatalogItem>()
        let catalogItems = try context.fetch(catalogDescriptor)
        #expect(catalogItems.count == 1)
        #expect(catalogItems[0].scope == .household)
        #expect(catalogItems[0].name == "Miso Soup")
        #expect(catalogItems[0].defaultQuantity == "4")
        #expect(catalogItems[0].defaultUnit == "cups")
        #expect(catalogItems[0].defaultNote == "low salt")

        let item = try listItems(in: context, listID: list.id)[0]
        #expect(item.catalogItemID == catalogItems[0].id)
    }

    @Test func invalidDraftCreatesNothing() throws {
        let (container, context, list, category) = try makeStore()
        defer { _ = container }
        let useCases = ItemEntryUseCases(context: context)

        #expect(useCases.add(ItemDraft(name: "  ", quantity: nil, unit: nil, note: nil, categoryID: category.id, catalogItemID: nil), to: list.id) == .invalid)
        #expect(useCases.add(ItemDraft(name: "Milk", quantity: nil, unit: nil, note: nil, categoryID: nil, catalogItemID: nil), to: list.id) == .invalid)
        #expect(try listItems(in: context, listID: list.id).isEmpty)
    }

    @Test func newItemAppendsToCategoryBottom() throws {
        let (container, context, list, category) = try makeStore()
        defer { _ = container }
        let useCases = ItemEntryUseCases(context: context)
        _ = TestFixtures.makeItem(in: context, list: list, category: category, name: "First", sortOrder: 0)
        _ = TestFixtures.makeItem(in: context, list: list, category: category, name: "Second", sortOrder: 1)

        #expect(useCases.add(ItemDraft(name: "Third", quantity: nil, unit: nil, note: nil, categoryID: category.id, catalogItemID: nil), to: list.id) == .added)

        let items = try listItems(in: context, listID: list.id)
        #expect(items.map(\.name) == ["First", "Second", "Third"])
        #expect(items.map(\.sortOrder) == [0, 1, 2])
    }
}

@Suite("Updating items")
struct ItemEntryUpdateTests {
    private func makeStore() throws -> (ModelContainer, ModelContext, HouseholdList, Category, Category) {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context)
        return (container, context, list, categories[0], categories[1])
    }

    @Test func updatePersistsMetadata() throws {
        let (container, context, list, category, _) = try makeStore()
        defer { _ = container }
        let item = TestFixtures.makeItem(in: context, list: list, category: category, name: "Milk", sortOrder: 0)
        let useCases = ItemEntryUseCases(context: context)
        let originalUpdatedAt = item.updatedAt

        #expect(
            useCases.update(
                item,
                with: ItemDraft(name: "Oat Milk", quantity: "2", unit: "gal", note: "barista", categoryID: category.id, catalogItemID: nil)
            )
        )

        let fetched = try listItems(in: context, listID: list.id)[0]
        #expect(fetched.name == "Oat Milk")
        #expect(fetched.quantity == "2")
        #expect(fetched.unit == "gal")
        #expect(fetched.note == "barista")
        #expect(fetched.updatedAt > originalUpdatedAt)
    }

    @Test func updateClearsBlankMetadata() throws {
        let (container, context, list, category, _) = try makeStore()
        defer { _ = container }
        let item = TestFixtures.makeItem(in: context, list: list, category: category, name: "Milk", sortOrder: 0, quantity: "1", unit: "gal", note: "2%")
        let useCases = ItemEntryUseCases(context: context)

        #expect(
            useCases.update(
                item,
                with: ItemDraft(name: "Milk", quantity: "  ", unit: "", note: nil, categoryID: category.id, catalogItemID: nil)
            )
        )

        let fetched = try listItems(in: context, listID: list.id)[0]
        #expect(fetched.quantity == nil)
        #expect(fetched.unit == nil)
        #expect(fetched.note == nil)
    }

    @Test func updateMovesItemToNewCategoryAtBottom() throws {
        let (container, context, list, category, other) = try makeStore()
        defer { _ = container }
        let item = TestFixtures.makeItem(in: context, list: list, category: category, name: "Milk", sortOrder: 0)
        _ = TestFixtures.makeItem(in: context, list: list, category: other, name: "Existing", sortOrder: 5)
        let useCases = ItemEntryUseCases(context: context)

        #expect(
            useCases.update(
                item,
                with: ItemDraft(name: "Milk", quantity: nil, unit: nil, note: nil, categoryID: other.id, catalogItemID: nil)
            )
        )

        let items = try listItems(in: context, listID: list.id)
        #expect(items.count == 2)
        #expect(items.filter { $0.categoryID == category.id }.isEmpty)
        let moved = items.first { $0.name == "Milk" }
        #expect(moved?.sortOrder == 6)
        #expect(item.categoryID == other.id)
    }

    @Test func updateRejectsInvalidDraftWithoutChanges() throws {
        let (container, context, list, category, _) = try makeStore()
        defer { _ = container }
        let item = TestFixtures.makeItem(in: context, list: list, category: category, name: "Milk", sortOrder: 0)
        let useCases = ItemEntryUseCases(context: context)

        #expect(!useCases.update(item, with: ItemDraft(name: "", quantity: nil, unit: nil, note: nil, categoryID: category.id, catalogItemID: nil)))

        let fetched = try listItems(in: context, listID: list.id)[0]
        #expect(fetched.name == "Milk")
    }
}

@Suite("Category order")
struct ListOrderTests {
    @Test func setCategoryOrderPersistsAcrossContexts() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context)
        ListUseCases(context: context).setCategoryOrder([categories[1].id, categories[0].id], for: list.id)

        let id = list.id
        let descriptor = FetchDescriptor<HouseholdList>(predicate: #Predicate { $0.id == id })
        let refetched = try TestStore.makeContext(container).fetch(descriptor)[0]
        #expect(refetched.categoryOrder == [categories[1].id, categories[0].id])
    }

    @Test func setCategoryOrderKeepsUnchangedOrderTouched() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context)
        let originalUpdatedAt = list.updatedAt

        ListUseCases(context: context).setCategoryOrder([categories[0].id, categories[1].id], for: list.id)

        #expect(list.categoryOrder == [categories[0].id, categories[1].id])
        #expect(list.updatedAt == originalUpdatedAt)
    }
}

@Suite("Unit system settings")
struct SettingsStoreTests {
    private func makeDefaults() -> (UserDefaults, SettingsStore) {
        let defaults = UserDefaults(suiteName: "settings.test.\(UUID())")!
        return (defaults, SettingsStore(defaults: defaults))
    }

    @Test func defaultUnitSystemIsImperial() {
        let (defaults, store) = makeDefaults()
        defer { defaults.removeObject(forKey: "settings.unitSystem") }
        #expect(store.unitSystem == .imperial)
    }

    @Test func unitSystemPersists() {
        var (defaults, store) = makeDefaults()
        defer { defaults.removeObject(forKey: "settings.unitSystem") }
        store.unitSystem = .metric
        #expect(SettingsStore(defaults: defaults).unitSystem == .metric)
    }
}

@Suite("Catalog search")
struct CatalogSearchTests {
    @Test func emptyQueryMatchesEverything() {
        #expect(CatalogSearch.matches(query: "", label: "Milk"))
        #expect(CatalogSearch.matches(query: "   ", label: "Milk"))
    }

    @Test func queryMatchesIgnoringCaseAndDiacritics() {
        #expect(CatalogSearch.matches(query: "SAKE", label: "Saké"))
        #expect(CatalogSearch.matches(query: "sake", label: "Sake"))
    }

    @Test func nonMatchingQueryExcludes() {
        #expect(!CatalogSearch.matches(query: "soda", label: "Sake"))
    }
}
