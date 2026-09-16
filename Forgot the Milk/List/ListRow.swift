import Foundation
import SwiftUI

struct ListRow: View {
    let item: ListItem
    let onToggle: () -> Void

    private var isCompleted: Bool {
        item.state == .completed
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCompleted ? "Mark \(item.name) as needed" : "Mark \(item.name) as completed")
            .accessibilityHint("Double tap to toggle the item's status")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))

                if let summary = summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("list-item-\(item.id)")
    }

    private var summary: String? {
        var parts: [String] = []
        let quantityPart = [item.quantity, item.unit].compactMap { $0 }.joined(separator: " ")
        if !quantityPart.isEmpty {
            parts.append(quantityPart)
        }
        if let note = item.note, !note.isEmpty {
            parts.append(note)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }
}
