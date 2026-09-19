import Foundation

enum ListExport {
    static func text(categories: [Category], items: [ListItem], categoryOrder: [UUID]) -> String {
        let grouped = ListGrouping.group(categories: categories, items: items, categoryOrder: categoryOrder)
        return text(sections: grouped.sections)
    }

    static func text(sections: [ListSection]) -> String {
        sections
            .map { section in
                let lines = section.items.map { "  \(line(for: $0))" }
                return (["\(section.name)"] + lines).joined(separator: "\n")
            }
            .joined(separator: "\n\n")
    }

    private static func line(for item: ListItem) -> String {
        var parts = [item.name]
        var detail = ""
        if let quantity = item.quantity {
            detail += quantity
        }
        if let unit = item.unit {
            detail += detail.isEmpty ? unit : " \(unit)"
        }
        if !detail.isEmpty {
            parts.append(detail)
        }
        if let note = item.note {
            parts.append(note)
        }
        return parts.joined(separator: " \u{2014} ")
    }
}
