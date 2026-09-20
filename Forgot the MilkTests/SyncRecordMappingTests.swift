import Foundation
import SwiftData
import Testing

@testable import Forgot_the_Milk

@Suite("Sync record mapping")
struct SyncRecordMappingTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 2_000)

    @Test func householdListRoundTripsAndSkipsShareMetadata() {
        let order = [UUID(), UUID()]
        let model = HouseholdList(
            id: UUID(),
            title: "Milk Run",
            categoryOrder: order,
            shareMetadata: Data([1, 2, 3]),
            createdAt: t0,
            updatedAt: t0.addingTimeInterval(1)
        )
        let record = SyncRecord(householdList: model)
        let copy = HouseholdList(
            id: model.id,
            title: "Old",
            categoryOrder: [],
            createdAt: .distantPast,
            updatedAt: .distantPast
        )
        record.apply(to: copy)

        #expect(record.type == .householdList)
        #expect(record.id == model.id)
        #expect(record.updatedAt == model.updatedAt)
        #expect(copy.title == model.title)
        #expect(copy.categoryOrder == order)
        #expect(copy.createdAt == model.createdAt)
        #expect(copy.updatedAt == model.updatedAt)
        #expect(copy.shareMetadata == nil)
    }

    @Test func categoryRoundTrips() {
        let model = Category(
            id: UUID(),
            name: "Produce",
            defaultOrder: 3,
            isSystem: true,
            createdAt: t0,
            updatedAt: t0.addingTimeInterval(2)
        )
        let record = SyncRecord(category: model)
        let copy = Category(
            id: model.id,
            name: "Old",
            defaultOrder: 0,
            isSystem: false,
            createdAt: .distantPast,
            updatedAt: .distantPast
        )
        record.apply(to: copy)

        #expect(record.type == .category)
        #expect(copy.name == model.name)
        #expect(copy.defaultOrder == model.defaultOrder)
        #expect(copy.isSystem == model.isSystem)
        #expect(copy.createdAt == model.createdAt)
        #expect(copy.updatedAt == model.updatedAt)
    }

    @Test func householdCatalogItemRoundTrips() {
        let model = CatalogItem(
            id: UUID(),
            name: "Oat Milk",
            categoryID: UUID(),
            defaultQuantity: "2",
            defaultUnit: "cartons",
            defaultNote: "barista edition",
            scope: .household,
            createdAt: t0,
            updatedAt: t0.addingTimeInterval(3)
        )
        guard let record = SyncRecord(catalogItem: model) else {
            Issue.record("household catalog item should produce a sync record")
            return
        }
        let copy = CatalogItem(
            id: model.id,
            name: "Old",
            categoryID: UUID(),
            defaultQuantity: nil,
            defaultUnit: nil,
            defaultNote: nil,
            scope: .household,
            createdAt: .distantPast,
            updatedAt: .distantPast
        )
        record.apply(to: copy)

        #expect(record.type == .catalogItem)
        #expect(copy.name == model.name)
        #expect(copy.categoryID == model.categoryID)
        #expect(copy.defaultQuantity == model.defaultQuantity)
        #expect(copy.defaultUnit == model.defaultUnit)
        #expect(copy.defaultNote == model.defaultNote)
        #expect(copy.scope == .household)
        #expect(copy.createdAt == model.createdAt)
        #expect(copy.updatedAt == model.updatedAt)
    }

    @Test func builtInCatalogItemIsNotSynced() {
        let model = CatalogItem(
            id: UUID(),
            name: "Milk",
            categoryID: UUID(),
            defaultQuantity: "1",
            defaultUnit: "gallon",
            defaultNote: nil,
            scope: .builtIn,
            createdAt: t0,
            updatedAt: t0
        )
        #expect(SyncRecord(catalogItem: model) == nil)
    }

    @Test func listItemRoundTrips() {
        let catalogID = UUID()
        let model = ListItem(
            id: UUID(),
            listID: UUID(),
            catalogItemID: catalogID,
            name: "Milk",
            categoryID: UUID(),
            quantity: "2",
            unit: "gallons",
            note: "whole",
            state: .completed,
            sortOrder: 7,
            createdAt: t0,
            updatedAt: t0.addingTimeInterval(4)
        )
        let record = SyncRecord(listItem: model)
        let copy = ListItem(
            id: model.id,
            listID: UUID(),
            catalogItemID: nil,
            name: "Old",
            categoryID: UUID(),
            quantity: nil,
            unit: nil,
            note: nil,
            state: .needed,
            sortOrder: 0,
            createdAt: .distantPast,
            updatedAt: .distantPast
        )
        record.apply(to: copy)

        #expect(record.type == .listItem)
        #expect(record.id == model.id)
        #expect(copy.listID == model.listID)
        #expect(copy.catalogItemID == catalogID)
        #expect(copy.name == model.name)
        #expect(copy.categoryID == model.categoryID)
        #expect(copy.quantity == model.quantity)
        #expect(copy.unit == model.unit)
        #expect(copy.note == model.note)
        #expect(copy.state == .completed)
        #expect(copy.sortOrder == model.sortOrder)
        #expect(copy.createdAt == model.createdAt)
        #expect(copy.updatedAt == model.updatedAt)
    }

    @Test func unlinkedListItemRoundTripsNilCatalogReference() {
        let model = ListItem(
            id: UUID(),
            listID: UUID(),
            catalogItemID: nil,
            name: "Mystery",
            categoryID: UUID(),
            quantity: nil,
            unit: nil,
            note: nil,
            state: .needed,
            sortOrder: 0,
            createdAt: t0,
            updatedAt: t0
        )
        let record = SyncRecord(listItem: model)
        let copy = ListItem(
            id: model.id,
            listID: UUID(),
            catalogItemID: UUID(),
            name: "Old",
            categoryID: UUID(),
            quantity: nil,
            unit: nil,
            note: nil,
            state: .needed,
            sortOrder: 0,
            createdAt: .distantPast,
            updatedAt: .distantPast
        )
        record.apply(to: copy)
        #expect(copy.catalogItemID == nil)
    }

    @Test func templateRoundTripsWithEntries() {
        let entries = [
            TemplateEntry(catalogItemID: UUID(), name: "Milk", categoryID: UUID(), quantity: "1", unit: "gallon", note: nil),
            TemplateEntry(catalogItemID: nil, name: "Bread", categoryID: UUID(), quantity: nil, unit: nil, note: nil)
        ]
        let model = Template(
            id: UUID(),
            listID: UUID(),
            name: "Weekly",
            entries: entries,
            createdAt: t0,
            updatedAt: t0.addingTimeInterval(5)
        )
        let record = SyncRecord(template: model)
        let copy = Template(
            id: model.id,
            listID: UUID(),
            name: "Old",
            entries: [],
            createdAt: .distantPast,
            updatedAt: .distantPast
        )
        record.apply(to: copy)

        #expect(record.type == .template)
        #expect(copy.name == model.name)
        #expect(copy.listID == model.listID)
        #expect(copy.entries == entries)
        #expect(copy.createdAt == model.createdAt)
        #expect(copy.updatedAt == model.updatedAt)
    }
}
