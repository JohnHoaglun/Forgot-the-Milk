import Foundation
import SwiftData
import Testing

@testable import Forgot_the_Milk

final class TestShareSheet: ShareSheetPresenting {
    private(set) var presentedItems: [[Any]] = []

    func present(items: [Any]) {
        presentedItems.append(items)
    }
}

@Suite("Sync coordinator")
struct SyncCoordinatorTests {
    private func makeContext() throws -> ModelContext {
        TestStore.makePlainContext(try TestStore.makeInMemoryContainer())
    }

    private func scratchDefaults() -> UserDefaults {
        UserDefaults(suiteName: "coordinator-test-\(UUID())")!
    }

    private func makeCoordinator(
        context: ModelContext,
        client: FakeCloudKitClient,
        online: Bool = true,
        shareSheet: TestShareSheet? = nil,
        defaults: UserDefaults? = nil
    ) -> (coordinator: SyncCoordinator, monitor: FakeConnectivityMonitor, shareSheet: TestShareSheet) {
        let monitor = FakeConnectivityMonitor()
        monitor.setOnline(online)
        let sheet = shareSheet ?? TestShareSheet()
        let coordinator = SyncCoordinator(
            context: context,
            client: client,
            connectivity: monitor,
            shareSheet: sheet,
            defaults: defaults ?? scratchDefaults()
        )
        return (coordinator, monitor, sheet)
    }

    private func waitUntilSettled(_ coordinator: SyncCoordinator) async {
        for _ in 0..<1_000 where coordinator.isReconciling {
            await Task.yield()
        }
    }

    private func waitFor(_ condition: () -> Bool) async {
        for _ in 0..<1_000 where !condition() {
            await Task.yield()
        }
    }

