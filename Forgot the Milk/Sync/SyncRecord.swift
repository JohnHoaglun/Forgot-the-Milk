import Foundation

enum SyncEntityType: String, CaseIterable, Codable, Hashable {
    case householdList
    case category
    case catalogItem
    case listItem
    case template

    var cloudKitType: String {
        switch self {
        case .householdList:
            return "HouseholdList"
        case .category:
            return "Category"
        case .catalogItem:
            return "CatalogItem"
        case .listItem:
            return "ListItem"
        case .template:
            return "Template"
        }
    }
}

struct HouseholdListPayload: Hashable, Codable {
    let id: UUID
    var title: String
    var categoryOrder: [UUID]
    var createdAt: Date
    var updatedAt: Date
}

struct CategoryPayload: Hashable, Codable {
    let id: UUID
    var name: String
    var defaultOrder: Int
    var isSystem: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct CatalogItemPayload: Hashable, Codable {
    let id: UUID
    var name: String
    var categoryID: UUID
    var defaultQuantity: String?
    var defaultUnit: String?
    var defaultNote: String?
    var scope: CatalogScope
    var createdAt: Date
    var updatedAt: Date
}

struct ListItemPayload: Hashable, Codable {
    let id: UUID
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
}

struct TemplatePayload: Hashable, Codable {
    let id: UUID
    var listID: UUID
    var name: String
    var entries: [TemplateEntry]
    var createdAt: Date
    var updatedAt: Date
}

enum SyncRecord: Hashable, Codable {
    case householdList(HouseholdListPayload)
    case category(CategoryPayload)
    case catalogItem(CatalogItemPayload)
    case listItem(ListItemPayload)
    case template(TemplatePayload)

    var id: UUID {
        switch self {
        case .householdList(let payload):
            return payload.id
        case .category(let payload):
            return payload.id
        case .catalogItem(let payload):
            return payload.id
        case .listItem(let payload):
            return payload.id
        case .template(let payload):
            return payload.id
        }
    }

    var type: SyncEntityType {
        switch self {
        case .householdList:
            return .householdList
        case .category:
            return .category
        case .catalogItem:
            return .catalogItem
        case .listItem:
            return .listItem
        case .template:
            return .template
        }
    }

    var updatedAt: Date {
        switch self {
        case .householdList(let payload):
            return payload.updatedAt
        case .category(let payload):
            return payload.updatedAt
        case .catalogItem(let payload):
            return payload.updatedAt
        case .listItem(let payload):
            return payload.updatedAt
        case .template(let payload):
            return payload.updatedAt
        }
    }
}
