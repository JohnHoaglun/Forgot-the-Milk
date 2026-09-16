import Foundation
import SwiftData

struct ItemUseCases {
    let context: ModelContext

    func complete(_ item: ListItem) {
        item.state = .completed
        item.updatedAt = Date()
        save()
    }

    func restore(_ item: ListItem) {
        item.state = .needed
        item.updatedAt = Date()
        save()
    }

    func delete(_ item: ListItem) {
        context.delete(item)
        save()
    }

    @discardableResult
    func clearCompleted(listID: UUID) -> Int {
        let descriptor = FetchDescriptor<ListItem>(predicate: #Predicate { $0.listID == listID })
        let all = (try? context.fetch(descriptor)) ?? []
        let completed = all.filter { $0.state == .completed }
        for item in completed {
            context.delete(item)
        }
        save()
        return completed.count
    }

    private func save() {
        if context.hasChanges {
            try? context.save()
        }
    }
}
