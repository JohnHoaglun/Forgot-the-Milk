# To Do

## Now

- [x] Establish the D1 Xcode project, targets, and canonical `scripts/verify.sh` command.
- [x] Implement and test the D1 local data model and deterministic catalog.
- [x] Implement and test persisted list behavior.
- [x] D2: domain entry logic — validation, normalization, add/reopen, save-to-catalog, reorder, unit-system seam (with unit tests).
- [x] D2: catalog picker and item form (add/edit) with validation and metadata.
- [x] D2: category reorder (Edit mode) with persisted order.
- [x] D2: `Forgot the MilkUITests` target, UI tests, accessibility/Dynamic Type pass, and `verify.sh` UI step.
- [x] D3: template domain — name validation, save snapshot (needed items only), apply via add/reopen with changed-count report, rename, delete (with unit tests).
- [x] D3: list export text (needed-only, category-grouped, metadata when present) with unit tests.
- [x] D3: `MailComposer`/`ShareSheetPresenter` adapters with deterministic fakes and `EmailExportService`.
- [x] D3: template UI (save/apply/manage) and `Email list` action, with accessibility labels.
- [x] D3: UI tests for template and export flows; Dynamic Type and VoiceOver pass for new surfaces.
- [x] D3: final end-to-end `scripts/verify.sh` run to close the slice (build + unit + UI tests green 2026-09-19).

- [x] D4: CloudKit entitlements wired (`Forgot the Milk.entitlements` with container `iCloud.com.hoaglun.forgotthemilk`, `com.apple.developer.icloud-services` = `CloudKit`, `CODE_SIGN_ENTITLEMENTS` in Debug and Release); build number 5 (2026-09-19).
- [x] D4: CloudKit sync domain — record mapping, sync-state reducer with Retry, whole-record last-writer-wins conflict policy, unsynced-mutation queue (with unit tests) (2026-09-20).
- [x] D4: fix the app launch crash — explicit `cloudKitDatabase: .none` at every `ModelConfiguration` site (the iOS 27 SDK default `.automatic` crashes launch and the test host under the CloudKit entitlement); build number 6 (2026-09-20).
- [x] D4: `CloudKitClient` seam with deterministic fakes (server clock, failure injection, two-device pair) and a connectivity monitor seam with a deterministic fake — delivered 2026-09-20, 17 unit tests, build number 7.
- [x] D4: reconciler — background launch/foreground reconcile, offline mutation queue replay in order, remote merge per conflict policy, share-change observation. Delivered 2026-09-21 as `SyncReconciler` + `SyncCoordinator` + `RealCloudKitClient` with app wiring and 11 unit tests; the sharing and settings UI surfaces remain (items below).
- [ ] D4: follow-up — hop the `SyncCoordinator` `onShareChange` and connectivity-change handlers onto the main actor (the callbacks currently invoke `@MainActor` state synchronously from background queues under Swift 5 minimal checking; a latent data race in production, not exercised by the deterministic tests).
- [ ] D4: sharing use cases — `Share List` (create/reuse `CKShare`, `readWrite`), collaborator display from share metadata, `Stop Sharing` (owner only), fresh-install share acceptance via `CKShare.Metadata`.
- [ ] D4: Settings UI — iCloud/account status, collaborators, share/stop-sharing controls, offline and error states with Retry; accessibility pass (large targets, Dynamic Type, VoiceOver).
- [ ] D4: CloudKit contract tests (fake client: share creation/acceptance, permission display, partial failures, conflict, stop-share), UI tests for share and status surfaces, manual two-Apple-ID smoke checklist.
- [ ] D4: final end-to-end `scripts/verify.sh` run plus signed-build entitlement verification to close the slice.

Use GitHub Issues for independently trackable work; link them here rather than duplicating their content.