    @Test func launchWhileOnlineReconciles() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "device")
        let (coordinator, _, _) = makeCoordinator(context: context, client: client)

        coordinator.start()
        await waitUntilSettled(coordinator)

        #expect(client.fetchCallCount == 1)
        #expect(coordinator.state.status == .idle)
        #expect(coordinator.state.lastSyncedAt != nil)
    }

    @Test func launchWhileOfflineDefersReconcileUntilOnline() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "device")
        let (coordinator, monitor, _) = makeCoordinator(context: context, client: client, online: false)

        coordinator.start()
        #expect(coordinator.state.status == .offline)
        #expect(client.fetchCallCount == 0)

        monitor.setOnline(true)
        await waitFor { coordinator.state.status == .idle && client.fetchCallCount == 1 }

        #expect(client.fetchCallCount == 1)
        #expect(coordinator.state.status == .idle)
    }

    @Test func retryAfterErrorReconciles() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "device")
        let (coordinator, _, _) = makeCoordinator(context: context, client: client)

        client.fetchFailure = .networkUnavailable
        coordinator.start()
        await waitUntilSettled(coordinator)
        #expect(coordinator.state.status == .error(.network))
        #expect(client.fetchCallCount == 1)

        coordinator.retry()
        await waitUntilSettled(coordinator)

        #expect(coordinator.state.status == .idle)
        #expect(client.fetchCallCount == 2)
    }

    @Test func retryWithoutErrorDoesNothing() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "device")
        let (coordinator, _, _) = makeCoordinator(context: context, client: client)

        coordinator.start()
        await waitUntilSettled(coordinator)
        #expect(coordinator.state.status == .idle)

        coordinator.retry()
        #expect(coordinator.state.status == .idle)
        #expect(client.fetchCallCount == 1)
        #expect(!coordinator.isReconciling)
    }

    @Test func inFlightReconcileIsNotReentered() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "device")
        let (coordinator, _, _) = makeCoordinator(context: context, client: client)

        var stashed: CheckedContinuation<Void, Never>?
        client.fetchSuspender = { stashed = $0 }

        coordinator.start()
        for _ in 0..<1_000 where client.fetchCallCount == 0 {
            await Task.yield()
        }
        #expect(client.fetchCallCount == 1)
        #expect(coordinator.isReconciling)

        coordinator.foreground()
        #expect(client.fetchCallCount == 1)
        #expect(coordinator.isReconciling)

        stashed?.resume(returning: ())
        await waitUntilSettled(coordinator)

        #expect(coordinator.state.status == .idle)
        #expect(client.fetchCallCount == 1)
    }

    @Test func foregroundRefreshesShareInfo() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "device")
        let (coordinator, _, _) = makeCoordinator(context: context, client: client)

        #expect(coordinator.shareInfo == nil)
        await coordinator.refreshShareInfo()
        #expect(coordinator.shareInfo == nil)

        _ = await client.createShare(defaultParticipantPermission: .readWrite)
        await coordinator.refreshShareInfo()
        #expect(coordinator.shareInfo?.isOwner == true)

        client.server.addParticipant("friend", status: .accepted)
        await waitFor { coordinator.shareInfo?.participants.count == 2 }
        #expect(coordinator.shareInfo?.participants.count == 2)
    }

    @Test func connectivityDropMarksOffline() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "device")
        let (coordinator, monitor, _) = makeCoordinator(context: context, client: client)

        coordinator.start()
        await waitUntilSettled(coordinator)
        #expect(coordinator.state.status == .idle)

        monitor.setOnline(false)
        await waitFor { coordinator.state.status == .offline }
        #expect(!coordinator.isReconciling)
    }

    @Test func startSharingCreatesSharePersistsMetadataAndPresentsSheet() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "owner")
        let (coordinator, _, shareSheet) = makeCoordinator(context: context, client: client)
        let (list, _) = TestFixtures.makeList(in: context, title: "Groceries")

        await coordinator.startSharing()

        #expect(coordinator.shareInfo?.isOwner == true)
        #expect(coordinator.activeListID == list.id)
        #expect(shareSheet.presentedItems.count == 1)
        guard let metadataData = list.shareMetadata else {
            Issue.record("share metadata was not persisted")
            return
        }
        let metadata = try #require(try JSONDecoder().decode(ListShare.self, from: metadataData))
        #expect(metadata.isOwner == true)
        #expect(metadata.shareURL == coordinator.shareInfo!.shareURL)
    }

    @Test func stopSharingClearsShareAndMetadataButKeepsLocalList() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "owner")
        let (coordinator, _, _) = makeCoordinator(context: context, client: client)
        let (list, _) = TestFixtures.makeList(in: context, title: "Groceries")

        await coordinator.startSharing()
        #expect(list.shareMetadata != nil)

        await coordinator.stopSharing()

        #expect(coordinator.shareInfo == nil)
        #expect(list.shareMetadata == nil)
        #expect(coordinator.activeListID == list.id)
        #expect(try context.fetchCount(FetchDescriptor<HouseholdList>()) == 1)
        guard case .success(let after) = await client.fetchShareInfo() else {
            Issue.record("expected share info after stop")
            return
        }
        #expect(after == nil)
    }

    @Test func stopSharingIsIgnoredForNonOwner() async throws {
        let context = try makeContext()
        let pair = FakeCloudKitClient.pair()
        let (coordinator, _, _) = makeCoordinator(context: context, client: pair.collaborator)
        _ = TestFixtures.makeList(in: context, title: "Personal")

        _ = await pair.owner.createShare(defaultParticipantPermission: .readWrite)
        await coordinator.refreshShareInfo()
        #expect(coordinator.shareInfo?.isOwner == false)

        await coordinator.stopSharing()

        #expect(coordinator.shareInfo?.isOwner == false)
        guard case .success(let stillShared) = await pair.owner.fetchShareInfo() else {
            Issue.record("expected share info after non-owner stop")
            return
        }
        #expect(stillShared != nil)
    }

    @Test func acceptShareURLAdoptsSharedListAndPreservesPersonalList() async throws {
        let pair = FakeCloudKitClient.pair()
        let ownerContext = try makeContext()
        let (ownerList, _) = TestFixtures.makeList(in: ownerContext, title: "Family Groceries")
        let (ownerCoordinator, _, _) = makeCoordinator(context: ownerContext, client: pair.owner)
        ownerCoordinator.start()
        await waitUntilSettled(ownerCoordinator)
        await ownerCoordinator.startSharing()
        #expect(ownerCoordinator.shareInfo?.isOwner == true)
        guard let shareURL = ownerCoordinator.shareInfo?.shareURL else {
            Issue.record("owner share URL missing")
            return
        }

        let bobContext = try makeContext()
        let (bobList, _) = TestFixtures.makeList(in: bobContext, title: "Bob's Personal")
        let (bobCoordinator, _, bobSheet) = makeCoordinator(context: bobContext, client: pair.collaborator)
        bobCoordinator.start()
        await waitUntilSettled(bobCoordinator)
        #expect(bobCoordinator.shareInfo == nil)

        await bobCoordinator.acceptShareURL(shareURL)
        await waitUntilSettled(bobCoordinator)

        #expect(bobCoordinator.shareInfo?.isOwner == false)
        #expect(bobCoordinator.activeListID == ownerList.id)
        #expect(bobSheet.presentedItems.isEmpty)
        #expect(try bobContext.fetchCount(FetchDescriptor<HouseholdList>()) == 2)
        let ownerListID = ownerList.id
        let adoptedDescriptor = FetchDescriptor<HouseholdList>(predicate: #Predicate { $0.id == ownerListID })
        let adopted = (try bobContext.fetch(adoptedDescriptor)).first
        #expect(adopted?.shareMetadata != nil)
        _ = bobList

        bobCoordinator.foreground()
        await waitUntilSettled(bobCoordinator)
        #expect(bobCoordinator.activeListID == ownerList.id)
    }

    @Test func acceptShareURLWithUnknownURLDoesNotChangeState() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "bob")
        let (coordinator, _, _) = makeCoordinator(context: context, client: client)
        _ = TestFixtures.makeList(in: context, title: "Personal")
        coordinator.start()
        await waitUntilSettled(coordinator)

        await coordinator.acceptShareURL(URL(string: "https://icloud.example/share/does-not-exist")!)

        #expect(coordinator.shareInfo == nil)
        #expect(coordinator.activeListID == nil)
        #expect(client.fetchCallCount == 1)
    }

    @Test func activeListPersistsAcrossCoordinatorRestart() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "owner")
        let defaults = scratchDefaults()
        let (coordinator, _, _) = makeCoordinator(context: context, client: client, defaults: defaults)
        let (list, _) = TestFixtures.makeList(in: context, title: "Groceries")

        await coordinator.startSharing()
        #expect(coordinator.activeListID == list.id)

        let resumed = SyncCoordinator(
            context: context,
            client: client,
            connectivity: FakeConnectivityMonitor(),
            shareSheet: TestShareSheet(),
            defaults: defaults
        )
        #expect(resumed.activeListID == list.id)
    }
}
