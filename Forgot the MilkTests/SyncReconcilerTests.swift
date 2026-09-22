import Foundation
import SwiftData
import Testing

@testable import Forgot_the_Milk

@Suite("Sync reconciler")
struct SyncReconcilerTests {
    private func makeContext() throws -> ModelContext {
        TestStore.makePlainContext(try TestStore.makeInMemoryContainer())
    }

    private func scratchDefaults() -> UserDefaults {
        UserDefaults(suiteName: "reconciler-test-\(UUID())")!
    }

    private func listItems(_ context: ModelContext) throws -> [ListItem] {
        try context.fetch(FetchDescriptor<ListItem>())
    }

    @Test func localDeletionPropagatesToOtherDevice() async throws {
        let contextA = try makeContext()
        let contextB = try makeContext()
        let (owner, collaborator) = FakeCloudKitClient.pair()
        let fixture = TestFixtures.makeList(in: contextA)
        let item = TestFixtures.makeItem(
            in: contextA,
            list: fixture.list,
            category: fixture.categories[0],
            name: "Milk",
            sortOrder: 0
        )

        let reconcilerA = SyncReconciler(context: contextA, client: owner, defaults: scratchDefaults())
        let reconcilerB = SyncReconciler(context: contextB, client: collaborator, defaults: scratchDefaults())

        _ = await reconcilerA.reconcile()
        _ = await reconcilerB.reconcile()
        #expect(try listItems(contextB).count == 1)

        contextA.delete(item)
        try contextA.save()
        let report = await reconcilerA.reconcile()
        #expect(report.failure == nil)
        #expect(report.remainingPendingCount == 0)
        #expect(owner.server.snapshot(for: "owner").deletions.map(\.entityID).contains(item.id))

        _ = await reconcilerB.reconcile()
        #expect(try listItems(contextB).isEmpty)
    }

    @Test func remoteEditWinsOverLocalDeletion() async throws {
        let contextA = try makeContext()
        let contextB = try makeContext()
        let (owner, collaborator) = FakeCloudKitClient.pair()
        let fixtureA = TestFixtures.makeList(in: contextA)
        let itemA = TestFixtures.makeItem(
            in: contextA,
            list: fixtureA.list,
            category: fixtureA.categories[0],
            name: "Milk",
            sortOrder: 0
        )

        let reconcilerA = SyncReconciler(context: contextA, client: owner, defaults: scratchDefaults())
        let reconcilerB = SyncReconciler(context: contextB, client: collaborator, defaults: scratchDefaults())

        _ = await reconcilerA.reconcile()
        _ = await reconcilerB.reconcile()
        #expect(try listItems(contextB).count == 1)

        owner.server.serverNow = owner.server.serverNow.addingTimeInterval(60)
        let itemB = try #require(try listItems(contextB).first)
        itemB.name = "Oat Milk"
        itemB.updatedAt = itemB.updatedAt.addingTimeInterval(1)
        try contextB.save()
        _ = await reconcilerB.reconcile()

        contextA.delete(itemA)
        try contextA.save()
        let report = await reconcilerA.reconcile()

        #expect(report.failure == nil)
        let revived = try #require(try listItems(contextA).first)
        #expect(revived.name == "Oat Milk")
    }

    @Test func rejectedDeletionStaysPendingAndReplays() async throws {
        let contextA = try makeContext()
        let contextB = try makeContext()
        let (owner, collaborator) = FakeCloudKitClient.pair()
        let fixture = TestFixtures.makeList(in: contextA)
        let item = TestFixtures.makeItem(
            in: contextA,
            list: fixture.list,
            category: fixture.categories[0],
            name: "Milk",
            sortOrder: 0
        )

        let reconcilerA = SyncReconciler(context: contextA, client: owner, defaults: scratchDefaults())
        let reconcilerB = SyncReconciler(context: contextB, client: collaborator, defaults: scratchDefaults())

        _ = await reconcilerA.reconcile()
        _ = await reconcilerB.reconcile()

        contextA.delete(item)
        try contextA.save()
        owner.deleteRejections = [item.id]
        let first = await reconcilerA.reconcile()
        #expect(first.failure == nil)
        #expect(first.remainingPendingCount == 1)
        #expect(!owner.server.snapshot(for: "owner").deletions.map(\.entityID).contains(item.id))

        owner.deleteRejections = []
        let second = await reconcilerA.reconcile()
        #expect(second.remainingPendingCount == 0)
        #expect(owner.server.snapshot(for: "owner").deletions.map(\.entityID).contains(item.id))

        _ = await reconcilerB.reconcile()
        #expect(try listItems(contextB).isEmpty)
    }

