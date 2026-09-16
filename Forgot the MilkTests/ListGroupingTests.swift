import Foundation
import Testing

@testable import Forgot_the_Milk

@Suite
struct ListGroupingTests {
    @Test
    func categoryOrderIsRespected() {
        let first = Category(name: "First", defaultOrder: 0)
        let second = Category(name: "Second", defaultOrder: 1)
        let list = HouseholdList(title: "List", categoryOrder: [second.id, first.id])
        let itemA = ListItem(listID: list.id, name: "A", categoryID: first.id, sortOrder: 0)
        let itemB = ListItem(listID: list.id, name: "B", categoryID: second.id, sortOrder: 0)

        let grouped = ListGrouping.group(
            categories: [first, second],
            items: [itemA, itemB],
            categoryOrder: list.categoryOrder
        )

        #expect(grouped.sections.count == 2)
        #expect(grouped.sections[0].categoryID == second.id)
        #expect(grouped.sections[1].categoryID == first.id)
    }

    @Test
    func sortOrderAscendingWithinCategory() {
        let category = Category(name: "C", defaultOrder: 0)
        let list = HouseholdList(title: "List", categoryOrder: [category.id])
        let item1 = ListItem(listID: list.id, name: "One", categoryID: category.id, sortOrder: 1)
        let item2 = ListItem(listID: list.id, name: "Two", categoryID: category.id, sortOrder: 2)
        let item3 = ListItem(listID: list.id, name: "Three", categoryID: category.id, sortOrder: 3)

        let grouped = ListGrouping.group(
            categories: [category],
            items: [item2, item1, item3],
            categoryOrder: list.categoryOrder
        )

        #expect(grouped.sections.count == 1)
        #expect(grouped.sections[0].items.map(\.sortOrder) == [1, 2, 3])
    }

    @Test
    func completedItemsAreSeparated() {
        let category = Category(name: "C", defaultOrder: 0)
        let list = HouseholdList(title: "List", categoryOrder: [category.id])
        let needed = ListItem(listID: list.id, name: "N", categoryID: category.id, sortOrder: 0)
        let done = ListItem(listID: list.id, name: "D", categoryID: category.id, state: .completed, sortOrder: 1)

        let grouped = ListGrouping.group(
            categories: [category],
            items: [needed, done],
            categoryOrder: list.categoryOrder
        )

        #expect(grouped.sections.first?.items.map(\.id) == [needed.id])
        #expect(grouped.completed.map(\.id) == [done.id])
        #expect(grouped.totalNeeded == 1)
    }

    @Test
    func emptyCategoriesAreOmitted() {
        let used = Category(name: "Used", defaultOrder: 0)
        let empty = Category(name: "Empty", defaultOrder: 1)
        let list = HouseholdList(title: "List", categoryOrder: [empty.id, used.id])
        let item = ListItem(listID: list.id, name: "X", categoryID: used.id, sortOrder: 0)

        let grouped = ListGrouping.group(
            categories: [used, empty],
            items: [item],
            categoryOrder: list.categoryOrder
        )

        #expect(grouped.sections.count == 1)
        #expect(grouped.sections.first?.categoryID == used.id)
    }

    @Test
    func totalNeededSumsSections() {
        let a = Category(name: "A", defaultOrder: 0)
        let b = Category(name: "B", defaultOrder: 1)
        let list = HouseholdList(title: "List", categoryOrder: [a.id, b.id])
        let items = [
            ListItem(listID: list.id, name: "1", categoryID: a.id, sortOrder: 0),
            ListItem(listID: list.id, name: "2", categoryID: a.id, sortOrder: 1),
            ListItem(listID: list.id, name: "3", categoryID: b.id, sortOrder: 0),
        ]

        let grouped = ListGrouping.group(categories: [a, b], items: items, categoryOrder: list.categoryOrder)

        #expect(grouped.totalNeeded == 3)
        #expect(grouped.sections.map(\.neededCount) == [2, 1])
    }
}
