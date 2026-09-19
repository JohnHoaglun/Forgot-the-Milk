import Foundation
import SwiftData
import Testing

@testable import Forgot_the_Milk

private func fetchTemplates(in context: ModelContext, listID: UUID) throws -> [Template] {
    let descriptor = FetchDescriptor<Template>(predicate: #Predicate { $0.listID == listID })
    return try context.fetch(descriptor)
}

private func fetchItems(in context: ModelContext, listID: UUID) throws -> [ListItem] {
    let descriptor = FetchDescriptor<ListItem>(predicate: #Predicate { $0.listID == listID })
    return try context.fetch(descriptor)
}

@Suite("Template name validation")
struct TemplateNameValidationTests {
    @Test func blankNameIsRejected() {
        #expect(TemplateNameValidation.issues(for: "   ", existing: []) == [.nameRequired])
    }

    @Test func nameAtLimitIsAccepted() {
        #expect(TemplateNameValidation.isValid(String(repeating: "a", count: TemplateNameValidation.limit), existing: []))
    }

    @Test func nameOverLimitIsRejected() {
        let issues = TemplateNameValidation.issues(for: String(repeating: "a", count: TemplateNameValidation.limit + 1), existing: [])
        #expect(issues.contains(.nameTooLong))
    }

    @Test func limitCountsGraphemeClusters() {
        let over = TemplateNameValidation.issues(for: String(repeating: "🛒", count: TemplateNameValidation.limit + 1), existing: [])
        #expect(over.contains(.nameTooLong))
        #expect(TemplateNameValidation.isValid(String(repeating: "🛒", count: TemplateNameValidation.limit), existing: []))
    }

    @Test func duplicateNameIsRejectedCaseInsensitively() {
        let template = Template(listID: UUID(), name: "Weekly")
        #expect(TemplateNameValidation.issues(for: "weekly", existing: [template]).contains(.nameNotUnique))
        #expect(TemplateNameValidation.issues(for: "  WEEKLY ", existing: [template]).contains(.nameNotUnique))
    }

    @Test func distinctNamesAreAccepted() {
        let template = Template(listID: UUID(), name: "Weekly")
        #expect(TemplateNameValidation.isValid("Bakery", existing: [template]))
    }
}

@Suite("Template save")
struct TemplateSaveTests {
    @Test func saveSnapshotsNeededItemsOnlyInOrder() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context)
        let entryUseCases = ItemEntryUseCases(context: context)
        _ = entryUseCases.add(
            ItemDraft(name: "Milk", quantity: "2", unit: "liters", note: "whole", categoryID: categories[0].id, catalogItemID: nil),
            to: list.id
        )
        _ = entryUseCases.add(
            ItemDraft(name: "Apples", categoryID: categories[1].id, catalogItemID: nil),
            to: list.id
        )
        _ = TestFixtures.makeItem(in: context, list: list, category: categories[1], name: "Done", sortOrder: 1, state: .completed)

        #expect(TemplateUseCases(context: context).save(named: "  Weekly  ", for: list.id) == .saved)

        let templates = try fetchTemplates(in: context, listID: list.id)
        #expect(templates.count == 1)
        #expect(templates[0].name == "Weekly")
        let entries = templates[0].entries
        #expect(entries.map(\.name) == ["Milk", "Apples"])
        #expect(entries[0].quantity == "2")
        #expect(entries[0].unit == "liters")
        #expect(entries[0].note == "whole")
        #expect(entries[0].categoryID == categories[0].id)
        #expect(!entries.contains { $0.name == "Done" })
        let done = try fetchItems(in: context, listID: list.id).first { $0.name == "Done" }
        #expect(done?.state == .completed)
    }

    @Test func saveIsUnavailableWhenNothingIsNeeded() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context)
        _ = TestFixtures.makeItem(in: context, list: list, category: categories[0], name: "Done", sortOrder: 0, state: .completed)

        #expect(TemplateUseCases(context: context).save(named: "Weekly", for: list.id) == .nothingNeeded)
        #expect(try fetchTemplates(in: context, listID: list.id).isEmpty)
    }

    @Test func saveRejectsInvalidNamesWithoutCreatingTemplates() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context)
        let entryUseCases = ItemEntryUseCases(context: context)
        _ = entryUseCases.add(ItemDraft(name: "Milk", categoryID: categories[0].id, catalogItemID: nil), to: list.id)
        let useCases = TemplateUseCases(context: context)

        #expect(useCases.save(named: "   ", for: list.id) == .invalidName)
        #expect(useCases.save(named: "Weekly", for: list.id) == .saved)
        #expect(useCases.save(named: "weekly", for: list.id) == .invalidName)
        #expect(useCases.save(named: String(repeating: "a", count: TemplateNameValidation.limit + 1), for: list.id) == .invalidName)
        #expect(try fetchTemplates(in: context, listID: list.id).count == 1)
    }
}

@Suite("Template apply")
struct TemplateApplyTests {
    private func makeTemplate(in context: ModelContext, list: HouseholdList) throws -> Template {
        let entryUseCases = ItemEntryUseCases(context: context)
        let category = try context.fetch(FetchDescriptor<Category>()).first!
        _ = entryUseCases.add(ItemDraft(name: "Milk", quantity: "2", unit: "liters", categoryID: category.id, catalogItemID: nil), to: list.id)
        _ = entryUseCases.add(ItemDraft(name: "Apples", categoryID: category.id, catalogItemID: nil), to: list.id)
        #expect(TemplateUseCases(context: context).save(named: "Weekly", for: list.id) == .saved)
        return try fetchTemplates(in: context, listID: list.id).first!
    }

