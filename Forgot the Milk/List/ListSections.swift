import Foundation

struct ListSection: Identifiable {
    let categoryID: UUID
    let name: String
    let items: [ListItem]

    var id: UUID { categoryID }
    var neededCount: Int { items.count }
}

struct GroupedList {
    let sections: [ListSection]
    let completed: [ListItem]

    var totalNeeded: Int {
        sections.reduce(0) { $0 + $1.neededCount }
    }
}

enum ListGrouping {
    static func orderedCategories(_ categories: [Category], order: [UUID]) -> [Category] {
        let orderRank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let fallbackRank = Dictionary(categories.map { ($0.id, $0.defaultOrder) }, uniquingKeysWith: { first, _ in first })

        return categories.sorted { lhs, rhs in
            let lhsPrimary = orderRank[lhs.id] ?? Int.max
            let rhsPrimary = orderRank[rhs.id] ?? Int.max
            if lhsPrimary != rhsPrimary { return lhsPrimary < rhsPrimary }
            let lhsSecondary = fallbackRank[lhs.id] ?? Int.max
            let rhsSecondary = fallbackRank[rhs.id] ?? Int.max
            if lhsSecondary != rhsSecondary { return lhsSecondary < rhsSecondary }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    static func group(
        categories: [Category],
        items: [ListItem],
        categoryOrder: [UUID]
    ) -> GroupedList {
        let needed = items.filter { $0.state == .needed }
        let completed = items.filter { $0.state == .completed }

        let neededByCategory = Dictionary(grouping: needed, by: \.categoryID)

        let sections = orderedCategories(categories, order: categoryOrder).compactMap { category -> ListSection? in
            guard let bucket = neededByCategory[category.id], !bucket.isEmpty else { return nil }
            return ListSection(categoryID: category.id, name: category.name, items: ordered(bucket))
        }

        return GroupedList(sections: sections, completed: ordered(completed))
    }

    private static func ordered(_ items: [ListItem]) -> [ListItem] {
        items.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
