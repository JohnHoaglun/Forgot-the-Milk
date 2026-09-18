# Forgot the Milk

## Status

D2 complete: item entry (catalog and custom), metadata, the duplicate/reopen rule, save-to-catalog, category reorder, and accessibility coverage, delivered on top of the D1 foundation and verified by `scripts/verify.sh`. Current delivery slice: D3 — templates and export.

## Purpose

An iPhone-first, offline-first shared household shopping-list app with one combined list, a store-organized catalog, and iCloud sharing. The product specification remains the behavior authority.

## Platform

iOS 17+, Swift 5.9+, SwiftUI, SwiftData, CloudKit/CKShare. Bundle ID: `com.hoaglun.forgotthemilk`. CloudKit container: `iCloud.com.hoaglun.forgotthemilk`.

## Architecture status

The app shell, SwiftData schema (`HouseholdList`, `Category`, `CatalogItem`, `ListItem`, `Template`), deterministic seed catalog (26 categories, 256 labels, audited by `scripts/check_seed_catalog.sh`), idempotent first-launch seeding, list item use cases (complete/restore/delete/clear-completed), the item-entry domain (validation, normalization, add/reopen, save-to-catalog, reorder, unit-system seam), the catalog picker and item form (add/edit), category reorder in Edit mode, and the list screen with category grouping and a collapsible completed section exist. Local persistence is the source of truth; CloudKit will reconcile shared data in D4.
