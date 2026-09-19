# Architecture

The Xcode project, app shell, SwiftData schema, seed catalog, first-launch seeding, item use cases, the item-entry domain (`ItemDraft`, `ItemFormValidation`, `ItemEntryUseCases`), the template domain (`TemplateNameValidation`, `TemplateUseCases`, `TemplateApplyReport`), list grouping logic, the export text builder (`ListExport`), the email export seam (`EmailExportService` with `MailComposing`/`ShareSheetPresenting` platform adapters, system wrappers, and DEBUG fakes), the catalog picker, the item form (add/edit), the template and export sheets, the list screen, the unit-test harness, and the UI-test target exist; no sync code exists yet. Views read through `@Query` and mutate only through `ItemUseCases`, `ItemEntryUseCases`, and `TemplateUseCases`; `AppSeeding` owns persistence setup; `ListGrouping`, `CatalogSearch`, and `ListExport` are pure UI-shaping or export logic. The intended boundary is:

`SwiftUI views → domain/use cases → local persistence → sync reconciliation adapters`

Local SwiftData persistence will remain available while offline and is the UI source of truth. CloudKit/CKShare is introduced only as a D4 reconciliation and sharing adapter. Catalog data and mail/share-sheet presentation have deterministic fakes; connectivity and CloudKit seams arrive with D4.
