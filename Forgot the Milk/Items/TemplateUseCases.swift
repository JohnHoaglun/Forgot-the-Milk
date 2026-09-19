import Foundation
import SwiftData

enum TemplateNameValidation {
    enum Issue: Equatable, Hashable {
        case nameRequired
        case nameTooLong
        case nameNotUnique
    }

    static let limit = 80

    static func trimmed(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func issues(for name: String, existing: [Template]) -> [Issue] {
        var issues: [Issue] = []
        let trimmedName = trimmed(name)
        if trimmedName.isEmpty {
            issues.append(.nameRequired)
        } else {
            if trimmedName.count > limit {
                issues.append(.nameTooLong)
            }
            let key = trimmedName.lowercased()
            if existing.contains(where: { trimmed($0.name).lowercased() == key }) {
                issues.append(.nameNotUnique)
            }
        }
        return issues
    }

    static func isValid(_ name: String, existing: [Template]) -> Bool {
        issues(for: name, existing: existing).isEmpty
    }
}

struct TemplateApplyReport: Equatable {
    var added: Int
    var reopened: Int

    var changedCount: Int { added + reopened }
}

enum TemplateSaveResult: Equatable {
    case saved
    case invalidName
    case nothingNeeded
}

struct TemplateUseCases {
    let context: ModelContext

    func templates(for listID: UUID) -> [Template] {
        let descriptor = FetchDescriptor<Template>(predicate: #Predicate { $0.listID == listID })
        let templates = (try? context.fetch(descriptor)) ?? []
        return templates.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    @discardableResult
    func save(named name: String, for listID: UUID) -> TemplateSaveResult {
        let trimmed = TemplateNameValidation.trimmed(name)
        let existing = templates(for: listID)
        guard TemplateNameValidation.isValid(trimmed, existing: existing) else {
            return .invalidName
        }
        let entries = snapshotEntries(for: listID)
        guard !entries.isEmpty else {
            return .nothingNeeded
        }
        let template = Template(listID: listID, name: trimmed, entries: entries)
        context.insert(template)
        save()
        return .saved
    }

    func apply(_ template: Template, to listID: UUID) -> TemplateApplyReport {
        var report = TemplateApplyReport(added: 0, reopened: 0)
        let entryUseCases = ItemEntryUseCases(context: context)
        for entry in template.entries {
            let draft = ItemDraft(
                name: entry.name,
                quantity: entry.quantity,
                unit: entry.unit,
                note: entry.note,
                categoryID: entry.categoryID,
                catalogItemID: entry.catalogItemID
            )
            switch entryUseCases.add(draft, to: listID) {
            case .added: report.added += 1
            case .reopened: report.reopened += 1
            case .alreadyNeeded, .invalid: break
            }
        }
        return report
    }

    @discardableResult
    func rename(_ template: Template, to name: String) -> Bool {
        let trimmed = TemplateNameValidation.trimmed(name)
        let others = templates(for: template.listID).filter { $0.id != template.id }
        guard TemplateNameValidation.isValid(trimmed, existing: others) else {
            return false
        }
        template.name = trimmed
        template.updatedAt = Date()
        save()
        return true
    }

    func delete(_ template: Template) {
        context.delete(template)
        save()
    }

    private func snapshotEntries(for listID: UUID) -> [TemplateEntry] {
        let listDescriptor = FetchDescriptor<HouseholdList>(predicate: #Predicate { $0.id == listID })
        guard let list = (try? context.fetch(listDescriptor))?.first else {
            return []
        }
        let itemDescriptor = FetchDescriptor<ListItem>(predicate: #Predicate { $0.listID == listID })
        let items = (try? context.fetch(itemDescriptor)) ?? []
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let grouped = ListGrouping.group(categories: categories, items: items, categoryOrder: list.categoryOrder)
        return grouped.sections.flatMap { section in
            section.items.map { item in
                TemplateEntry(
                    catalogItemID: item.catalogItemID,
                    name: item.name,
                    categoryID: item.categoryID,
                    quantity: item.quantity,
                    unit: item.unit,
                    note: item.note
                )
            }
        }
    }

    private func save() {
        if context.hasChanges {
            try? context.save()
        }
    }
}