    @Test func pendingDeletionSurvivesRestartAndReplays() async throws {
        let contextA = try makeContext()
        let contextB = try makeContext()
        let (owner, collaborator) = FakeCloudKitClient.pair()
        let fixture = TestFixtures.makeList(in: contextA)
        let item = TestFixtures.makeItem(
            in: contextA,
            list: fixture.list,
            category: fixture.categories[0],
            name: "Milk",
            sortOrder: 0
        )

        let defaults = scratchDefaults()
        let reconcilerA = SyncReconciler(context: contextA, client: owner, defaults: defaults)
        let reconcilerB = SyncReconciler(context: contextB, client: collaborator, defaults: scratchDefaults())

        _ = await reconcilerA.reconcile()
        _ = await reconcilerB.reconcile()

        contextA.delete(item)
        try contextA.save()
        owner.deleteFailure = .networkUnavailable
        let queued = await reconcilerA.reconcile()
        #expect(queued.failure == .network)
        #expect(queued.remainingPendingCount == 1)
        #expect(!owner.server.snapshot(for: "owner").deletions.map(\.entityID).contains(item.id))

        owner.deleteFailure = nil
        let restarted = SyncReconciler(context: contextA, client: owner, defaults: defaults)
        let replayed = await restarted.reconcile()
        #expect(replayed.failure == nil)
        #expect(replayed.remainingPendingCount == 0)
        #expect(owner.server.snapshot(for: "owner").deletions.map(\.entityID).contains(item.id))

        _ = await reconcilerB.reconcile()
        #expect(try listItems(contextB).isEmpty)
    }

    @Test func reconcileWithoutIcAccountReportsAuthenticationFailure() async throws {
        let contextA = try makeContext()
        let fixture = TestFixtures.makeList(in: contextA)
        let (owner, _) = FakeCloudKitClient.pair()
        owner.authentication = .unavailable

        let report = await SyncReconciler(context: contextA, client: owner, defaults: scratchDefaults()).reconcile()
        #expect(report.failure == .authentication)
        #expect(report.remainingPendingCount == 0)
        #expect(owner.server.snapshot(for: "owner").records.isEmpty)
        _ = fixture
    }

    @Test func schemaVersionBumpRepushesRecordsMissingFromServer() async throws {
        let context = try makeContext()
        let (owner, _) = FakeCloudKitClient.pair()
        let fixture = TestFixtures.makeList(in: context)
        let defaults = scratchDefaults()

        // Mimic a device that already synced: the journal claims the local state
        // is up to date, so an empty server pull would push nothing.
        var journal = SyncJournal()
        let localRecords = [SyncRecord(householdList: fixture.list)]
            + fixture.categories.map { SyncRecord(category: $0) }
        for record in localRecords {
            journal.baselines[record.id] = Date(timeIntervalSinceReferenceDate: 1_000_000)
            journal.localVersions[record.id] = record.updatedAt
        }
        journal.persist(to: defaults)

        // The server no longer serves those records (as when its schema predates
        // a new field), and the device records an older schema version. The next
        // reconcile must reset the journal and re-push every local record.
        defaults.set(0, forKey: SyncSchema.versionKey)
        let report = await SyncReconciler(context: context, client: owner, defaults: defaults).reconcile()
        #expect(report.failure == nil)
        #expect(report.pushedCount == fixture.categories.count + 1)
        #expect(owner.server.snapshot(for: "owner").records.contains { $0.record.id == fixture.list.id })
        #expect(defaults.integer(forKey: SyncSchema.versionKey) == SyncSchema.version)
    }

    @Test func schemaVersionBumpJournalResetSurvivesPullFailure() async throws {
        let context = try makeContext()
        let (owner, _) = FakeCloudKitClient.pair()
        let fixture = TestFixtures.makeList(in: context)

        let defaults = scratchDefaults()
        let first = await SyncReconciler(context: context, client: owner, defaults: defaults).reconcile()
        #expect(first.failure == nil)
        #expect(!SyncJournal.load(from: defaults).baselines.isEmpty)

        // A schema version bump must durably reset the journal before the pull:
        // if the reconcile aborts on a pull failure, the reset must not be lost.
        defaults.set(0, forKey: SyncSchema.versionKey)
        owner.fetchFailure = .networkUnavailable
        let second = await SyncReconciler(context: context, client: owner, defaults: defaults).reconcile()
        #expect(second.failure == .network)
        #expect(SyncJournal.load(from: defaults).baselines.isEmpty)
        #expect(defaults.integer(forKey: SyncSchema.versionKey) == SyncSchema.version)
        _ = fixture
    }
}
