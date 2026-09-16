# Changelog

## Unreleased

- Added agent delivery contract and initial project-management documentation.
- Established the `Forgot the Milk` Xcode project (iPhone-only, iOS 17+, bundle `com.hoaglun.forgotthemilk`), the `Forgot the MilkTests` target, the shared scheme, and the canonical `scripts/verify.sh` build-and-test entry point.
- Delivered D1 (foundation and catalog): SwiftData schema (`HouseholdList`, `Category`, `CatalogItem`, `ListItem`, `Template`), deterministic SHA-256 seed IDs, the 26-category / 256-label seed catalog with a mechanical spec-vs-seed audit (`scripts/check_seed_catalog.sh`), idempotent first-launch seeding, complete/restore/delete/clear-completed use cases, and the list screen (category grouping, swipe actions, collapsed completed section, empty state). 24 automated tests pass through `scripts/verify.sh`.
