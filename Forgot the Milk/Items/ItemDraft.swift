import Foundation

struct ItemDraft: Equatable {
    var name: String
    var quantity: String?
    var unit: String?
    var note: String?
    var categoryID: UUID?
    var catalogItemID: UUID?
}

enum AddResult: Equatable {
    case added
    case alreadyNeeded
    case reopened
    case invalid
}
