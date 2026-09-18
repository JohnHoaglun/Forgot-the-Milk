# Delivery Plan

## Active milestone

D3 — Templates and export. D1 (foundation and catalog) and D2 (item workflow) were delivered and verified by `scripts/verify.sh`.

## Delivery sequence

1. D1 (delivered): app shell, local model, deterministic catalog, persisted list behavior.
2. D2 (delivered): catalog picker, custom items, metadata, category order, accessibility.
3. D3: reusable templates and plain-text email/share-sheet export.
4. D4: CloudKit sharing, invitations, offline reconciliation, and recovery states.

## Blockers

No implementation blocker is currently recorded. Before real D4 validation, configure the App ID, CloudKit container, and signed iCloud entitlements.

## Verification gate

Every delivery leaves `main` runnable and passes its assigned automated tests. D4 also requires manual two-Apple-ID sharing, offline/reconnect, Dynamic Type, and VoiceOver checks.