    @Test func applyAddsItemsAndReportsChangedCount() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, _) = TestFixtures.makeList(in: context)
        let template = try makeTemplate(in: context, list: list)
        let itemUseCases = ItemUseCases(context: context)
        for item in try fetchItems(in: context, listID: list.id) {
            itemUseCases.delete(item)
        }

        let report = TemplateUseCases(context: context).apply(template, to: list.id)

        #expect(report.added == 2)
        #expect(report.reopened == 0)
        #expect(report.changedCount == 2)
        let items = try fetchItems(in: context, listID: list.id)
        #expect(items.map(\.name).sorted() == ["Apples", "Milk"])
        #expect(items.allSatisfy { $0.state == .needed })
    }

    @Test func applyReopensCompletedItems() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, _) = TestFixtures.makeList(in: context)
        let template = try makeTemplate(in: context, list: list)
        let itemUseCases = ItemUseCases(context: context)
        for item in try fetchItems(in: context, listID: list.id) {
            itemUseCases.complete(item)
        }

        let report = TemplateUseCases(context: context).apply(template, to: list.id)

        #expect(report.added == 0)
        #expect(report.reopened == 2)
        #expect(try fetchItems(in: context, listID: list.id).allSatisfy { $0.state == .needed })
    }

    @Test func applyLeavesUnrelatedItemsUnchanged() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context)
        let template = try makeTemplate(in: context, list: list)
        let entryUseCases = ItemEntryUseCases(context: context)
        _ = entryUseCases.add(ItemDraft(name: "Sourdough", categoryID: categories[0].id, catalogItemID: nil), to: list.id)
        let itemUseCases = ItemUseCases(context: context)
        if let sourdough = try fetchItems(in: context, listID: list.id).first(where: { $0.name == "Sourdough" }) {
            itemUseCases.complete(sourdough)
        }

        let report = TemplateUseCases(context: context).apply(template, to: list.id)

        #expect(report.changedCount == 0)
        let items = try fetchItems(in: context, listID: list.id)
        #expect(items.count == 3)
        #expect(items.first { $0.name == "Sourdough" }?.state == .completed)
        #expect(items.filter { $0.name != "Sourdough" }.allSatisfy { $0.state == .needed })
    }

    @Test func applyRestoresMetadataFromTheSnapshot() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, _) = TestFixtures.makeList(in: context)
        let template = try makeTemplate(in: context, list: list)
        let itemUseCases = ItemUseCases(context: context)
        for item in try fetchItems(in: context, listID: list.id) {
            itemUseCases.delete(item)
        }

        _ = TemplateUseCases(context: context).apply(template, to: list.id)

        let milk = try fetchItems(in: context, listID: list.id).first { $0.name == "Milk" }
        #expect(milk?.quantity == "2")
        #expect(milk?.unit == "liters")
        #expect(milk?.note == nil)
    }
}

@Suite("Template rename and delete")
struct TemplateRenameDeleteTests {
    @Test func renameUpdatesName() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context)
        let entryUseCases = ItemEntryUseCases(context: context)
        _ = entryUseCases.add(ItemDraft(name: "Milk", categoryID: categories[0].id, catalogItemID: nil), to: list.id)
        let useCases = TemplateUseCases(context: context)
        #expect(useCases.save(named: "Weekly", for: list.id) == .saved)
        let template = try fetchTemplates(in: context, listID: list.id).first!

        #expect(useCases.rename(template, to: "  Bakery  ") == true)
        #expect(template.name == "Bakery")
        #expect(useCases.templates(for: list.id).map(\.name) == ["Bakery"])
    }

    @Test func renameRejectsBlankAndDuplicateNames() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context)
        let entryUseCases = ItemEntryUseCases(context: context)
        _ = entryUseCases.add(ItemDraft(name: "Milk", categoryID: categories[0].id, catalogItemID: nil), to: list.id)
        let useCases = TemplateUseCases(context: context)
        #expect(useCases.save(named: "Weekly", for: list.id) == .saved)
        #expect(useCases.save(named: "Bakery", for: list.id) == .saved)
        let weekly = try fetchTemplates(in: context, listID: list.id).first { $0.name == "Weekly" }!

        #expect(useCases.rename(weekly, to: "  ") == false)
        #expect(useCases.rename(weekly, to: "bakery") == false)
        #expect(weekly.name == "Weekly")
    }

    @Test func deleteRemovesOnlyTheTemplate() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let (list, categories) = TestFixtures.makeList(in: context)
        let entryUseCases = ItemEntryUseCases(context: context)
        _ = entryUseCases.add(ItemDraft(name: "Milk", categoryID: categories[0].id, catalogItemID: nil), to: list.id)
        let useCases = TemplateUseCases(context: context)
        #expect(useCases.save(named: "Weekly", for: list.id) == .saved)
        let template = try fetchTemplates(in: context, listID: list.id).first!

        useCases.delete(template)

        #expect(try fetchTemplates(in: context, listID: list.id).isEmpty)
        #expect(try fetchItems(in: context, listID: list.id).map(\.name) == ["Milk"])
    }
}
