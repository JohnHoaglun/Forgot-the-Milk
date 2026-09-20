import Foundation
import Testing

@testable import Forgot_the_Milk

@Suite("Mutation queue")
struct MutationQueueTests {
    private var t0: Date { Date(timeIntervalSinceReferenceDate: 1_000) }

    private func categoryRecord(id: UUID, name: String) -> SyncRecord {
        .category(CategoryPayload(
            id: id,
            name: name,
            defaultOrder: 0,
            isSystem: false,
            createdAt: t0,
            updatedAt: t0
        ))
    }

    @Test func replayOrderFollowsFirstEnqueueOrder() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        var queue = MutationQueue()
        queue.enqueue(.upsert(categoryRecord(id: a, name: "A")), at: t0)
        queue.enqueue(.upsert(categoryRecord(id: b, name: "B")), at: t0.addingTimeInterval(1))
        queue.enqueue(.upsert(categoryRecord(id: c, name: "C")), at: t0.addingTimeInterval(2))

        #expect(queue.count == 3)
        #expect(queue.pending.map(\.id) == [a, b, c])
        #expect(queue.pending.map(\.sequence) == [0, 1, 2])
    }

    @Test func upsertsCoalescePerEntityKeepingLatestPayload() {
        let a = UUID()
        var queue = MutationQueue()
        queue.enqueue(.upsert(categoryRecord(id: a, name: "v1")), at: t0)
        queue.enqueue(.upsert(categoryRecord(id: a, name: "v2")), at: t0.addingTimeInterval(1))

        #expect(queue.count == 1)
        let entry = queue.entry(for: a)
        #expect(entry != nil)
        #expect(entry?.sequence == 0)
        guard case .upsert(.category(let payload)) = entry?.mutation else {
            Issue.record("expected upsert(category) entry")
            return
        }
        #expect(payload.name == "v2")
    }

    @Test func deleteAfterUpsertCoalescesToDelete() {
        let a = UUID()
        var queue = MutationQueue()
        queue.enqueue(.upsert(categoryRecord(id: a, name: "A")), at: t0)
        queue.enqueue(.delete(.category, a), at: t0.addingTimeInterval(1))

        #expect(queue.count == 1)
        #expect(queue.entry(for: a)?.mutation == .delete(.category, a))
    }

    @Test func upsertAfterDeleteCoalescesToUpsert() {
        let a = UUID()
        var queue = MutationQueue()
        queue.enqueue(.upsert(categoryRecord(id: a, name: "v1")), at: t0)
        queue.enqueue(.delete(.category, a), at: t0.addingTimeInterval(1))
        queue.enqueue(.upsert(categoryRecord(id: a, name: "v2")), at: t0.addingTimeInterval(2))

        #expect(queue.count == 1)
        guard case .upsert(.category(let payload)) = queue.entry(for: a)?.mutation else {
            Issue.record("expected upsert(category) entry")
            return
        }
        #expect(payload.name == "v2")
    }

    @Test func reenqueuePreservesReplayPosition() {
        let a = UUID()
        let b = UUID()
        var queue = MutationQueue()
        queue.enqueue(.upsert(categoryRecord(id: a, name: "A")), at: t0)
        queue.enqueue(.upsert(categoryRecord(id: b, name: "B")), at: t0.addingTimeInterval(1))
        queue.enqueue(.upsert(categoryRecord(id: a, name: "A2")), at: t0.addingTimeInterval(2))

        #expect(queue.pending.map(\.id) == [a, b])
    }

    @Test func removeClearedEntitiesAfterSuccessfulPush() {
        let a = UUID()
        let b = UUID()
        var queue = MutationQueue()
        queue.enqueue(.upsert(categoryRecord(id: a, name: "A")), at: t0)
        queue.enqueue(.upsert(categoryRecord(id: b, name: "B")), at: t0.addingTimeInterval(1))
        queue.remove([a])

        #expect(queue.count == 1)
        #expect(queue.entry(for: a) == nil)
        #expect(queue.entry(for: b) != nil)
    }

    @Test func removeIgnoresUnknownEntities() {
        let a = UUID()
        var queue = MutationQueue()
        queue.enqueue(.upsert(categoryRecord(id: a, name: "A")), at: t0)
        queue.remove([UUID()])
        #expect(queue.count == 1)
    }

    @Test func reenqueueAfterRemoveGetsFreshSequence() {
        let a = UUID()
        let b = UUID()
        var queue = MutationQueue()
        queue.enqueue(.upsert(categoryRecord(id: a, name: "A")), at: t0)
        queue.remove([a])
        queue.enqueue(.upsert(categoryRecord(id: a, name: "A2")), at: t0.addingTimeInterval(5))
        queue.enqueue(.upsert(categoryRecord(id: b, name: "B")), at: t0.addingTimeInterval(6))

        #expect(queue.pending.map(\.id) == [a, b])
        #expect(queue.pending.map(\.sequence) == [1, 2])
    }

    @Test func entityIDsReportsPendingEntities() {
        let a = UUID()
        let b = UUID()
        var queue = MutationQueue()
        queue.enqueue(.upsert(categoryRecord(id: a, name: "A")), at: t0)
        queue.enqueue(.delete(.category, b), at: t0.addingTimeInterval(1))
        #expect(queue.entityIDs == [a, b])
    }
}

@Suite("Sync baselines")
struct SyncBaselinesTests {
    @Test func setAndGetBaseline() {
        let id = UUID()
        let stamp = Date(timeIntervalSinceReferenceDate: 42)
        var baselines = SyncBaselines()
        baselines.set(id, stamp)
        #expect(baselines[id] == stamp)
        #expect(baselines.count == 1)
    }

    @Test func baselineOverwriteReplacesPrevious() {
        let id = UUID()
        let first = Date(timeIntervalSinceReferenceDate: 42)
        let second = Date(timeIntervalSinceReferenceDate: 43)
        var baselines = SyncBaselines()
        baselines.set(id, first)
        baselines.set(id, second)
        #expect(baselines[id] == second)
        #expect(baselines.count == 1)
    }

    @Test func subscriptAssignmentWorksBothWays() {
        let id = UUID()
        let stamp = Date(timeIntervalSinceReferenceDate: 44)
        var baselines = SyncBaselines()
        baselines[id] = stamp
        #expect(baselines[id] == stamp)
        baselines[id] = nil
        #expect(baselines[id] == nil)
        #expect(baselines.count == 0)
    }

    @Test func removeDeletesBaseline() {
        let id = UUID()
        var baselines = SyncBaselines()
        baselines.set(id, Date(timeIntervalSinceReferenceDate: 45))
        baselines.remove(id)
        #expect(baselines[id] == nil)
        #expect(baselines.count == 0)
    }

    @Test func removeAllClearsAllBaselines() {
        var baselines = SyncBaselines()
        baselines.set(UUID(), Date(timeIntervalSinceReferenceDate: 46))
        baselines.set(UUID(), Date(timeIntervalSinceReferenceDate: 47))
        baselines.removeAll()
        #expect(baselines.count == 0)
        #expect(baselines.all.isEmpty)
    }
}
