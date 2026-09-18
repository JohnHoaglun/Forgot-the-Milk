import Foundation
import SwiftData

struct ListUseCases {
    let context: ModelContext

    func setCategoryOrder(_ order: [UUID], for listID: UUID) {
        let descriptor = FetchDescriptor<HouseholdList>(predicate: #Predicate { $0.id == listID })
        let lists = (try? context.fetch(descriptor)) ?? []
        guard let list = lists.first, list.categoryOrder != order else { return }
        list.categoryOrder = order
        list.updatedAt = Date()
        if context.hasChanges {
            try? context.save()
        }
    }
}
