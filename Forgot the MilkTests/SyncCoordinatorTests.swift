import Foundation
import SwiftData
import Testing

@testable import Forgot_the_Milk

@Suite("Sync coordinator")
struct SyncCoordinatorTests {
    private func makeContext() throws -> ModelContext {
        TestStore.makePlainContext(try TestStore.makeInMemoryContainer())
    }

    private func scratchDefaults() -> UserDefaults {
        UserDefaults(suiteName: "coordinator-test-\(UUID())")!
    }

    private func waitUntilSettled(_ coordinator: SyncCoordinator) async {
        for _ in 0..<1_000 where coordinator.isReconciling {
            await Task.yield()
        }
    }

    @Test func launchWhileOnlineReconciles() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "device")
        let monitor = FakeConnectivityMonitor()
        monitor.setOnline(true)
        let coordinator = SyncCoordinator(
            context: context,
            client: client,
            connectivity: monitor,
            defaults: scratchDefaults()
        )

        coordinator.start()
        await waitUntilSettled(coordinator)

        #expect(client.fetchCallCount == 1)
        #expect(coordinator.state.status == .idle)
        #expect(coordinator.state.lastSyncedAt != nil)
    }

    @Test func launchWhileOfflineDefersReconcileUntilOnline() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "device")
        let monitor = FakeConnectivityMonitor()
        let coordinator = SyncCoordinator(
            context: context,
            client: client,
            connectivity: monitor,
            defaults: scratchDefaults()
        )

        coordinator.start()
        #expect(coordinator.state.status == .offline)
        #expect(client.fetchCallCount == 0)

        monitor.setOnline(true)
        await waitUntilSettled(coordinator)

        #expect(client.fetchCallCount == 1)
        #expect(coordinator.state.status == .idle)
    }

    @Test func retryAfterErrorReconciles() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "device")
        let monitor = FakeConnectivityMonitor()
        monitor.setOnline(true)
        let coordinator = SyncCoordinator(
            context: context,
            client: client,
            connectivity: monitor,
            defaults: scratchDefaults()
        )

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
        let monitor = FakeConnectivityMonitor()
        monitor.setOnline(true)
        let coordinator = SyncCoordinator(
            context: context,
            client: client,
            connectivity: monitor,
            defaults: scratchDefaults()
        )

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
        let monitor = FakeConnectivityMonitor()
        monitor.setOnline(true)
        let coordinator = SyncCoordinator(
            context: context,
            client: client,
            connectivity: monitor,
            defaults: scratchDefaults()
        )

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
        let monitor = FakeConnectivityMonitor()
        monitor.setOnline(true)
        let coordinator = SyncCoordinator(
            context: context,
            client: client,
            connectivity: monitor,
            defaults: scratchDefaults()
        )

        #expect(coordinator.shareInfo == nil)
        await coordinator.refreshShareInfo()
        #expect(coordinator.shareInfo == nil)

        _ = await client.createShare(defaultParticipantPermission: .readWrite)
        await coordinator.refreshShareInfo()
        #expect(coordinator.shareInfo?.participants.first?.isOwner == true)

        client.server.addParticipant("friend", status: .accepted)
        #expect(coordinator.shareInfo?.participants.count == 2)
    }

    @Test func connectivityDropMarksOffline() async throws {
        let context = try makeContext()
        let client = FakeCloudKitClient(deviceID: "device")
        let monitor = FakeConnectivityMonitor()
        monitor.setOnline(true)
        let coordinator = SyncCoordinator(
            context: context,
            client: client,
            connectivity: monitor,
            defaults: scratchDefaults()
        )

        coordinator.start()
        await waitUntilSettled(coordinator)
        #expect(coordinator.state.status == .idle)

        monitor.setOnline(false)
        #expect(coordinator.state.status == .offline)
        #expect(!coordinator.isReconciling)
    }
}
