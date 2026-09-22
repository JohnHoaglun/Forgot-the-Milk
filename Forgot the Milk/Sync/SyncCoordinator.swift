import Foundation
import Observation
import OSLog
import SwiftData

@MainActor
@Observable
final class SyncCoordinator {
    private(set) var state: SyncState = SyncState()
    private(set) var shareInfo: ShareInfo?
    private(set) var authStatus: CloudKitAuthStatus?
    private(set) var activeListID: UUID?

    private let context: ModelContext
    private var settings: SettingsStore
    private let reconciler: SyncReconciler
    private let client: any CloudKitClient
    private let connectivity: any ConnectivityMonitoring
    private let shareSheet: any ShareSheetPresenting
    private let logger = Logger(subsystem: "com.hoaglun.forgotthemilk", category: "sync")
    private var reconcileTask: Task<Void, Never>?

    var isReconciling: Bool { reconcileTask != nil }

    init(
        context: ModelContext,
        client: any CloudKitClient,
        connectivity: any ConnectivityMonitoring,
        shareSheet: any ShareSheetPresenting,
        defaults: UserDefaults = .standard
    ) {
        self.context = context
        self.client = client
        self.connectivity = connectivity
        self.shareSheet = shareSheet
        self.settings = SettingsStore(defaults: defaults)
        self.reconciler = SyncReconciler(context: context, client: client, defaults: defaults)
        self.activeListID = settings.activeListID
        client.onShareChange = { [weak self] info in
            Task { @MainActor [weak self] in
                self?.shareInfo = info
            }
        }
        connectivity.setChangeHandler { [weak self] isOnline in
            Task { @MainActor [weak self] in
                self?.connectivityChanged(isOnline: isOnline)
            }
        }
    }

    func start() {
        refreshAuthStatus()
        guard connectivity.isOnline else {
            state = SyncReducer.reduce(state, .connectivityChanged(isOnline: false))
            return
        }
        scheduleReconcile(trigger: "launch")
    }

    func foreground() {
        refreshAuthStatus()
        if connectivity.isOnline {
            scheduleReconcile(trigger: "foreground")
        }
        Task { [weak self] in
            await self?.refreshShareInfo()
        }
    }

    func retry() {
        refreshAuthStatus()
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

    func startSharing() async {
        guard let list = activeHouseholdList else { return }
        if shareInfo == nil {
            switch await client.fetchShareInfo() {
            case .success(let existing):
                shareInfo = existing
            case .failure:
                break
            }
        }
        if shareInfo == nil {
            guard case .success(let info) = await client.createShare(defaultParticipantPermission: .readWrite) else {
                return
            }
            shareInfo = info
        }
        guard let info = shareInfo else { return }
        setActiveList(list.id)
        persistShareMetadata(on: list.id, info: info)
        shareSheet.present(items: [info.shareURL])
    }

    func stopSharing() async {
        guard let info = shareInfo, info.isOwner else { return }
        guard case .success = await client.deleteShare() else { return }
        shareInfo = nil
        clearShareMetadata(on: activeListID)
    }

    func acceptShareURL(_ url: URL) async {
        switch await client.acceptShareURL(url) {
        case .success(let info):
            shareInfo = info
            if connectivity.isOnline {
                scheduleReconcile(trigger: "share-accept")
            }
        case .failure:
            break
        }
    }

    private var activeHouseholdList: HouseholdList? {
        let lists = Self.fetchAll(context, HouseholdList.self)
        if let id = activeListID, let match = lists.first(where: { $0.id == id }) {
            return match
        }
        return lists.first
    }

    private func setActiveList(_ id: UUID) {
        activeListID = id
        settings.activeListID = id
    }

    private func persistShareMetadata(on listID: UUID, info: ShareInfo) {
        guard let list = Self.findHouseholdList(context, id: listID) else { return }
        let metadata = ListShare(shareURL: info.shareURL, isOwner: info.isOwner)
        list.shareMetadata = (try? JSONEncoder().encode(metadata)) ?? nil
        try? context.save()
    }

    private func clearShareMetadata(on listID: UUID?) {
        guard let listID, let list = Self.findHouseholdList(context, id: listID) else { return }
        list.shareMetadata = nil
        try? context.save()
    }

    private func refreshAuthStatus() {
        Task { [weak self] in
            guard let self else { return }
            self.authStatus = await self.client.authenticationStatus()
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
        reconcileTask = nil
        resolveActiveList(from: report.sharedHouseholdListIDs)
        if let info = shareInfo, let activeID = activeListID, report.sharedHouseholdListIDs.contains(activeID) {
            persistShareMetadata(on: activeID, info: info)
        }
        logger.debug(
            "Reconcile finished (\(trigger, privacy: .public), pushed \(report.pushedCount), pulled \(report.pulledCount), pending \(report.remainingPendingCount))"
        )
    }

    private func resolveActiveList(from sharedListIDs: Set<UUID>) {
        guard !sharedListIDs.isEmpty else { return }
        if let current = activeListID, sharedListIDs.contains(current) {
            return
        }
        guard let chosen = sharedListIDs.sorted(by: { $0.uuidString < $1.uuidString }).first else {
            return
        }
        setActiveList(chosen)
        if let info = shareInfo {
            persistShareMetadata(on: chosen, info: info)
        }
    }

    private static func fetchAll<T: PersistentModel>(_ context: ModelContext, _ type: T.Type) -> [T] {
        let descriptor = FetchDescriptor<T>()
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func findHouseholdList(_ context: ModelContext, id: UUID) -> HouseholdList? {
        let descriptor = FetchDescriptor<HouseholdList>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }
}
