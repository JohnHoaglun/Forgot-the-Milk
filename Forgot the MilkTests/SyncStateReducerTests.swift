import Foundation
import Testing

@testable import Forgot_the_Milk

@Suite("Sync state reducer")
struct SyncStateReducerTests {
    @Test func initialStateIsIdle() {
        let state = SyncState()
        #expect(state.status == .idle)
        #expect(state.pendingCount == 0)
        #expect(state.lastSyncedAt == nil)
        #expect(state.rejectedCount == 0)
        #expect(state.needsReconcile == false)
    }

    @Test func reconcileStartedMovesToSyncing() {
        var state = SyncState()
        state = SyncReducer.reduce(state, .reconcileStarted)
        #expect(state.status == .syncing)
        #expect(state.needsReconcile == false)
    }

    @Test func successfulReconcileReturnsToIdleAndRecordsSyncTime() {
        let syncedAt = Date(timeIntervalSinceReferenceDate: 1_000)
        var report = ReconcileReport()
        report.pushedCount = 2
        report.pulledCount = 1
        report.syncedAt = syncedAt

        var state = SyncState()
        state = SyncReducer.reduce(state, .reconcileStarted)
        state = SyncReducer.reduce(state, .reconcileCompleted(report))
        #expect(state.status == .idle)
        #expect(state.lastSyncedAt == syncedAt)
        #expect(state.pendingCount == 0)
        #expect(state.rejectedCount == 0)
    }

    @Test func failedReconcileSurfacesErrorKindAndKeepsPendingCount() {
        var report = ReconcileReport()
        report.failure = .network
        report.remainingPendingCount = 3

        var state = SyncState()
        state = SyncReducer.reduce(state, .reconcileStarted)
        state = SyncReducer.reduce(state, .reconcileCompleted(report))
        #expect(state.status == .error(.network))
        #expect(state.pendingCount == 3)
        #expect(state.lastSyncedAt == nil)
    }

    @Test func retryFromErrorStartsSyncing() {
        var state = SyncState()
        var report = ReconcileReport()
        report.failure = .network
        state = SyncReducer.reduce(state, .reconcileCompleted(report))
        #expect(state.status == .error(.network))
        state = SyncReducer.reduce(state, .retryRequested)
        #expect(state.status == .syncing)
        #expect(state.needsReconcile == true)
    }

    @Test func retryIsIgnoredOutsideErrorState() {
        var state = SyncState()
        state = SyncReducer.reduce(state, .retryRequested)
        #expect(state.status == .idle)
    }

    @Test func goingOfflineMovesIdleToOffline() {
        var state = SyncState()
        state = SyncReducer.reduce(state, .connectivityChanged(isOnline: false))
        #expect(state.status == .offline)
    }

    @Test func goingOfflineMovesSyncingToOffline() {
        var state = SyncState()
        state = SyncReducer.reduce(state, .reconcileStarted)
        state = SyncReducer.reduce(state, .connectivityChanged(isOnline: false))
        #expect(state.status == .offline)
    }

    @Test func reconnectFromOfflineStartsSyncing() {
        var state = SyncState()
        state = SyncReducer.reduce(state, .connectivityChanged(isOnline: false))
        state = SyncReducer.reduce(state, .connectivityChanged(isOnline: true))
        #expect(state.status == .syncing)
        #expect(state.needsReconcile == true)
    }

    @Test func errorStateWaitsForExplicitRetryOnReconnect() {
        var state = SyncState()
        var report = ReconcileReport()
        report.failure = .authentication
        state = SyncReducer.reduce(state, .reconcileCompleted(report))
        state = SyncReducer.reduce(state, .connectivityChanged(isOnline: true))
        #expect(state.status == .error(.authentication))
    }

    @Test func offlineStaysOfflineWithoutReconnect() {
        var state = SyncState()
        state = SyncReducer.reduce(state, .connectivityChanged(isOnline: false))
        state = SyncReducer.reduce(state, .localMutationEnqueued)
        #expect(state.status == .offline)
        #expect(state.pendingCount == 1)
        #expect(state.needsReconcile == true)
    }

    @Test func localMutationIncrementsPendingCountWithoutChangingStatus() {
        var state = SyncState()
        state = SyncReducer.reduce(state, .localMutationEnqueued)
        state = SyncReducer.reduce(state, .localMutationEnqueued)
        #expect(state.pendingCount == 2)
        #expect(state.needsReconcile == true)
        #expect(state.status == .idle)
    }

    @Test func partialFailureReportsErrorAndKeepsRemainingPending() {
        var state = SyncState()
        for _ in 0..<3 {
            state = SyncReducer.reduce(state, .localMutationEnqueued)
        }
        state = SyncReducer.reduce(state, .reconcileStarted)
        var report = ReconcileReport()
        report.pushedCount = 1
        report.remainingPendingCount = 2
        report.failure = .partialFailure
        state = SyncReducer.reduce(state, .reconcileCompleted(report))
        #expect(state.status == .error(.partialFailure))
        #expect(state.pendingCount == 2)
    }

    @Test func rejectedMutationsAreCountedWhenReconcileSucceeds() {
        let syncedAt = Date(timeIntervalSinceReferenceDate: 2_000)
        var report = ReconcileReport()
        report.rejectedCount = 1
        report.syncedAt = syncedAt

        var state = SyncState()
        state = SyncReducer.reduce(state, .reconcileStarted)
        state = SyncReducer.reduce(state, .reconcileCompleted(report))
        #expect(state.status == .idle)
        #expect(state.rejectedCount == 1)
        #expect(state.lastSyncedAt == syncedAt)
    }
}
