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
- [ ] D3: final end-to-end `scripts/verify.sh` run to close the slice (implementation, tests, docs, and build number 4 committed 2026-09-19).

## Later

- [ ] D4 CloudKit sharing and reconciliation.

Use GitHub Issues for independently trackable work; link them here rather than duplicating their content.
