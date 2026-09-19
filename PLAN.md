# Delivery Plan

## Active milestone

D3 — Templates and email export. D1 (foundation and catalog) and D2 (item workflow) were delivered and verified by `scripts/verify.sh`.

### D3 work breakdown

Existing seams: the `Template`/`TemplateEntry` models already exist (D1 schema); `ItemEntryUseCases.add(_:) -> AddResult` (`.added`/`.alreadyNeeded`/`.reopened`/`.invalid`) is the add/reopen rule that template apply must reuse; `ListGrouping` supplies the persisted category order; the UI-test DEBUG launch-argument seams exist.

1. Template domain (pure, unit-tested): name validation (nonblank, 1–80 grapheme characters, case-insensitive unique per list); save snapshots only *needed* items (name, categoryID, quantity, unit, note, catalogItemID, ordering) and is unavailable with an explanation when nothing is needed; apply builds an `ItemDraft` per `TemplateEntry` and runs it through `ItemEntryUseCases.add`, reporting changed count = `added` + `reopened` (unrelated needed items untouched); rename and delete.
2. List export domain (pure, unit-tested): plain-text body of needed items only, grouped by persisted category order, including quantity/unit and note when present, excluding completed items and collaborator metadata; deterministic string pinned by unit tests.
3. Platform adapters with deterministic fakes: `MailComposer` (wraps `MFMailComposeViewController`, exposes `canCompose`) and `ShareSheetPresenter` (wraps `UIActivityViewController`); `EmailExportService` uses mail when configured, otherwise presents the same generated text through the share sheet.
4. UI: list toolbar menu providing `Save as template` and `Apply template` (with the template list), name-entry sheet with validation, apply confirmation alert followed by the changed-count report, template management (rename, delete with confirmation), unavailable-state explanation when nothing is needed, and an `Email list` action. Accessibility: large targets, Dynamic Type, and VoiceOver labels for every new surface.
5. UI tests: save/apply (changed-count report)/rename/delete flows, export via share-sheet fake and via mail-configured fake, and Dynamic Type/VoiceOver passes for the new surfaces.
6. Docs (CHANGELOG, ARCHITECTURE, DECISIONS), build number bump, `scripts/verify.sh` green, atomic commit, push.

Status (2026-09-19): steps 1–5 implemented; full gate passed (build, 20+ unit tests, 23 UI tests green); docs updated and build number 4 committed. **D3 closed.**

Spec anchors: §4.3 (templates), §4.5 (email export), rule 9 (a template snapshots needed-item selections, never completion state), and the D3 acceptance criteria (snapshot metadata without completion state; apply leaves unrelated items and reports changed count; needed-only category-grouped export; sharing/copying works without a configured Mail account).

## Delivery sequence

1. D1 (delivered): app shell, local model, deterministic catalog, persisted list behavior.
2. D2 (delivered): catalog picker, custom items, metadata, category order, accessibility.
3. D3: reusable templates and plain-text email/share-sheet export.
4. D4: CloudKit sharing, invitations, offline reconciliation, and recovery states.

## Blockers

No implementation blocker is currently recorded. Before real D4 validation, configure the App ID, CloudKit container, and signed iCloud entitlements.

## Verification gate

Every delivery leaves `main` runnable and passes its assigned automated tests. D4 also requires manual two-Apple-ID sharing, offline/reconnect, Dynamic Type, and VoiceOver checks.
