# Forgot the Milk — Agent Instructions

## Product authority

Read ` Forgot the Milk -- Product Specs.md` and `README.md` before changing implementation or scope. The specification is authoritative for v1 behavior, deferred features, acceptance criteria, and delivery slices.

Work only on the currently accepted delivery slice: D1 foundation and catalog; D2 item workflow; D3 templates and export; D4 CloudKit collaboration. Do not begin a later slice merely because its architecture appears convenient.

## Delivery loop

For every completed, file-changing delivery: inspect status and relevant docs; make the smallest coherent change; update only documentation whose facts changed; run proportionate verification; review the diff; commit code, tests, build metadata, and docs atomically; then push to `origin`. A task is not done solely because a tool succeeds: relevant checks must pass or a concrete blocker must be recorded.

Maintain `PROJECT.md`, `PLAN.md`, `TODO.md`, `ARCHITECTURE.md`, `DECISIONS.md`, and `CHANGELOG.md` truthfully. Link GitHub Issues from `TODO.md` instead of duplicating them. Check whether a file or directory exists before creating it and preserve unrelated user work.

## Architecture and product constraints

- Target iOS 17+, SwiftUI, SwiftData, CloudKit, and CKShare; use Apple frameworks only unless the specification changes.
- Local persistence is the source of truth. CloudKit is a reconciliation and sharing layer, never a UI dependency.
- Keep views separate from domain/use-case logic, persistence, catalog data, CloudKit sync, and platform-presentation adapters.
- Build deterministic fakes for CloudKit, connectivity, mail, and share-sheet presentation.
- Preserve offline-first behavior and deterministic conflict handling.
- Do not add accounts, ads, subscriptions, analytics, tracking, custom backend services, or deferred v2 features without a specification update.
- Accessibility is an acceptance criterion: large targets, Dynamic Type, VoiceOver, and usable swipe actions.

## Verification

Discover projects, schemes, test targets, and existing scripts before selecting commands; never guess a scheme name. Keep `scripts/verify.sh` as the canonical verification entry point. D1–D3 require simulator build and deterministic tests for changed behavior. D4 additionally requires recorded manual two-Apple-ID sharing, offline/reconnect, large-text, and VoiceOver checks. Do not claim real sharing was tested until the App ID `com.hoaglun.forgotthemilk`, container `iCloud.com.hoaglun.forgotthemilk`, and signed entitlements are configured.

## Versioning and Git safety

Maintain `VERSIONS_LOCATIONS.md` as the inventory of version/build locations. Keep marketing version separate from a monotonically increasing build number; increment the build number once per completed file-changing delivery and change marketing version only for an intentional release. Xcode build settings and `Info.plist` values are authoritative. Never force-push, rewrite history, reset destructively, commit secrets/signing material, or include unrelated changes.
