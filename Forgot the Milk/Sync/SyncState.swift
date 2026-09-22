import Foundation

enum SyncErrorKind: String, CaseIterable, Codable, Hashable {
    case authentication
    case permissionDenied
    case quota
    case network
    case partialFailure
    case conflict
    case unknown
}

enum SyncStatus: Equatable {
    case idle
    case syncing
    case offline
    case error(SyncErrorKind)
}

struct SyncState: Equatable {
    var status: SyncStatus = .idle
    var pendingCount: Int = 0
    var lastSyncedAt: Date?
    var rejectedCount: Int = 0
    var needsReconcile: Bool = false
}

struct ReconcileReport: Equatable {
    var pushedCount: Int = 0
    var pulledCount: Int = 0
    var rejectedCount: Int = 0
    var remainingPendingCount: Int = 0
    var sharedHouseholdListIDs: Set<UUID> = []
    var failure: SyncErrorKind?
    var syncedAt: Date?
}

struct RejectedMutation: Identifiable, Equatable {
    enum Reason: Equatable {
        case supersededByRemote
    }

    let id: UUID
    let entityType: SyncEntityType
    let reason: Reason
    let rejectedAt: Date
    let localRecord: SyncRecord
}

enum SyncAction: Equatable {
    case connectivityChanged(isOnline: Bool)
    case localMutationEnqueued
    case reconcileStarted
    case reconcileCompleted(ReconcileReport)
    case retryRequested
}

enum SyncReducer {
    static func reduce(_ current: SyncState, _ action: SyncAction) -> SyncState {
        var state = current
        switch action {
        case .connectivityChanged(let isOnline):
            if isOnline {
                if case .offline = state.status {
                    state.status = .syncing
                }
                state.needsReconcile = true
            } else {
                switch state.status {
                case .idle, .syncing:
                    state.status = .offline
                case .offline, .error:
                    break
                }
            }
        case .localMutationEnqueued:
            state.pendingCount += 1
            state.needsReconcile = true
        case .reconcileStarted:
            state.status = .syncing
            state.needsReconcile = false
        case .reconcileCompleted(let report):
            state.pendingCount = report.remainingPendingCount
            state.rejectedCount = report.rejectedCount
            if let failure = report.failure {
                state.status = .error(failure)
            } else {
                state.status = .idle
                state.lastSyncedAt = report.syncedAt
            }
        case .retryRequested:
            if case .error = state.status {
                state.status = .syncing
                state.needsReconcile = true
            }
        }
        return state
    }
}
