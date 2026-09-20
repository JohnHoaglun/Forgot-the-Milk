import Foundation

enum SyncMutation: Hashable {
    case upsert(SyncRecord)
    case delete(SyncEntityType, UUID)

    var entityID: UUID {
        switch self {
        case .upsert(let record):
            return record.id
        case .delete(_, let entityID):
            return entityID
        }
    }
}

struct PendingMutation: Identifiable, Hashable {
    let id: UUID
    let mutation: SyncMutation
    let enqueuedAt: Date
    let sequence: Int
}

struct MutationQueue {
    private var entries: [UUID: PendingMutation] = [:]
    private var nextSequence = 0

    var count: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }
    var entityIDs: Set<UUID> { Set(entries.keys) }

    var pending: [PendingMutation] {
        entries.values.sorted { $0.sequence < $1.sequence }
    }

    func entry(for entityID: UUID) -> PendingMutation? {
        entries[entityID]
    }

    mutating func enqueue(_ mutation: SyncMutation, at date: Date) {
        let existing = entries[mutation.entityID]
        let sequence = existing?.sequence ?? nextSequence
        if existing == nil {
            nextSequence += 1
        }
        entries[mutation.entityID] = PendingMutation(
            id: mutation.entityID,
            mutation: mutation,
            enqueuedAt: date,
            sequence: sequence
        )
    }

    mutating func remove(_ entityIDs: Set<UUID>) {
        for entityID in entityIDs {
            entries.removeValue(forKey: entityID)
        }
    }

    mutating func removeAll() {
        entries.removeAll()
    }
}

struct SyncBaselines: Equatable {
    private var byEntityID: [UUID: Date] = [:]

    var count: Int { byEntityID.count }
    var all: [UUID: Date] { byEntityID }

    subscript(entityID: UUID) -> Date? {
        get { byEntityID[entityID] }
        set { byEntityID[entityID] = newValue }
    }

    mutating func set(_ entityID: UUID, _ serverModifiedAt: Date) {
        byEntityID[entityID] = serverModifiedAt
    }

    mutating func remove(_ entityID: UUID) {
        byEntityID.removeValue(forKey: entityID)
    }

    mutating func removeAll() {
        byEntityID.removeAll()
    }
}
