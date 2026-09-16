# Architecture

The Xcode project, minimal app shell, and unit-test harness exist; no domain, persistence, or sync code exists yet. The intended boundary is:

`SwiftUI views → domain/use cases → local persistence → sync reconciliation adapters`

Local SwiftData persistence will remain available while offline and is the UI source of truth. CloudKit/CKShare is introduced only as a D4 reconciliation and sharing adapter. Catalog data, connectivity, CloudKit, mail, and share-sheet presentation require deterministic test seams.
