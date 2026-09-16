import Foundation
import SwiftData

enum ListItemState: Int, Codable, CaseIterable {
    case needed
    case completed
}

enum CatalogScope: Int, Codable, CaseIterable {
    case builtIn
    case household
}

@Model
final class HouseholdList {
    var id: UUID
    var title: String
    var categoryOrder: [UUID]
    var shareMetadata: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        categoryOrder: [UUID] = [],
        shareMetadata: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.categoryOrder = categoryOrder
        self.shareMetadata = shareMetadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class Category {
    var id: UUID
    var name: String
    var defaultOrder: Int
    var isSystem: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        defaultOrder: Int,
        isSystem: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.defaultOrder = defaultOrder
        self.isSystem = isSystem
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class CatalogItem {
    var id: UUID
    var name: String
    var categoryID: UUID
    var defaultQuantity: String?
    var defaultUnit: String?
    var defaultNote: String?
    var scope: CatalogScope
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        categoryID: UUID,
        defaultQuantity: String? = nil,
        defaultUnit: String? = nil,
        defaultNote: String? = nil,
        scope: CatalogScope = .builtIn,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.categoryID = categoryID
        self.defaultQuantity = defaultQuantity
        self.defaultUnit = defaultUnit
        self.defaultNote = defaultNote
        self.scope = scope
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ListItem {
    var id: UUID
    var listID: UUID
    var catalogItemID: UUID?
    var name: String
    var categoryID: UUID
    var quantity: String?
    var unit: String?
    var note: String?
    var state: ListItemState
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        listID: UUID,
        catalogItemID: UUID? = nil,
        name: String,
        categoryID: UUID,
        quantity: String? = nil,
        unit: String? = nil,
        note: String? = nil,
        state: ListItemState = .needed,
        sortOrder: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.listID = listID
        self.catalogItemID = catalogItemID
        self.name = name
        self.categoryID = categoryID
        self.quantity = quantity
        self.unit = unit
        self.note = note
        self.state = state
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class Template {
    var id: UUID
    var listID: UUID
    var name: String
    var entriesData: Data
    var createdAt: Date
    var updatedAt: Date

    var entries: [TemplateEntry] {
        get { (try? JSONDecoder().decode([TemplateEntry].self, from: entriesData)) ?? [] }
        set { entriesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    init(
        id: UUID = UUID(),
        listID: UUID,
        name: String,
        entries: [TemplateEntry] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.listID = listID
        self.name = name
        self.entriesData = (try? JSONEncoder().encode(entries)) ?? Data()
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct TemplateEntry: Codable, Hashable {
    var catalogItemID: UUID?
    var name: String
    var categoryID: UUID
    var quantity: String?
    var unit: String?
    var note: String?
}
