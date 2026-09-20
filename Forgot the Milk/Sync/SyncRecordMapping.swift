import Foundation
import SwiftData

extension SyncRecord {
    init?(catalogItem: CatalogItem) {
        guard catalogItem.scope == .household else {
            return nil
        }
        self = .catalogItem(CatalogItemPayload(
            id: catalogItem.id,
            name: catalogItem.name,
            categoryID: catalogItem.categoryID,
            defaultQuantity: catalogItem.defaultQuantity,
            defaultUnit: catalogItem.defaultUnit,
            defaultNote: catalogItem.defaultNote,
            scope: catalogItem.scope,
            createdAt: catalogItem.createdAt,
            updatedAt: catalogItem.updatedAt
        ))
    }

    init(householdList: HouseholdList) {
        self = .householdList(HouseholdListPayload(
            id: householdList.id,
            title: householdList.title,
            categoryOrder: householdList.categoryOrder,
            createdAt: householdList.createdAt,
            updatedAt: householdList.updatedAt
        ))
    }

    init(category: Category) {
        self = .category(CategoryPayload(
            id: category.id,
            name: category.name,
            defaultOrder: category.defaultOrder,
            isSystem: category.isSystem,
            createdAt: category.createdAt,
            updatedAt: category.updatedAt
        ))
    }

    init(listItem: ListItem) {
        self = .listItem(ListItemPayload(
            id: listItem.id,
            listID: listItem.listID,
            catalogItemID: listItem.catalogItemID,
            name: listItem.name,
            categoryID: listItem.categoryID,
            quantity: listItem.quantity,
            unit: listItem.unit,
            note: listItem.note,
            state: listItem.state,
            sortOrder: listItem.sortOrder,
            createdAt: listItem.createdAt,
            updatedAt: listItem.updatedAt
        ))
    }

    init(template: Template) {
        self = .template(TemplatePayload(
            id: template.id,
            listID: template.listID,
            name: template.name,
            entries: template.entries,
            createdAt: template.createdAt,
            updatedAt: template.updatedAt
        ))
    }
}

extension SyncRecord {
    func apply(to householdList: HouseholdList) {
        if case .householdList(let payload) = self {
            householdList.title = payload.title
            householdList.categoryOrder = payload.categoryOrder
            householdList.createdAt = payload.createdAt
            householdList.updatedAt = payload.updatedAt
        }
    }

    func apply(to category: Category) {
        if case .category(let payload) = self {
            category.name = payload.name
            category.defaultOrder = payload.defaultOrder
            category.isSystem = payload.isSystem
            category.createdAt = payload.createdAt
            category.updatedAt = payload.updatedAt
        }
    }

    func apply(to catalogItem: CatalogItem) {
        if case .catalogItem(let payload) = self {
            catalogItem.name = payload.name
            catalogItem.categoryID = payload.categoryID
            catalogItem.defaultQuantity = payload.defaultQuantity
            catalogItem.defaultUnit = payload.defaultUnit
            catalogItem.defaultNote = payload.defaultNote
            catalogItem.scope = payload.scope
            catalogItem.createdAt = payload.createdAt
            catalogItem.updatedAt = payload.updatedAt
        }
    }

    func apply(to listItem: ListItem) {
        if case .listItem(let payload) = self {
            listItem.listID = payload.listID
            listItem.catalogItemID = payload.catalogItemID
            listItem.name = payload.name
            listItem.categoryID = payload.categoryID
            listItem.quantity = payload.quantity
            listItem.unit = payload.unit
            listItem.note = payload.note
            listItem.state = payload.state
            listItem.sortOrder = payload.sortOrder
            listItem.createdAt = payload.createdAt
            listItem.updatedAt = payload.updatedAt
        }
    }

    func apply(to template: Template) {
        if case .template(let payload) = self {
            template.listID = payload.listID
            template.name = payload.name
            template.entries = payload.entries
            template.createdAt = payload.createdAt
            template.updatedAt = payload.updatedAt
        }
    }
}
