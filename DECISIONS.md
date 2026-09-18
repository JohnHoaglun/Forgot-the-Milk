# Decisions

| Date | Decision | Rationale |
| --- | --- | --- |
| 2026-09-15 | Keep local persistence as the source of truth. | The app must remain usable offline; CloudKit is a reconciliation layer. |
| 2026-09-15 | Use Apple frameworks only for v1. | The specification calls for no dependencies or custom backend. |
| 2026-09-15 | Store D1 work on branch `dev` and push there until the delivery slices are complete. | Keeps in-progress work off `main` while the delivery loop completes. |
| 2026-09-15 | Project creation establishes the recorded version baseline (marketing 0.0.0, build 1); each later file-changing delivery increments the build number. | Matches the version inventory recorded before the project existed. |
| 2026-09-15 | Unit tests use the Swift Testing framework in a hosted `Forgot the MilkTests` target. | Xcode 27 default; satisfies the deterministic test-harness requirement. |
| 2026-09-15 | Keep the seed catalog in Swift source and verify it with `scripts/check_seed_catalog.sh` (mechanical spec-vs-seed audit) on every delivery. | Deterministic, repeatable verification with no external tooling; catches transcription drift. |
| 2026-09-15 | The personal list is titled "My List" and empty categories are hidden in D1. | Keeps the D1 surface minimal per the acceptance criteria; both are revisited in D2. |
| 2026-09-15 | In the catalog picker, needed catalog items are shown marked "Added" and non-selectable; completed ones stay selectable so selecting reopens them. | Makes the duplicate/reopen rule visible without hiding catalog state. |
| 2026-09-15 | Custom (non-catalog) items follow the same add/reopen rule matched by (category, normalized name): needed → no-op, completed → restore. | Extends spec rule 5 with the spec's normalization rule. |
| 2026-09-15 | "Save to catalog" is offered only when adding a custom item, not when editing a one-off item. | Keeps the edit form minimal per spec 4.2. |
| 2026-09-15 | The unit-system setting is a persisted value (default Imperial) plus a domain seam in D2; the settings UI and initial-unit suggestion ship with D4. | The settings screen is D4 scope; the suggestion rule never converts quantities. |
| 2026-09-15 | DEBUG-only launch arguments `resetDatabaseOnLaunch` and `contentSizeCategory` are the deterministic UI-test seams. | UI tests need a clean store and a forced Dynamic Type size without touching real settings. |
| 2026-09-15 | D2 adds an XCUITest target `Forgot the MilkUITests`; `scripts/verify.sh` runs unit tests then UI tests. | Spec section 7 requires UI-level coverage in the canonical harness. |
| 2026-09-17 | List-scoped destructive confirmations (delete item, clear completed) use `.alert` instead of `.confirmationDialog`. | On the iOS simulators tested, SwiftUI renders a List-anchored `confirmationDialog` as a top-anchored popover whose button container is sized for one button, clipping the second button out of the accessibility tree; a system alert always renders all buttons and keeps cancel reachable. The item form's delete confirmation keeps `confirmationDialog` because it renders correctly from its sheet context. |
