import Foundation

struct SeedCategory: Hashable, Sendable {
    let name: String
    let defaultOrder: Int
}

struct SeedEntry: Hashable, Sendable {
    let category: String
    let label: String
}
