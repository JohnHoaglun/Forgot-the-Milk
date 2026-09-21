import Foundation

enum CloudKitClientError: Error, Equatable {
    case notAuthenticated
    case authenticationRestricted
    case containerUnavailable
    case networkUnavailable
    case permissionDenied
    case quotaExceeded
    case conflict
    case unknown(String)
}

enum CloudKitAuthStatus: Equatable {
    case authorized
    case notDetermined
    case restricted
    case unavailable
    case couldNotDetermine
}

enum SharePermission: String, Codable, CaseIterable, Equatable {
    case readOnly
    case readWrite
}

enum ShareParticipantStatus: String, Codable, Equatable {
    case invited
    case accepted
}

struct ShareParticipant: Hashable, Codable, Equatable {
    let name: String
    let isOwner: Bool
    let permission: SharePermission
    let status: ShareParticipantStatus
}

struct ShareInfo: Equatable {
    let shareURL: URL
    var participants: [ShareParticipant]
}

struct FetchedSyncRecord: Equatable {
    let record: SyncRecord
    let serverModifiedAt: Date
    let shared: Bool
}

struct SyncDeletion: Equatable {
    let entityType: SyncEntityType
    let entityID: UUID
    let serverModifiedAt: Date
}

struct SyncPullResult: Equatable {
    var records: [FetchedSyncRecord]
    var deletions: [SyncDeletion]

    init(records: [FetchedSyncRecord] = [], deletions: [SyncDeletion] = []) {
        self.records = records
        self.deletions = deletions
    }
}

struct SyncDeleteRequest: Equatable {
    let entityType: SyncEntityType
    let entityID: UUID
}

struct SaveOutcome: Equatable {
    let entityID: UUID
    let accepted: Bool
    let serverModifiedAt: Date?
}

struct SaveResult: Equatable {
    var outcomes: [SaveOutcome]

    var acceptedIDs: Set<UUID> { Set(outcomes.filter(\.accepted).map(\.entityID)) }
    var rejectedIDs: Set<UUID> { Set(outcomes.filter { !$0.accepted }.map(\.entityID)) }
}

@MainActor
protocol CloudKitClient: AnyObject {
    func authenticationStatus() async -> CloudKitAuthStatus
    func fetchSyncRecords() async -> Result<SyncPullResult, CloudKitClientError>
    func saveRecords(_ records: [SyncRecord]) async -> Result<SaveResult, CloudKitClientError>
    func deleteRecords(_ requests: [SyncDeleteRequest]) async -> Result<Set<UUID>, CloudKitClientError>
    func createShare(defaultParticipantPermission: SharePermission) async -> Result<ShareInfo, CloudKitClientError>
    func fetchShareInfo() async -> Result<ShareInfo?, CloudKitClientError>
    func deleteShare() async -> Result<Void, CloudKitClientError>
    var onShareChange: ((ShareInfo) -> Void)? { get set }
}
