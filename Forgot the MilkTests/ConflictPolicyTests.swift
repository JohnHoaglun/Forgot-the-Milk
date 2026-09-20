import Foundation
import Testing

@testable import Forgot_the_Milk

@Suite("Conflict policy")
struct ConflictPolicyTests {
    private let policy = ConflictPolicy()
    private let t0 = Date(timeIntervalSinceReferenceDate: 100)

    private func listItem(updatedAt: Date = Date(timeIntervalSinceReferenceDate: 100)) -> SyncRecord {
        .listItem(ListItemPayload(
            id: UUID(),
            listID: UUID(),
            catalogItemID: nil,
            name: "Milk",
            categoryID: UUID(),
            quantity: nil,
            unit: nil,
            note: nil,
            state: .needed,
            sortOrder: 0,
            createdAt: t0,
            updatedAt: updatedAt
        ))
    }

    @Test func nothingLocallyAndNothingRemotelyIsNoChange() {
        let result = policy.resolve(local: nil, localIsDirty: false, baseline: nil, remote: nil)
        #expect(result.outcome == .noChange)
        #expect(result.rejectedLocal == false)
        #expect(result.newBaseline == nil)
    }

    @Test func newDirtyLocalRecordIsPushed() {
        let result = policy.resolve(local: listItem(), localIsDirty: true, baseline: nil, remote: nil)
        #expect(result.outcome == .pushLocal)
        #expect(result.rejectedLocal == false)
    }

    @Test func neverSyncedCleanLocalRecordIsPushedOnFirstSync() {
        let result = policy.resolve(local: listItem(), localIsDirty: false, baseline: nil, remote: nil)
        #expect(result.outcome == .pushLocal)
        #expect(result.rejectedLocal == false)
    }

    @Test func remoteDeletionWinsWhenLocalIsClean() {
        let baseline = Date(timeIntervalSinceReferenceDate: 10)
        let result = policy.resolve(local: listItem(), localIsDirty: false, baseline: baseline, remote: nil)
        #expect(result.outcome == .adoptRemote)
        #expect(result.rejectedLocal == false)
        #expect(result.newBaseline == nil)
    }

    @Test func unsyncedLocalEditBeatsUnobservableRemoteDeletion() {
        let baseline = Date(timeIntervalSinceReferenceDate: 10)
        let result = policy.resolve(local: listItem(), localIsDirty: true, baseline: baseline, remote: nil)
        #expect(result.outcome == .pushLocal)
        #expect(result.rejectedLocal == false)
    }

    @Test func remoteRecordWithNoLocalCopyIsAdopted() {
        let baseline = Date(timeIntervalSinceReferenceDate: 50)
        let remote = RemoteRecord(record: listItem(), serverModifiedAt: baseline)
        let result = policy.resolve(local: nil, localIsDirty: false, baseline: nil, remote: remote)
        #expect(result.outcome == .adoptRemote)
        #expect(result.rejectedLocal == false)
        #expect(result.newBaseline == baseline)
    }

    @Test func unchangedRemoteRecordIsSkipped() {
        let baseline = Date(timeIntervalSinceReferenceDate: 50)
        let remote = RemoteRecord(record: listItem(), serverModifiedAt: baseline)
        let result = policy.resolve(local: listItem(), localIsDirty: false, baseline: baseline, remote: remote)
        #expect(result.outcome == .noChange)
        #expect(result.rejectedLocal == false)
        #expect(result.newBaseline == nil)
    }

    @Test func remoteChangeIsAdoptedWhenLocalIsClean() {
        let baseline = Date(timeIntervalSinceReferenceDate: 50)
        let remote = RemoteRecord(record: listItem(), serverModifiedAt: baseline.addingTimeInterval(60))
        let result = policy.resolve(local: listItem(), localIsDirty: false, baseline: baseline, remote: remote)
        #expect(result.outcome == .adoptRemote)
        #expect(result.rejectedLocal == false)
        #expect(result.newBaseline == remote.serverModifiedAt)
    }

    @Test func unsyncedLocalEditWinsWhenServerUnchangedSinceBaseline() {
        let baseline = Date(timeIntervalSinceReferenceDate: 50)
        let remote = RemoteRecord(record: listItem(), serverModifiedAt: baseline)
        let result = policy.resolve(
            local: listItem(updatedAt: baseline.addingTimeInterval(30)),
            localIsDirty: true,
            baseline: baseline,
            remote: remote
        )
        #expect(result.outcome == .pushLocal)
        #expect(result.rejectedLocal == false)
    }

    @Test func remoteWinsLastWriterWinsAndLocalEditIsRejected() {
        let baseline = Date(timeIntervalSinceReferenceDate: 50)
        let remote = RemoteRecord(record: listItem(), serverModifiedAt: baseline.addingTimeInterval(120))
        let result = policy.resolve(local: listItem(), localIsDirty: true, baseline: baseline, remote: remote)
        #expect(result.outcome == .adoptRemote)
        #expect(result.rejectedLocal == true)
        #expect(result.newBaseline == remote.serverModifiedAt)
    }

    @Test func dirtyLocalWithNoBaselineLosesToRemote() {
        let remote = RemoteRecord(record: listItem(), serverModifiedAt: Date(timeIntervalSinceReferenceDate: 99))
        let result = policy.resolve(local: listItem(), localIsDirty: true, baseline: nil, remote: remote)
        #expect(result.outcome == .adoptRemote)
        #expect(result.rejectedLocal == true)
        #expect(result.newBaseline == remote.serverModifiedAt)
    }

    @Test func twoOfflineEditsResolveDeterministically() {
        // Spec: two devices offline, both edit the same item. B's edit reaches
        // the server first, so B's serverModifiedAt exceeds A's baseline and A's
        // edit is rejected (surfaced, never silently dropped).
        let baseline = Date(timeIntervalSinceReferenceDate: 50)
        let remote = RemoteRecord(record: listItem(), serverModifiedAt: baseline.addingTimeInterval(90))
        let result = policy.resolve(local: listItem(), localIsDirty: true, baseline: baseline, remote: remote)
        #expect(result.outcome == .adoptRemote)
        #expect(result.rejectedLocal == true)
        #expect(result.newBaseline == remote.serverModifiedAt)
    }
}
