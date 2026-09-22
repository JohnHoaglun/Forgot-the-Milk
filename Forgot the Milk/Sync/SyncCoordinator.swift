import Foundation
import Observation
import OSLog
import SwiftData

@MainActor
@Observable
final class SyncCoordinator {
    private(set) var state: SyncState = SyncState()
    private(set) var shareInfo: ShareInfo?

    private let reconciler: SyncReconciler
    private let client: any CloudKitClient
    private let connectivity: any ConnectivityMonitoring
    private let logger = Logger(subsystem: "com.hoaglun.forgotthemilk", category: "sync")
    private var reconcileTask: Task<Void, Never>?

    var isReconciling: Bool { reconcileTask != nil }

    init(
        context: ModelContext,
        client: any CloudKitClient,
        connectivity: any ConnectivityMonitoring,
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.connectivity = connectivity
        self.reconciler = SyncReconciler(context: context, client: client, defaults: defaults)
        client.onShareChange = { [weak self] info in
            self?.shareInfo = info
        }
        connectivity.setChangeHandler { [weak self] isOnline in
            self?.connectivityChanged(isOnline: isOnline)
        }
    }

    func start() {
        guard connectivity.isOnline else {
            state = SyncReducer.reduce(state, .connectivityChanged(isOnline: false))
            return
        }
        scheduleReconcile(trigger: "launch")
    }

    func foreground() {
        if connectivity.isOnline {
            scheduleReconcile(trigger: "foreground")
        }
        Task { [weak self] in
            await self?.refreshShareInfo()
        }
    }

    func retry() {
        state = SyncReducer.reduce(state, .retryRequested)
        guard case .syncing = state.status else { return }
        scheduleReconcile(trigger: "retry")
    }

    func connectivityChanged(isOnline: Bool) {
        state = SyncReducer.reduce(state, .connectivityChanged(isOnline: isOnline))
        if isOnline {
            scheduleReconcile(trigger: "connectivity")
        }
    }

    func refreshShareInfo() async {
        switch await client.fetchShareInfo() {
        case .success(let info):
            shareInfo = info
        case .failure:
            break
        }
    }

    private func scheduleReconcile(trigger: String) {
        guard reconcileTask == nil else { return }
        state = SyncReducer.reduce(state, .reconcileStarted)
        logger.debug("Reconcile started (\(trigger, privacy: .public))")
        reconcileTask = Task { [weak self] in
            guard let self else { return }
            let report = await self.reconciler.reconcile()
            self.finishReconcile(report, trigger: trigger)
        }
    }

    private func finishReconcile(_ report: ReconcileReport, trigger: String) {
        state = SyncReducer.reduce(state, .reconcileCompleted(report))
        logger.debug(
            "Reconcile finished (\(trigger, privacy: .public), pushed \(report.pushedCount), pulled \(report.pulledCount), pending \(report.remainingPendingCount))"
        )
        reconcileTask = nil
    }
}
