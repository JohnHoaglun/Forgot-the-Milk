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
