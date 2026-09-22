import Foundation

struct RemoteRecord: Hashable {
    let record: SyncRecord
    let serverModifiedAt: Date
}

struct ConflictResolution: Equatable {
    enum Outcome: Equatable {
        case noChange
        case pushLocal
        case adoptRemote
    }

    let outcome: Outcome
    let rejectedLocal: Bool
    let newBaseline: Date?
}

nonisolated struct ConflictPolicy {
    func resolve(local: SyncRecord?, localIsDirty: Bool, baseline: Date?, remote: RemoteRecord?) -> ConflictResolution {
        guard let remote else {
            guard local != nil else {
                return ConflictResolution(outcome: .noChange, rejectedLocal: false, newBaseline: nil)
            }
            if localIsDirty {
                return ConflictResolution(outcome: .pushLocal, rejectedLocal: false, newBaseline: nil)
            }
            if baseline == nil {
                return ConflictResolution(outcome: .pushLocal, rejectedLocal: false, newBaseline: nil)
            }
            return ConflictResolution(outcome: .adoptRemote, rejectedLocal: false, newBaseline: nil)
        }

        guard local != nil else {
            return ConflictResolution(outcome: .adoptRemote, rejectedLocal: false, newBaseline: remote.serverModifiedAt)
        }

        if !localIsDirty {
            if baseline == remote.serverModifiedAt {
                return ConflictResolution(outcome: .noChange, rejectedLocal: false, newBaseline: nil)
            }
            return ConflictResolution(outcome: .adoptRemote, rejectedLocal: false, newBaseline: remote.serverModifiedAt)
        }

        if let baseline, baseline == remote.serverModifiedAt {
            return ConflictResolution(outcome: .pushLocal, rejectedLocal: false, newBaseline: nil)
        }
        return ConflictResolution(outcome: .adoptRemote, rejectedLocal: true, newBaseline: remote.serverModifiedAt)
    }
}
