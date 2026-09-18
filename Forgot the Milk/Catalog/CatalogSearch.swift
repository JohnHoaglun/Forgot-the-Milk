import Foundation

enum CatalogSearch {
    static func matches(query: String, label: String) -> Bool {
        let normalizedQuery = ItemLabel.normalize(query)
        guard !normalizedQuery.isEmpty else { return true }
        return ItemLabel.normalize(label).contains(normalizedQuery)
    }
}
