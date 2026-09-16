# Forgot the Milk

## Status

Planning complete; implementation has not started. Current delivery slice: D1 — Foundation and catalog.

## Purpose

An iPhone-first, offline-first shared household shopping-list app with one combined list, a store-organized catalog, and iCloud sharing. The product specification remains the behavior authority.

## Platform

iOS 17+, Swift 5.9+, SwiftUI, SwiftData, CloudKit/CKShare. Bundle ID: `com.hoaglun.forgotthemilk`. CloudKit container: `iCloud.com.hoaglun.forgotthemilk`.

## Architecture status

No app architecture has been implemented. D1 establishes the app shell, local data model, deterministic seed catalog, and persisted-list behavior. Local persistence will be the source of truth; CloudKit will reconcile shared data in D4.
