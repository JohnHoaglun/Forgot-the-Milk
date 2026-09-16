# Architecture

The Xcode project, app shell, SwiftData schema, seed catalog, first-launch seeding, item use cases, list grouping logic, list screen, and unit-test harness exist; no sync code exists yet. Views read through `@Query` and mutate only through `ItemUseCases`; `AppSeeding` owns persistence setup; `ListGrouping` is pure UI-shaping logic. The intended boundary is:

`SwiftUI views → domain/use cases → local persistence → sync reconciliation adapters`

Local SwiftData persistence will remain available while offline and is the UI source of truth. CloudKit/CKShare is introduced only as a D4 reconciliation and sharing adapter. Catalog data, connectivity, CloudKit, mail, and share-sheet presentation require deterministic test seams.
