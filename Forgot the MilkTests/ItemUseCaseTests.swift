import Foundation
import SwiftData
import Testing

@testable import Forgot_the_Milk

@Suite
struct ItemUseCaseTests {
    @Test
    func completeSetsCompletedAndPreservesMetadata() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let fixtures = TestFixtures.makeList(in: context)
        let item = TestFixtures.makeItem(
            in: context,
            list: fixtures.list,
            category: fixtures.categories[0],
            name: "Milk",
            sortOrder: 0,
            quantity: "2",
            unit: "gallon",
            note: "the red one"
        )

        let useCases = ItemUseCases(context: context)
        useCases.complete(item)

        #expect(item.state == .completed)
        #expect(item.quantity == "2")
        #expect(item.unit == "gallon")
        #expect(item.note == "the red one")
        #expect(item.updatedAt >= item.createdAt)
    }

    @Test
    func restoreSetsNeeded() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let fixtures = TestFixtures.makeList(in: context)
        let item = TestFixtures.makeItem(
            in: context,
            list: fixtures.list,
            category: fixtures.categories[0],
            name: "Eggs",
            sortOrder: 0,
            quantity: "12",
            note: "free range"
        )

        let useCases = ItemUseCases(context: context)
        useCases.complete(item)
        useCases.restore(item)

        #expect(item.state == .needed)
        #expect(item.quantity == "12")
        #expect(item.note == "free range")
    }

    @Test
    func deleteRemovesItem() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let fixtures = TestFixtures.makeList(in: context)
        let item = TestFixtures.makeItem(
            in: context,
            list: fixtures.list,
            category: fixtures.categories[0],
            name: "Bread",
            sortOrder: 0
        )

        let useCases = ItemUseCases(context: context)
        useCases.delete(item)

        let itemID = item.id
        let descriptor = FetchDescriptor<ListItem>(predicate: #Predicate { $0.id == itemID })
        let remaining = (try? context.fetch(descriptor)) ?? []
        #expect(remaining.isEmpty)
    }

    @Test
    func clearCompletedRemovesOnlyCompletedForThatList() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        let first = TestFixtures.makeList(in: context, title: "First")
        let second = TestFixtures.makeList(in: context, title: "Second")

        let useCases = ItemUseCases(context: context)

        let firstCompletedA = TestFixtures.makeItem(
            in: context, list: first.list, category: first.categories[0],
            name: "A", sortOrder: 0, state: .completed
        )
        let firstCompletedB = TestFixtures.makeItem(
            in: context, list: first.list, category: first.categories[1],
            name: "B", sortOrder: 1, state: .completed
        )
        let firstNeeded = TestFixtures.makeItem(
            in: context, list: first.list, category: first.categories[0],
            name: "C", sortOrder: 2
        )
        let secondCompleted = TestFixtures.makeItem(
            in: context, list: second.list, category: second.categories[0],
            name: "D", sortOrder: 0, state: .completed
        )

        let deleted = useCases.clearCompleted(listID: first.list.id)

        #expect(deleted == 2)

        let remainingIDs = Set(try context.fetch(FetchDescriptor<ListItem>()).map(\.id))
        #expect(!remainingIDs.contains(firstCompletedA.id))
        #expect(!remainingIDs.contains(firstCompletedB.id))
        #expect(remainingIDs.contains(firstNeeded.id))
        #expect(remainingIDs.contains(secondCompleted.id))
    }
}
