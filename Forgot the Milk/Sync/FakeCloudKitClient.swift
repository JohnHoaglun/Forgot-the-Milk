#if DEBUG
import Foundation

final class FakeCloudKitServer {
    struct StoredRecord: Equatable {
        let record: SyncRecord
        let serverModifiedAt: Date
        let writtenBy: String
    }

    var serverNow: Date
    private(set) var share: ShareInfo?

    private var records: [SyncEntityType: [UUID: StoredRecord]] = [:]
    private var tombstones: [SyncEntityType: [UUID: Date]] = [:]
    private var shareChangeHandlers: [String: (ShareInfo) -> Void] = [:]
    private var defaultParticipantPermission: SharePermission = .readWrite

    init(serverNow: Date = Date(timeIntervalSinceReferenceDate: 1_000_000)) {
        self.serverNow = serverNow
    }

    func put(_ record: SyncRecord, writtenBy deviceID: String) -> Date {
        let stamp = serverNow
        records[record.type, default: [:]][record.id] = StoredRecord(
            record: record,
            serverModifiedAt: stamp,
            writtenBy: deviceID
        )
        tombstones[record.type, default: [:]][record.id] = nil
        return stamp
    }

    @discardableResult
    func remove(_ entityType: SyncEntityType, _ entityID: UUID) -> Date? {
        guard records[entityType]?[entityID] != nil else { return nil }
        let stamp = serverNow
        records[entityType, default: [:]][entityID] = nil
        tombstones[entityType, default: [:]][entityID] = stamp
        return stamp
    }

    func snapshot(for deviceID: String) -> SyncPullResult {
        var fetched: [FetchedSyncRecord] = []
        for type in SyncEntityType.allCases {
            for (entityID, entry) in records[type] ?? [:] {
                fetched.append(FetchedSyncRecord(
                    record: entry.record,
                    serverModifiedAt: entry.serverModifiedAt,
                    shared: entry.writtenBy != deviceID
                ))
            }
        }
        fetched.sort {
            $0.record.type == $1.record.type
                ? $0.record.id.uuidString < $1.record.id.uuidString
                : $0.record.type.rawValue < $1.record.type.rawValue
        }

        var deleted: [SyncDeletion] = []
        for type in SyncEntityType.allCases {
            for (entityID, stamp) in tombstones[type] ?? [:] {
                deleted.append(SyncDeletion(entityType: type, entityID: entityID, serverModifiedAt: stamp))
            }
        }
        deleted.sort {
            $0.entityType == $1.entityType
                ? $0.entityID.uuidString < $1.entityID.uuidString
                : $0.entityType.rawValue < $1.entityType.rawValue
        }

        return SyncPullResult(records: fetched, deletions: deleted)
    }

    func createShare(ownerName: String, defaultParticipantPermission: SharePermission) -> ShareInfo {
        if share == nil {
            self.defaultParticipantPermission = defaultParticipantPermission
            let token = UUID()
            share = ShareInfo(
                shareURL: URL(string: "https://icloud.example/share/\(token.uuidString)")!,
                participants: [ShareParticipant(name: ownerName, isOwner: true, permission: .readWrite, status: .accepted)]
            )
        }
        return share!
    }

    func clearShare() {
        share = nil
        defaultParticipantPermission = .readWrite
    }

    func addParticipant(_ name: String, permission: SharePermission? = nil, status: ShareParticipantStatus) {
        guard var info = share else { return }
        info.participants = info.participants.filter { $0.name != name }
        info.participants.append(ShareParticipant(
            name: name,
            isOwner: false,
            permission: permission ?? defaultParticipantPermission,
            status: status
        ))
        info.participants.sort {
            ($0.isOwner ? 0 : 1, $0.name) < ($1.isOwner ? 0 : 1, $1.name)
        }
        share = info
        broadcast(info)
    }

    func registerShareChangeHandler(for deviceID: String, _ handler: @escaping (ShareInfo) -> Void) {
        shareChangeHandlers[deviceID] = handler
    }

