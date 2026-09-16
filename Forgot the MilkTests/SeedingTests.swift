import Foundation
import SwiftData
import Testing

@testable import Forgot_the_Milk

@Suite
struct SeedingTests {
    @Test
    func freshSeedCreatesExpectedCatalog() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        try AppSeeding.seedIfNeeded(context: context)

        let lists = try context.fetch(FetchDescriptor<HouseholdList>())
        let categories = try context.fetch(FetchDescriptor<Category>())
        let items = try context.fetch(FetchDescriptor<CatalogItem>())

        #expect(lists.count == 1)
        #expect(lists.first?.title == "My List")
        #expect(categories.count == 26)
        #expect(items.count == 256)
        #expect(items.allSatisfy { $0.scope == .builtIn })

        let list = try #require(lists.first)
        #expect(list.categoryOrder.count == 26)
        let categoryIDs = Set(categories.map(\.id))
        #expect(list.categoryOrder.allSatisfy { categoryIDs.contains($0) })
    }

    @Test
    func seedIsIdempotent() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        try AppSeeding.seedIfNeeded(context: context)
        try AppSeeding.seedIfNeeded(context: context)

        let lists = try context.fetch(FetchDescriptor<HouseholdList>())
        let categories = try context.fetch(FetchDescriptor<Category>())
        let items = try context.fetch(FetchDescriptor<CatalogItem>())

        #expect(lists.count == 1)
        #expect(categories.count == 26)
        #expect(items.count == 256)

        let uniqueCategoryNames = Set(categories.map(\.name))
        #expect(uniqueCategoryNames.count == categories.count)

        var uniqueItemPairs = Set<String>()
        for item in items {
            uniqueItemPairs.insert("\(item.categoryID)|\(item.name)")
        }
        #expect(uniqueItemPairs.count == items.count)
    }

    @Test
    func relaunchPersistsData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        do {
            let first = try TestStore.makeFileContainer(directory: directory)
            let firstContext = TestStore.makeContext(first)
            try AppSeeding.seedIfNeeded(context: firstContext)
        }

        let second = try TestStore.makeFileContainer(directory: directory, cleanExisting: false)
        let secondContext = TestStore.makeContext(second)

        let lists = try secondContext.fetch(FetchDescriptor<HouseholdList>())
        let categories = try secondContext.fetch(FetchDescriptor<Category>())
        let items = try secondContext.fetch(FetchDescriptor<CatalogItem>())

        #expect(lists.count == 1)
        #expect(categories.count == 26)
        #expect(items.count == 256)
    }

    @Test
    func seededCatalogMatchesSeedData() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        try AppSeeding.seedIfNeeded(context: context)

        let categories = try context.fetch(FetchDescriptor<Category>())
        let items = try context.fetch(FetchDescriptor<CatalogItem>())
        var categoryNames: [UUID: String] = [:]
        for category in categories {
            categoryNames[category.id] = category.name
        }

        let seeded = Set(items.map {
            normalize(categoryNames[$0.categoryID] ?? "") + "\u{0}" + normalize($0.name)
        })
        let expected = Set(SeedCatalog.entries.map {
            normalize($0.category) + "\u{0}" + normalize($0.label)
        })

        #expect(seeded == expected)
    }

    @Test
    func seededCategoryOrderFollowsSeedOrder() throws {
        let container = try TestStore.makeInMemoryContainer()
        let context = TestStore.makeContext(container)
        try AppSeeding.seedIfNeeded(context: context)

        let lists = try context.fetch(FetchDescriptor<HouseholdList>())
        let list = try #require(lists.first)
        let categories = try context.fetch(FetchDescriptor<Category>())
        var orders: [UUID: Int] = [:]
        for category in categories {
            orders[category.id] = category.defaultOrder
        }

        let sequence = list.categoryOrder.compactMap { orders[$0] }
        #expect(sequence == Array(0...25))
    }

    private func normalize(_ value: String) -> String {
        let collapsed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
