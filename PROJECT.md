# Forgot the Milk

## Status

D1–D3 delivered and verified by `scripts/verify.sh` (foundation and catalog; item workflow; templates and email export). Current delivery slice: D4 — CloudKit collaboration and recovery (sync domain, `CloudKitClient` seam with deterministic fakes, and connectivity seam landed; reconciler, sharing use cases, and settings UI remain).

## Purpose

An iPhone-first, offline-first shared household shopping-list app with one combined list, a store-organized catalog, and iCloud sharing. The product specification remains the behavior authority.

## Platform

iOS 17+, Swift 5.9+, SwiftUI, SwiftData, CloudKit/CKShare. Bundle ID: `com.hoaglun.forgotthemilk`. CloudKit container: `iCloud.com.hoaglun.forgotthemilk`.

## Architecture status

The app shell, SwiftData schema (`HouseholdList`, `Category`, `CatalogItem`, `ListItem`, `Template`), deterministic seed catalog (26 categories, 256 labels, audited by `scripts/check_seed_catalog.sh`), idempotent first-launch seeding, list item use cases (complete/restore/delete/clear-completed), the item-entry domain (validation, normalization, add/reopen, save-to-catalog, reorder, unit-system seam), the catalog picker and item form (add/edit), category reorder in Edit mode, the list screen with category grouping and a collapsible completed section, the template domain and export flow, and the D4 sync layer (pure sync domain: `SyncRecord`/`SyncRecordMapping`, `ConflictPolicy`, `MutationQueue`/`SyncBaselines`, `SyncState`; platform seams: `CloudKitClient` with DEBUG `FakeCloudKitClient`/`FakeCloudKitServer` two-device pair, and `ConnectivityMonitoring` with `SystemConnectivityMonitor`/`FakeConnectivityMonitor`) exist. Local persistence is the source of truth; the CloudKit reconciler and sharing use cases arrive in the remaining D4 work.
