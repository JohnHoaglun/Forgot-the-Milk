import CloudKit
import Foundation
import OSLog

@MainActor
final class RealCloudKitClient: CloudKitClient {
    private static let containerIdentifier = "iCloud.com.hoaglun.forgotthemilk"
    private static let zoneName = "com.hoaglun.forgotthemilk.household"
    private static let shareStoreKey = "com.hoaglun.forgotthemilk.cloudkit.share"
    private static let pageLimit = 2000

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private struct HouseholdZone {
        let database: CKDatabase
        let zoneID: CKRecordZone.ID
        let isShared: Bool
    }

    private let container: CKContainer
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.hoaglun.forgotthemilk", category: "cloudkit")
    private var householdZone: HouseholdZone?
    private var lastObservedShare: ShareInfo?

    var onShareChange: ((ShareInfo) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.container = CKContainer(identifier: Self.containerIdentifier)
        self.defaults = defaults
    }

    private var privateZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: Self.zoneName)
    }

    private func shareRecordID(for zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
    }

    func authenticationStatus() async -> CloudKitAuthStatus {
        let status: CKAccountStatus = await withCheckedContinuation { continuation in
            container.accountStatus { accountStatus, _ in
                continuation.resume(returning: accountStatus)
            }
        }
        switch status {
        case .available:
            return .authorized
        case .restricted:
            return .restricted
        case .noAccount, .temporarilyUnavailable:
            return .unavailable
        case .couldNotDetermine:
            return .couldNotDetermine
        @unknown default:
            return .unavailable
        }
    }

    func fetchSyncRecords() async -> Result<SyncPullResult, CloudKitClientError> {
        do {
            let zone = try await resolveHouseholdZone()
            var fetched: [FetchedSyncRecord] = []
            for type in SyncEntityType.allCases {
                let records: [CKRecord]
                do {
                    records = try await fetchAllRecords(in: zone.database, zoneID: zone.zoneID, type: type)
                } catch let error as CKError where Self.isTolerableQueryFailure(error, type: type) {
                    // A zone created before the first save of a record type reports the
                    // type as missing instead of returning an empty query page, and a
                    // server schema that predates the queryable `updatedAt` field
                    // rejects the query. Both mean "no usable remote data for this
                    // type" and are repaired by the pushes that follow the pull.
                    continue
                }
                for record in records {
                    guard let data = record["payload"] as? Data,
                          let syncRecord = try? Self.decoder.decode(SyncRecord.self, from: data) else {
                        logger.warning("Skipping undecodable record \(record.recordID.recordName, privacy: .public) (\(record.recordType, privacy: .public))")
                        continue
                    }
                    fetched.append(FetchedSyncRecord(
                        record: syncRecord,
                        serverModifiedAt: record.modificationDate ?? .distantPast,
                        shared: zone.isShared
                    ))
                }
            }
            return .success(SyncPullResult(records: fetched, deletions: []))
        } catch {
            return .failure(clientError(error))
        }
    }

    private static func isTolerableQueryFailure(_ error: CKError, type: SyncEntityType) -> Bool {
        let message = (error as NSError).userInfo["ServerErrorDescription"] as? String
        switch error.code {
        case .unknownItem:
            // A zone created before the first save of this type reports the type as
            // missing instead of returning an empty query page.
            return message?.contains("Did not find record type: \(type.cloudKitType)") == true
        case .invalidArguments:
            // A server schema inferred before the queryable `updatedAt` field existed
            // rejects the query ("Unknown field" / "not marked queryable"). The
            // pushes that follow the pull repair the schema.
            return message?.contains("Unknown field") == true
                || message?.contains("not marked queryable") == true
        default:
            return false
        }
    }

    func saveRecords(_ records: [SyncRecord]) async -> Result<SaveResult, CloudKitClientError> {
        guard !records.isEmpty else {
            return .success(SaveResult(outcomes: []))
        }
        do {
            let zone = try await resolveHouseholdZone()
            let ckRecords = records.map { ckRecord(from: $0, zoneID: zone.zoneID) }
            let (saveResults, _) = try await zone.database.modifyRecords(
                saving: ckRecords,
                deleting: [],
                savePolicy: .allKeys,
                atomically: false
            )
            var outcomes: [SaveOutcome] = []
            for record in records {
                let recordID = CKRecord.ID(recordName: record.id.uuidString, zoneID: zone.zoneID)
                switch saveResults[recordID] {
                case .success(let saved):
                    outcomes.append(SaveOutcome(
                        entityID: record.id,
                        accepted: true,
                        serverModifiedAt: saved.modificationDate
                    ))
                case .failure(let error):
                    logger.debug("Save rejected for \(record.id.uuidString, privacy: .public): \(self.errorDescription(error), privacy: .public)")
                    outcomes.append(SaveOutcome(entityID: record.id, accepted: false, serverModifiedAt: nil))
                case nil:
                    outcomes.append(SaveOutcome(entityID: record.id, accepted: false, serverModifiedAt: nil))
                }
            }
            return .success(SaveResult(outcomes: outcomes))
        } catch {
            return .failure(clientError(error))
        }
    }

    func deleteRecords(_ requests: [SyncDeleteRequest]) async -> Result<Set<UUID>, CloudKitClientError> {
        guard !requests.isEmpty else {
            return .success([])
        }
        do {
            let zone = try await resolveHouseholdZone()
            let recordIDs = requests.map {
                CKRecord.ID(recordName: $0.entityID.uuidString, zoneID: zone.zoneID)
            }
            let (_, deleteResults) = try await zone.database.modifyRecords(
                saving: [],
                deleting: recordIDs,
                savePolicy: .ifServerRecordUnchanged,
                atomically: false
            )
            var accepted: Set<UUID> = []
            for request in requests {
                let recordID = CKRecord.ID(recordName: request.entityID.uuidString, zoneID: zone.zoneID)
                switch deleteResults[recordID] {
                case .success:
                    accepted.insert(request.entityID)
                case .failure(let error):
                    logger.debug("Delete rejected for \(request.entityID.uuidString, privacy: .public): \(self.errorDescription(error), privacy: .public)")
                case nil:
                    break
                }
            }
            return .success(accepted)
        } catch {
            return .failure(clientError(error))
        }
    }

    func createShare(defaultParticipantPermission: SharePermission) async -> Result<ShareInfo, CloudKitClientError> {
        do {
            let zone = try await resolveHouseholdZone()
            guard !zone.isShared else {
                return .failure(.permissionDenied)
            }
            let shareRecordID = shareRecordID(for: zone.zoneID)
            if let existing = try await fetchShareRecord(shareRecordID, in: zone.database) {
                guard let info = await shareInfo(of: existing) else {
                    return .failure(.unknown("Share URL unavailable"))
                }
                storeShareURL(info.shareURL)
                return .success(info)
            }
            let share = CKShare(recordZoneID: zone.zoneID)
            share.publicPermission = ckPermission(defaultParticipantPermission)
            let (saveResults, _) = try await zone.database.modifyRecords(
                saving: [share],
                deleting: [],
                savePolicy: .ifServerRecordUnchanged,
                atomically: false
            )
            switch saveResults[shareRecordID] {
            case .success:
                var info = await shareInfo(of: share)
                if info == nil, let fetched = try? await fetchShareRecord(shareRecordID, in: zone.database) {
                    info = await shareInfo(of: fetched)
                }
                guard let info else {
                    logger.warning("Share saved but URL is unavailable")
                    return .failure(.unknown("Share URL unavailable"))
                }
                storeShareURL(info.shareURL)
                return .success(info)
            case .failure(let error):
                return .failure(clientError(error))
            case nil:
                return .failure(.unknown("Share save result missing"))
            }
        } catch {
            return .failure(clientError(error))
        }
    }

    func fetchShareInfo() async -> Result<ShareInfo?, CloudKitClientError> {
        guard let storedURL = storedShareURL() else {
            return .success(nil)
        }
        do {
            let metadata = try await container.shareMetadata(for: storedURL)
            let info = ShareInfo(
                shareURL: storedURL,
                participants: mapParticipants(of: metadata.share),
                isOwner: await isOwner(of: metadata.share)
            )
            observe(info)
            return .success(info)
        } catch let error as CKError where isMissingItem(error) {
            clearStoredShare()
            lastObservedShare = nil
            return .success(nil)
        } catch {
            return .failure(clientError(error))
        }
    }

    func acceptShareURL(_ url: URL) async -> Result<ShareInfo, CloudKitClientError> {
        storeShareURL(url)
        switch await fetchShareInfo() {
        case .success(let info):
            guard let info else {
                return .failure(.unknown("Share URL unavailable"))
            }
            return .success(info)
        case .failure(let error):
            return .failure(error)
        }
    }

    func deleteShare() async -> Result<Void, CloudKitClientError> {
        guard storedShareURL() != nil else {
            return .success(())
        }
        do {
            let zone = try await resolveHouseholdZone()
            let shareRecordID = shareRecordID(for: zone.zoneID)
            let (_, deleteResults) = try await zone.database.modifyRecords(
                saving: [],
                deleting: [shareRecordID],
                savePolicy: .ifServerRecordUnchanged,
                atomically: false
            )
            if case .failure(let error)? = deleteResults[shareRecordID], !isMissingItem(error) {
                return .failure(clientError(error))
            }
            clearStoredShare()
            return .success(())
        } catch {
            return .failure(clientError(error))
        }
    }

    private func fetchShareRecord(_ recordID: CKRecord.ID, in database: CKDatabase) async throws -> CKShare? {
        do {
            let record = try await database.record(for: recordID)
            return record as? CKShare
        } catch let error as CKError where isMissingItem(error) {
            return nil
        }
    }

    private func shareInfo(of share: CKShare) async -> ShareInfo? {
        guard let url = share.url else {
            return nil
        }
        let info = ShareInfo(shareURL: url, participants: mapParticipants(of: share), isOwner: await isOwner(of: share))
        observe(info)
        return info
    }

    private func isOwner(of share: CKShare) async -> Bool {
        guard let myRecordID = try? await container.userRecordID() else {
            return false
        }
        return share.participants.contains { participant in
            participant.userIdentity.userRecordID == myRecordID
                && participant.role == .owner
        }
    }

    private func observe(_ info: ShareInfo) {
        if info != lastObservedShare {
            lastObservedShare = info
            onShareChange?(info)
        }
    }

    private func mapParticipants(of share: CKShare) -> [ShareParticipant] {
        var participants: [ShareParticipant] = []
        for participant in share.participants {
            participants.append(ShareParticipant(
                name: name(of: participant),
                isOwner: participant.role == .owner,
                permission: participant.permission == .readWrite ? .readWrite : .readOnly,
                status: participant.acceptanceStatus == .accepted ? .accepted : .invited
            ))
        }
        participants.sort {
            ($0.isOwner ? 0 : 1, $0.name) < ($1.isOwner ? 0 : 1, $1.name)
        }
        return participants
    }

    private func name(of participant: CKShare.Participant) -> String {
        if participant.role == .owner {
            return "Owner"
        }
        let components = participant.userIdentity.nameComponents
        guard let name = components.map(PersonNameComponentsFormatter().string(from:)), !name.isEmpty else {
            return "Collaborator"
        }
        return name
    }

    private func ckPermission(_ permission: SharePermission) -> CKShare.ParticipantPermission {
        switch permission {
        case .readWrite:
            return .readWrite
        case .readOnly:
            return .readOnly
        }
    }

    private func resolveHouseholdZone() async throws -> HouseholdZone {
        if let zone = householdZone {
            return zone
        }
        let zone = try await discoverHouseholdZone()
        householdZone = zone
        return zone
    }

    private func discoverHouseholdZone() async throws -> HouseholdZone {
        do {
            _ = try await container.privateCloudDatabase.recordZone(for: privateZoneID)
            return HouseholdZone(database: container.privateCloudDatabase, zoneID: privateZoneID, isShared: false)
        } catch let error as CKError where error.code == .zoneNotFound {
            // Not the household owner; look for a shared household zone.
        }
        let zones = try await container.sharedCloudDatabase.allRecordZones()
        let candidates = zones
            .filter { $0.zoneID != .default }
            .sorted { $0.zoneID.zoneName < $1.zoneID.zoneName }
        for zone in candidates {
            let probe = CKQuery(
                recordType: SyncEntityType.householdList.cloudKitType,
                predicate: NSPredicate(format: "updatedAt > %@", Self.queryAnchor as NSDate)
            )
            // A probe failure (e.g. the type has never been saved in this zone)
            // only means this candidate is not a household zone.
            let probed = try? await container.sharedCloudDatabase.records(
                matching: probe,
                inZoneWith: zone.zoneID,
                desiredKeys: nil,
                resultsLimit: 1
            )
            guard let (results, _) = probed, !results.isEmpty else { continue }
            return HouseholdZone(database: container.sharedCloudDatabase, zoneID: zone.zoneID, isShared: true)
        }
        let newZone = CKRecordZone(zoneName: Self.zoneName)
        let result = try await container.privateCloudDatabase.modifyRecordZones(saving: [newZone], deleting: [])
        guard case .success = result.saveResults[privateZoneID] else {
            throw CKError(.internalError)
        }
        return HouseholdZone(database: container.privateCloudDatabase, zoneID: privateZoneID, isShared: false)
    }

    private static let queryAnchor = Date(timeIntervalSinceReferenceDate: 0)

    private func fetchAllRecords(in database: CKDatabase, zoneID: CKRecordZone.ID, type: SyncEntityType) async throws -> [CKRecord] {
        // Query a constant comparison on the known `updatedAt` field: zones whose
        // record type schema was inferred from saves reject field-less predicates.
        let query = CKQuery(
            recordType: type.cloudKitType,
            predicate: NSPredicate(format: "updatedAt > %@", Self.queryAnchor as NSDate)
        )
        var all: [CKRecord] = []
        let (page, cursor) = try await database.records(
            matching: query,
            inZoneWith: zoneID,
            desiredKeys: nil,
            resultsLimit: Self.pageLimit
        )
        appendFetched(page, to: &all)
        var currentCursor: CKQueryOperation.Cursor? = cursor
        while let nextCursor = currentCursor {
            let (page, newCursor) = try await database.records(
                continuingMatchFrom: nextCursor,
                desiredKeys: nil,
                resultsLimit: Self.pageLimit
            )
            appendFetched(page, to: &all)
            currentCursor = newCursor
        }
        return all
    }

    private func appendFetched(_ page: [(CKRecord.ID, Result<CKRecord, any Error>)], to all: inout [CKRecord]) {
        for (recordID, result) in page {
            switch result {
            case .success(let record):
                all.append(record)
            case .failure(let error):
                logger.warning("Skipping record \(recordID.recordName, privacy: .public): \(self.errorDescription(error), privacy: .public)")
            }
        }
    }

    private func ckRecord(from record: SyncRecord, zoneID: CKRecordZone.ID) -> CKRecord {
        let ckRecord = CKRecord(
            recordType: record.type.cloudKitType,
            recordID: CKRecord.ID(recordName: record.id.uuidString, zoneID: zoneID)
        )
        if let data = try? Self.encoder.encode(record) {
            ckRecord["payload"] = data
        }
        // A top-level field so the server's inferred record type schema includes a
        // queryable field: types whose schema was inferred from `payload` alone
        // reject queries.
        ckRecord["updatedAt"] = record.updatedAt
        return ckRecord
    }

    private func storedShareURL() -> URL? {
        guard let raw = defaults.string(forKey: Self.shareStoreKey) else {
            return nil
        }
        return URL(string: raw)
    }

    private func storeShareURL(_ url: URL) {
        defaults.set(url.absoluteString, forKey: Self.shareStoreKey)
    }

    private func clearStoredShare() {
        defaults.removeObject(forKey: Self.shareStoreKey)
    }

    private func isMissingItem(_ error: any Error) -> Bool {
        guard let code = (error as? CKError)?.code else {
            return false
        }
        return code == .unknownItem || code == .zoneNotFound
    }

    private func errorDescription(_ error: any Error) -> String {
        if let ckError = error as? CKError {
            return String(describing: ckError.code)
        }
        return String(describing: error)
    }

    private func clientError(_ error: Error) -> CloudKitClientError {
        guard let code = (error as? CKError)?.code else {
            return .unknown(String(describing: error))
        }
        switch code {
        case .notAuthenticated:
            return .notAuthenticated
        case .permissionFailure, .managedAccountRestricted:
            return .permissionDenied
        case .quotaExceeded, .requestRateLimited, .limitExceeded:
            return .quotaExceeded
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .badContainer, .missingEntitlement:
            return .containerUnavailable
        case .serverRecordChanged, .constraintViolation, .alreadyShared, .referenceViolation:
            return .conflict
        default:
            return .unknown(String(describing: code))
        }
    }
}
