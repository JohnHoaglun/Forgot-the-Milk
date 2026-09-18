# Architecture

The Xcode project, app shell, SwiftData schema, seed catalog, first-launch seeding, item use cases, the item-entry domain (`ItemDraft`, `ItemFormValidation`, `ItemEntryUseCases`), list grouping logic, the catalog picker, the item form (add/edit), the list screen, the unit-test harness, and the UI-test target exist; no sync code exists yet. Views read through `@Query` and mutate only through `ItemUseCases` and `ItemEntryUseCases`; `AppSeeding` owns persistence setup; `ListGrouping` and `CatalogSearch` are pure UI-shaping logic. The intended boundary is:

`SwiftUI views → domain/use cases → local persistence → sync reconciliation adapters`

Local SwiftData persistence will remain available while offline and is the UI source of truth. CloudKit/CKShare is introduced only as a D4 reconciliation and sharing adapter. Catalog data, connectivity, CloudKit, mail, and share-sheet presentation require deterministic test seams.
