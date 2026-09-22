# Delivery Plan

## Active milestone

D4 — CloudKit collaboration and recovery. D1 (foundation and catalog), D2 (item workflow), and D3 (templates and email export) were delivered and verified by `scripts/verify.sh`.

### D4 work breakdown

Existing seams: local mutations are owned by `ItemUseCases`/`ItemEntryUseCases`/`TemplateUseCases` over the SwiftData store; `TestStore` is a resettable in-memory SwiftData store; DEBUG deterministic fakes exist for mail and share-sheet presentation; the spec requires views to never call CloudKit directly.

1. Entitlements (done 2026-09-19): `Forgot the Milk.entitlements` declares the spec-mandated container `iCloud.com.hoaglun.forgotthemilk` plus `com.apple.developer.icloud-services` = `CloudKit` (per Apple's entitlements documentation and Xcode's CloudKit capability template); `CODE_SIGN_ENTITLEMENTS` wired into the app target's Debug and Release.
2. CloudKit sync domain (done 2026-09-20, pure, unit-tested): record mapping for every persisted model (stable UUIDs for local identity; `CKRecordID`s and share metadata persisted separately; `createdAt`/`updatedAt` plus a monotonic ordering field on user-editable records); a sync-state reducer (idle, reconciling, and recoverable error with plain-language message plus Retry); conflict policy = whole-record last-writer-wins by CloudKit server modification timestamp; a local unsynced mutation that CloudKit rejects or cannot reconcile is never silently discarded (queued and surfaced with Retry). Delivered as `SyncRecord`/`SyncRecordMapping`, `SyncState`, `ConflictPolicy`, `MutationQueue`/`SyncBaselines` with four test files. The launch crash from the iOS 27 SDK `cloudKitDatabase: .automatic` default (fatal under the CloudKit entitlement) was fixed in the same delivery with explicit `cloudKitDatabase: .none`.
3. CloudKit client seam (`CloudKitClient` protocol wrapping `CKContainer`/`CKDatabase`/`CKShare`) with deterministic fakes: controllable server clock and modification timestamps, injectable auth/permission/quota/network/partial-failure errors, and a two-device fake pair for contract tests. (Done 2026-09-20 as a `CKContainer`-free seam: `fetch`/`save`/`delete`, share lifecycle, auth status, typed `CloudKitClientError`, with DEBUG `FakeCloudKitClient`/`FakeCloudKitServer` — server clock, per-device attribution, one-shot failures, two-device `pair()`; 13 contract tests. The real `CKContainer`-backed adapter ships with the reconciler.)
4. Connectivity monitor seam with a deterministic fake (online/offline transitions, main-actor delivery, no external dependencies). (Done 2026-09-20: `ConnectivityMonitoring` protocol, `SystemConnectivityMonitor` on `NWPathMonitor` with a main-actor hop, DEBUG `FakeConnectivityMonitor` with change-only notifications; 4 tests.)
5. Reconciler: load local immediately on launch/foreground, then reconcile CloudKit in the background; offline mutation queue replayed in order when connectivity returns; incoming remote changes merged per the conflict policy; share-change observation while active and refresh on foreground return.
6. Sharing use cases: `Share List` creates or reuses a `CKShare` (default `readWrite`; no read-only choice in v1) and presents the system share sheet; collaborators and permission levels displayed from share metadata; `Stop Sharing` (owner only) leaves the owner's local list intact and explains that collaborators lose access; accepting a `CKShare` invitation after a fresh install is supported by preserving and handling `CKShare.Metadata` through launch/activation.
7. Settings UI: iCloud/account status, collaborators, `Share List`, `Stop Sharing` (owner only); when iCloud is unavailable, plain-language state with local editing still enabled and sharing controls disabled with a recovery instruction; non-blocking sync status plus Retry; existing unit-system and About/privacy entries unchanged. Accessibility: large targets, Dynamic Type, and VoiceOver labels for every new surface.
8. Tests: unit (sync-state reducer, retry behavior, conflict policy, queue ordering); repository/integration (offline mutations queued and replayed in order; incoming remote changes merge per the conflict policy, through the fake client); CloudKit contract (share creation/acceptance, permission display, partial failures, conflict, stop-share); UI (share flow via fakes, status/Retry surfaces, Dynamic Type and VoiceOver passes). Maintain a separately gated manual two-Apple-ID smoke checklist.
9. Docs (CHANGELOG, ARCHITECTURE, DECISIONS), build number bump, `scripts/verify.sh` green, atomic commit, push.

Status (2026-09-22): steps 1–8 delivered (entitlements; sync domain; `CloudKitClient` seam with deterministic fakes; connectivity seam with deterministic fake; real `CKContainer` adapter + reconciler + coordinator with app wiring; sharing use cases — `startSharing`/`stopSharing`/`acceptShareURL` with `ListShare` metadata persistence and active-list resolution; settings UI with unavailable-state recovery instruction; unit, contract, and fake-driven UI coverage, including the share round trip and accessibility-size pass). Build number 10. Signed-device entitlement verification is complete (container and `CloudKit` service confirmed in a signed iPhone build) and real-device sync is verified end-to-end after fixing two real-server query behaviors: fresh zones report never-saved record types as missing (tolerated per type as empty), and the server rejects queries without a constant field comparison (replaced by a queryable `updatedAt` on every record plus the `updatedAt > <reference epoch>` predicate, with a one-time schema-version-gated journal reset so pre-`updatedAt` server schemas self-repair via re-push). Remaining: the manual two-Apple-ID smoke checklist and the final end-to-end `scripts/verify.sh` run to close the slice.

Spec anchors: §4.4 (sharing and settings), §5 (technical behavior: local persistence as source of truth, background reconcile on launch/foreground, recoverable error states with Retry, OSLog without notes/identities/share URLs), §6 D4 acceptance criteria, §7 (sync-state reducer and retry unit tests; offline queue replay and conflict merge integration coverage; CloudKit contract fake-client tests; manual two-Apple-ID checklist), §8 (container/bundle decision, `readWrite` default, no read-only choice, fresh-install share acceptance).

## Delivery sequence

1. D1 (delivered): app shell, local model, deterministic catalog, persisted list behavior.
2. D2 (delivered): catalog picker, custom items, metadata, category order, accessibility.
3. D3 (delivered): reusable templates and plain-text email/share-sheet export.
4. D4 (active): CloudKit sharing, invitations, offline reconciliation, and recovery states.

## Blockers

No implementation blocker is currently recorded. The CloudKit entitlements are committed (step 1) and the container `iCloud.com.hoaglun.forgotthemilk` is verified provisioned in a signed device build (2026-09-22); real-device sync works end-to-end. Before real D4 validation is claimed, the manual two-Apple-ID sharing smoke must be executed (spec release gate).

## Verification gate

Every delivery leaves `main` runnable and passes its assigned automated tests. D4 also requires manual two-Apple-ID sharing, offline/reconnect, Dynamic Type, and VoiceOver checks.
