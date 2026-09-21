import Foundation
import Testing

@testable import Forgot_the_Milk

@Suite("CloudKit client")
struct CloudKitClientTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
    private let listID = UUID()
    private let categoryID = UUID()
    private let catalogItemID = UUID()
    private let itemID = UUID()
    private let templateID = UUID()

    private func listRecord() -> SyncRecord {
        .householdList(HouseholdListPayload(
            id: listID,
            title: "Groceries",
            categoryOrder: [categoryID],
            createdAt: t0,
            updatedAt: t0
        ))
    }

    private func categoryRecord() -> SyncRecord {
        .category(CategoryPayload(
            id: categoryID,
            name: "Produce",
            defaultOrder: 0,
            isSystem: false,
            createdAt: t0,
            updatedAt: t0
        ))
    }

    private func catalogRecord() -> SyncRecord {
        .catalogItem(CatalogItemPayload(
            id: catalogItemID,
            name: "Milk",
            categoryID: categoryID,
            defaultQuantity: "1",
            defaultUnit: "carton",
            defaultNote: nil,
            scope: .household,
            createdAt: t0,
            updatedAt: t0
        ))
    }

    private func itemRecord(name: String = "Milk", state: ListItemState = .needed) -> SyncRecord {
        .listItem(ListItemPayload(
            id: itemID,
            listID: listID,
            catalogItemID: catalogItemID,
            name: name,
            categoryID: categoryID,
            quantity: "1",
            unit: "carton",
            note: nil,
            state: state,
            sortOrder: 0,
            createdAt: t0,
            updatedAt: t0
        ))
    }

    private func templateRecord() -> SyncRecord {
        .template(TemplatePayload(
            id: templateID,
            listID: listID,
            name: "Weekly",
            entries: [TemplateEntry(
                catalogItemID: catalogItemID,
                name: "Milk",
                categoryID: categoryID,
                quantity: "1",
                unit: "carton",
                note: nil
            )],
            createdAt: t0,
            updatedAt: t0
        ))
    }

    private func expectSuccess<T>(_ result: Result<T, CloudKitClientError>) -> T? {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            Issue.record("expected success, got \(error)")
            return nil
        }
    }

    private func expectFailure<T>(_ result: Result<T, CloudKitClientError>, _ expected: CloudKitClientError) -> Bool {
        if case .failure(let error) = result, error == expected {
            return true
        }
        Issue.record("expected failure \(expected), got \(String(describing: result))")
        return false
    }

    @Test func fetchOnFreshServerReturnsEmptyPullResult() async {
        let client = FakeCloudKitClient(deviceID: "owner")
        guard let pull = expectSuccess(await client.fetchSyncRecords()) else { return }
        #expect(pull.records.isEmpty)
        #expect(pull.deletions.isEmpty)
    }

    @Test func saveStampsServerTimeAndRoundTripsEveryEntityType() async {
        let client = FakeCloudKitClient(deviceID: "owner")
        let all = [listRecord(), categoryRecord(), catalogRecord(), itemRecord(), templateRecord()]

        guard let saved = expectSuccess(await client.saveRecords(all)) else { return }
        #expect(saved.outcomes.count == 5)
        #expect(saved.rejectedIDs.isEmpty)
        #expect(saved.outcomes.allSatisfy { $0.accepted && $0.serverModifiedAt == client.server.serverNow })

        guard let pull = expectSuccess(await client.fetchSyncRecords()) else { return }
        #expect(Set(pull.records.map(\.record)) == Set(all))
        #expect(pull.records.map(\.record.type) == [.catalogItem, .category, .householdList, .listItem, .template])
        #expect(pull.records.allSatisfy { $0.serverModifiedAt == client.server.serverNow && !$0.shared })

        client.server.serverNow = client.server.serverNow.addingTimeInterval(60)
        let updated = itemRecord(name: "Oat Milk")
        guard let resaved = expectSuccess(await client.saveRecords([updated])) else { return }
        #expect(resaved.outcomes.first?.serverModifiedAt == client.server.serverNow)

        guard let repulled = expectSuccess(await client.fetchSyncRecords()) else { return }
        #expect(repulled.records.contains { $0.record == updated })
    }

    @Test func partialSaveFailureReportsRejectedEntityIDs() async {
        let client = FakeCloudKitClient(deviceID: "owner")
        client.saveRejections = [itemID]

        guard let saved = expectSuccess(await client.saveRecords([listRecord(), itemRecord()])) else { return }
        #expect(saved.acceptedIDs == [listID])
        #expect(saved.rejectedIDs == [itemID])
        #expect(saved.outcomes.first { $0.entityID == itemID }?.accepted == false)
        #expect(saved.outcomes.first { $0.entityID == itemID }?.serverModifiedAt == nil)

        guard let pull = expectSuccess(await client.fetchSyncRecords()) else { return }
        #expect(pull.records.contains { $0.record.id == listID })
        #expect(!pull.records.contains { $0.record.id == itemID })

        guard let resaved = expectSuccess(await client.saveRecords([itemRecord()])) else { return }
        #expect(resaved.rejectedIDs.isEmpty)
        #expect(resaved.acceptedIDs == [itemID])
    }

    @Test func deletePublishesTombstoneVisibleToOtherDevice() async {
        let pair = FakeCloudKitClient.pair()

        guard let saved = expectSuccess(await pair.owner.saveRecords([itemRecord()])) else { return }
        #expect(saved.acceptedIDs == [itemID])

        guard let deleted = expectSuccess(await pair.owner.deleteRecords([SyncDeleteRequest(entityType: .listItem, entityID: itemID)])) else { return }
        #expect(deleted == [itemID])

        guard let ownerPull = expectSuccess(await pair.owner.fetchSyncRecords()) else { return }
        #expect(ownerPull.records.isEmpty)
        #expect(ownerPull.deletions == [
            SyncDeletion(entityType: .listItem, entityID: itemID, serverModifiedAt: pair.owner.server.serverNow)
        ])

        guard let otherPull = expectSuccess(await pair.collaborator.fetchSyncRecords()) else { return }
        #expect(otherPull.records.isEmpty)
        #expect(otherPull.deletions.count == 1)
        #expect(otherPull.deletions.first?.entityType == .listItem)
        #expect(otherPull.deletions.first?.entityID == itemID)
    }

    @Test func recordsAreMarkedSharedForTheOtherDeviceOnly() async {
        let pair = FakeCloudKitClient.pair()

        guard let saved = expectSuccess(await pair.owner.saveRecords([itemRecord()])) else { return }
        #expect(saved.acceptedIDs == [itemID])

        guard let ownerPull = expectSuccess(await pair.owner.fetchSyncRecords()) else { return }
        #expect(ownerPull.records.allSatisfy { !$0.shared })

        guard let otherPull = expectSuccess(await pair.collaborator.fetchSyncRecords()) else { return }
        #expect(otherPull.records.allSatisfy { $0.shared })

        guard let resaved = expectSuccess(await pair.collaborator.saveRecords([itemRecord(state: .completed)])) else { return }
        #expect(resaved.acceptedIDs == [itemID])

        guard let repulled = expectSuccess(await pair.owner.fetchSyncRecords()) else { return }
        #expect(repulled.records.first?.shared == true)
    }

    @Test func laterServerWriteWinsOnBothDevices() async {
        let pair = FakeCloudKitClient.pair()

        _ = await pair.owner.saveRecords([itemRecord(name: "first")])
        pair.owner.server.serverNow = pair.owner.server.serverNow.addingTimeInterval(30)
        _ = await pair.collaborator.saveRecords([itemRecord(name: "second")])

        guard let ownerPull = expectSuccess(await pair.owner.fetchSyncRecords()) else { return }
        guard case .listItem(let ownerPayload) = ownerPull.records.first?.record else {
            Issue.record("expected listItem record on owner")
            return
        }
        #expect(ownerPayload.name == "second")
        #expect(ownerPull.records.first?.serverModifiedAt == pair.owner.server.serverNow)

        guard let otherPull = expectSuccess(await pair.collaborator.fetchSyncRecords()) else { return }
        guard case .listItem(let otherPayload) = otherPull.records.first?.record else {
            Issue.record("expected listItem record on collaborator")
            return
        }
        #expect(otherPayload.name == "second")
    }

    @Test func unauthorizedClientFailsEveryOperationWithoutConsumingInjections() async {
        let client = FakeCloudKitClient(deviceID: "owner")
        client.authentication = .restricted
        client.fetchFailure = .networkUnavailable

        #expect(await client.authenticationStatus() == .restricted)
        #expect(expectFailure(await client.fetchSyncRecords(), .notAuthenticated))
        #expect(expectFailure(await client.saveRecords([itemRecord()]), .notAuthenticated))
        #expect(expectFailure(await client.deleteRecords([SyncDeleteRequest(entityType: .listItem, entityID: itemID)]), .notAuthenticated))
        #expect(expectFailure(await client.createShare(defaultParticipantPermission: .readWrite), .notAuthenticated))
        #expect(expectFailure(await client.fetchShareInfo(), .notAuthenticated))
        #expect(expectFailure(await client.deleteShare(), .notAuthenticated))

        client.authentication = .authorized
        #expect(expectFailure(await client.fetchSyncRecords(), .networkUnavailable))
    }

    @Test func injectedFetchAndShareFailuresAreConsumedOnce() async {
        let client = FakeCloudKitClient(deviceID: "owner")
        client.fetchFailure = .networkUnavailable
        client.shareFailure = .quotaExceeded

        #expect(expectFailure(await client.fetchSyncRecords(), .networkUnavailable))
        guard let pull = expectSuccess(await client.fetchSyncRecords()) else { return }
        #expect(pull.records.isEmpty)

        #expect(expectFailure(await client.createShare(defaultParticipantPermission: .readWrite), .quotaExceeded))
        guard let info = expectSuccess(await client.createShare(defaultParticipantPermission: .readOnly)) else { return }
        #expect(info.participants.count == 1)
    }

    @Test func createShareRecordsOwnerAndSurvivesSecondCall() async {
        let client = FakeCloudKitClient(deviceID: "owner")

        guard let first = expectSuccess(await client.createShare(defaultParticipantPermission: .readOnly)) else { return }
        #expect(first.participants == [
            ShareParticipant(name: "owner", isOwner: true, permission: .readWrite, status: .accepted)
        ])

        guard let second = expectSuccess(await client.createShare(defaultParticipantPermission: .readWrite)) else { return }
        #expect(second == first)
        #expect(second.shareURL.absoluteString.hasPrefix("https://icloud.example/share/"))
    }

    @Test func invitedParticipantsUseShareDefaultPermission() async {
        let pair = FakeCloudKitClient.pair()

        guard let created = expectSuccess(await pair.owner.createShare(defaultParticipantPermission: .readOnly)) else { return }
        pair.owner.server.addParticipant("Ada", status: .invited)
        pair.owner.server.addParticipant("Ben", status: .accepted)

        guard let maybeInfo = expectSuccess(await pair.owner.fetchShareInfo()), let repulled = maybeInfo else { return }
        #expect(repulled.participants == [
            ShareParticipant(name: "owner", isOwner: true, permission: .readWrite, status: .accepted),
            ShareParticipant(name: "Ada", isOwner: false, permission: .readOnly, status: .invited),
            ShareParticipant(name: "Ben", isOwner: false, permission: .readOnly, status: .accepted)
        ])

        guard let otherPull = expectSuccess(await pair.collaborator.fetchShareInfo()) else { return }
        #expect(otherPull == repulled)
    }

    @Test func fetchShareInfoWithoutShareReturnsNil() async {
        let client = FakeCloudKitClient(deviceID: "owner")
        guard let info = expectSuccess(await client.fetchShareInfo()) else { return }
        #expect(info == nil)
    }

    @Test func deleteShareClearsShareWithoutNotifyingHandlers() async {
        let pair = FakeCloudKitClient.pair()
        var changes: [ShareInfo] = []
        pair.owner.onShareChange = { changes.append($0) }
        pair.collaborator.onShareChange = { changes.append($0) }

        guard let created = expectSuccess(await pair.owner.createShare(defaultParticipantPermission: .readWrite)) else { return }
        #expect(created.participants.count == 1)

        pair.owner.server.addParticipant("Ada", status: .accepted)
        #expect(changes.count == 2)
        #expect(changes.allSatisfy { $0.participants.count == 2 })

        guard expectSuccess(await pair.owner.deleteShare()) != nil else { return }
        #expect(changes.count == 2)

        guard let cleared = expectSuccess(await pair.owner.fetchShareInfo()) else { return }
        #expect(cleared == nil)
        guard let alsoCleared = expectSuccess(await pair.collaborator.fetchShareInfo()) else { return }
        #expect(alsoCleared == nil)
    }

    @Test func addParticipantBroadcastsToBothDevices() async {
        let pair = FakeCloudKitClient.pair()
        var ownerChanges: [ShareInfo] = []
        var collaboratorChanges: [ShareInfo] = []
        pair.owner.onShareChange = { ownerChanges.append($0) }
        pair.collaborator.onShareChange = { collaboratorChanges.append($0) }

        guard let created = expectSuccess(await pair.owner.createShare(defaultParticipantPermission: .readOnly)) else { return }
        #expect(ownerChanges.isEmpty)
        #expect(collaboratorChanges.isEmpty)

        pair.owner.server.addParticipant("Ada", status: .invited)

        #expect(ownerChanges.count == 1)
        #expect(collaboratorChanges.count == 1)
        let updated = ownerChanges.first
        #expect(updated == collaboratorChanges.first)
        #expect(updated?.participants == [
            ShareParticipant(name: "owner", isOwner: true, permission: .readWrite, status: .accepted),
            ShareParticipant(name: "Ada", isOwner: false, permission: .readOnly, status: .invited)
        ])
        #expect(created.participants.count == 1)
    }
}
