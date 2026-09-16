import Foundation
import Testing

@testable import Forgot_the_Milk

@Suite
struct DeterministicIDTests {
    @Test
    func stableForSameInput() {
        #expect(DeterministicID.category("Milk") == DeterministicID.category("Milk"))
        #expect(
            DeterministicID.catalogItem(category: "Dairy", label: "Milk")
                == DeterministicID.catalogItem(category: "Dairy", label: "Milk")
        )
    }

    @Test
    func distinctForDifferentInputs() {
        #expect(DeterministicID.category("A") != DeterministicID.category("B"))
        #expect(
            DeterministicID.catalogItem(category: "Dairy", label: "Milk")
                != DeterministicID.catalogItem(category: "Dairy", label: "Cream")
        )
        #expect(
            DeterministicID.category("Milk")
                != DeterministicID.catalogItem(category: "Dairy", label: "Milk")
        )
    }

    @Test
    func seedIDsAreUnique() {
        let categoryIDs = Set(SeedCatalog.categories.map { DeterministicID.category($0.name) })
        let itemIDs = Set(SeedCatalog.entries.map { DeterministicID.catalogItem(category: $0.category, label: $0.label) })

        #expect(categoryIDs.count == 26)
        #expect(itemIDs.count == 256)
    }
}