    private func broadcast(_ info: ShareInfo) {
        for handler in shareChangeHandlers.values {
            handler(info)
        }
    }
}

final class FakeCloudKitClient: CloudKitClient {
    let deviceID: String
    let server: FakeCloudKitServer

    var authentication: CloudKitAuthStatus = .authorized
    var onShareChange: ((ShareInfo) -> Void)?
    var fetchFailure: CloudKitClientError?
    var saveFailure: CloudKitClientError?
    var deleteFailure: CloudKitClientError?
    var shareFailure: CloudKitClientError?
    var saveRejections: Set<UUID> = []
    var deleteRejections: Set<UUID> = []

    init(deviceID: String, server: FakeCloudKitServer) {
        self.deviceID = deviceID
        self.server = server
        server.registerShareChangeHandler(for: deviceID) { [weak self] info in
            self?.onShareChange?(info)
        }
    }

    convenience init(deviceID: String) {
        self.init(deviceID: deviceID, server: FakeCloudKitServer())
    }

    static func pair() -> (owner: FakeCloudKitClient, collaborator: FakeCloudKitClient) {
        let server = FakeCloudKitServer()
        return (
            FakeCloudKitClient(deviceID: "owner", server: server),
            FakeCloudKitClient(deviceID: "collaborator", server: server)
        )
    }

    func authenticationStatus() async -> CloudKitAuthStatus {
        authentication
    }

    func fetchSyncRecords() async -> Result<SyncPullResult, CloudKitClientError> {
        guard isAuthorized else { return .failure(.notAuthenticated) }
        if let failure = fetchFailure {
            fetchFailure = nil
            return .failure(failure)
        }
        return .success(server.snapshot(for: deviceID))
    }

    func saveRecords(_ records: [SyncRecord]) async -> Result<SaveResult, CloudKitClientError> {
        guard isAuthorized else { return .failure(.notAuthenticated) }
        if let failure = saveFailure {
            saveFailure = nil
            return .failure(failure)
        }
        var outcomes: [SaveOutcome] = []
        for record in records {
            if saveRejections.contains(record.id) {
                outcomes.append(SaveOutcome(entityID: record.id, accepted: false, serverModifiedAt: nil))
            } else {
                outcomes.append(SaveOutcome(
                    entityID: record.id,
                    accepted: true,
                    serverModifiedAt: server.put(record, writtenBy: deviceID)
                ))
            }
        }
        saveRejections = []
        return .success(SaveResult(outcomes: outcomes))
    }

    func deleteRecords(_ requests: [SyncDeleteRequest]) async -> Result<Set<UUID>, CloudKitClientError> {
        guard isAuthorized else { return .failure(.notAuthenticated) }
        if let failure = deleteFailure {
            deleteFailure = nil
            return .failure(failure)
        }
        var accepted: Set<UUID> = []
        for request in requests where !deleteRejections.contains(request.entityID) {
            if server.remove(request.entityType, request.entityID) != nil {
                accepted.insert(request.entityID)
            }
        }
        deleteRejections = []
        return .success(accepted)
    }

    func createShare(defaultParticipantPermission: SharePermission) async -> Result<ShareInfo, CloudKitClientError> {
        guard isAuthorized else { return .failure(.notAuthenticated) }
        if let failure = shareFailure {
            shareFailure = nil
            return .failure(failure)
        }
        return .success(server.createShare(ownerName: deviceID, defaultParticipantPermission: defaultParticipantPermission))
    }

    func fetchShareInfo() async -> Result<ShareInfo?, CloudKitClientError> {
        guard isAuthorized else { return .failure(.notAuthenticated) }
        return .success(server.share)
    }

    func deleteShare() async -> Result<Void, CloudKitClientError> {
        guard isAuthorized else { return .failure(.notAuthenticated) }
        if let failure = shareFailure {
            shareFailure = nil
            return .failure(failure)
        }
        server.clearShare()
        return .success(())
    }

    private var isAuthorized: Bool { authentication == .authorized }
}
#endif
