import Foundation
import Testing
@testable import Forgot_the_Milk

struct SeedCatalogTests {
    private struct NormalizedKey: Hashable {
        let category: String
        let label: String
    }

    private func normalizedLabel(_ label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    @Test func categoriesCountIs26() {
        #expect(SeedCatalog.categories.count == 26)
    }

    @Test func entriesCountIs256() {
        #expect(SeedCatalog.entries.count == 256)
    }

    @Test func defaultOrdersAreSequential() {
        #expect(SeedCatalog.categories.map(\.defaultOrder) == Array(0...25))
        #expect(SeedCatalog.categories.last?.name == "Other / errands")
    }

    @Test func everyEntryBelongsToACategory() {
        let categoryNames = Set(SeedCatalog.categories.map(\.name))
        for entry in SeedCatalog.entries {
            #expect(categoryNames.contains(entry.category), "Entry '\(entry.label)' belongs to unknown category '\(entry.category)'")
        }
    }

    @Test func noDuplicateNormalizedPairs() {
        let keys = SeedCatalog.entries.map { NormalizedKey(category: $0.category, label: normalizedLabel($0.label)) }
        let unique = Set(keys)
        #expect(unique.count == keys.count, "Duplicate (category, normalized label) pairs found")
    }

    @Test func labelsAreClean() {
        for category in SeedCatalog.categories {
            #expect(!category.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty or whitespace-only category name")
        }
        for entry in SeedCatalog.entries {
            #expect(!entry.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty or whitespace-only label in category '\(entry.category)'")
        }
    }
}
