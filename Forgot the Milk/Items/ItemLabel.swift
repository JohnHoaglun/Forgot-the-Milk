import Foundation

enum ItemLabel {
    static func normalize(_ value: String) -> String {
        let collapsed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
