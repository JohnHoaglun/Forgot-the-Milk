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
- [x] D4: follow-up — hop the `SyncCoordinator` `onShareChange` and connectivity-change handlers onto the main actor (the callbacks now wrap their state access in `Task { @MainActor in ... }` hops; delivered 2026-09-21 with the sharing use cases).
- [x] D4: sharing use cases — `Share List` (create/reuse `CKShare`, `readWrite`), collaborator display from share metadata, `Stop Sharing` (owner only) with confirmation, share acceptance via `acceptShareURL` with per-device `isOwner` and `ListShare` metadata persistence (delivered 2026-09-21; 6 coordinator unit tests).
- [x] D4: Settings UI — iCloud/account status, sync status with plain-language error text and Retry, collaborators, share/stop-sharing controls, unavailable state with disabled sharing and recovery instruction; accessibility identifiers plus an accessibility-size UI pass (delivered 2026-09-21; 4 UI tests).
- [x] D4: CloudKit contract tests (fake client: share creation/acceptance per device, stop-share, unavailable-account reconcile failure) and UI tests for the share and status surfaces (delivered 2026-09-21).
- [x] D4: signed-build entitlement verification and real-device sync — container `iCloud.com.hoaglun.forgotthemilk` and `com.apple.developer.icloud-services = [CloudKit]` confirmed in a signed iPhone build, and sync verified end-to-end on-device after fixing the real-server query behaviors (missing-type tolerance, queryable `updatedAt` with constant predicate, schema-version journal reset) (2026-09-22; build number 10).
- [ ] D4: manual two-Apple-ID smoke checklist — share, accept, edit, and stop-share on two signed devices with the real container (container now verified provisioned in a signed device build, 2026-09-22).
- [ ] D4: final end-to-end `scripts/verify.sh` run to close the slice.

Use GitHub Issues for independently trackable work; link them here rather than duplicating their content.
