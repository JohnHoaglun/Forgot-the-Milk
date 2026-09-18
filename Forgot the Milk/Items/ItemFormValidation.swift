import Foundation

enum ItemFormValidation {
    enum Issue: Equatable, Hashable {
        case nameRequired
        case nameTooLong
        case quantityTooLong
        case unitTooLong
        case noteTooLong
        case categoryRequired
    }

    static let nameLimit = 120
    static let quantityLimit = 40
    static let unitLimit = 40
    static let noteLimit = 280

    static func issues(for draft: ItemDraft) -> [Issue] {
        var issues: [Issue] = []
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            issues.append(.nameRequired)
        } else if name.count > nameLimit {
            issues.append(.nameTooLong)
        }
        if let quantity = draft.quantity, quantity.count > quantityLimit {
            issues.append(.quantityTooLong)
        }
        if let unit = draft.unit, unit.count > unitLimit {
            issues.append(.unitTooLong)
        }
        if let note = draft.note, note.count > noteLimit {
            issues.append(.noteTooLong)
        }
        if draft.categoryID == nil {
            issues.append(.categoryRequired)
        }
        return issues
    }

    static func isValid(_ draft: ItemDraft) -> Bool {
        issues(for: draft).isEmpty
    }
}
