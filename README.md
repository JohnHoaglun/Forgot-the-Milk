# Forgot the Milk

An iPhone-first, offline-first grocery and household shopping-list app for a shared household. It is designed for a simple, collaborative experience: one combined list, store-ordered categories, real-time iCloud sharing, and no ads, subscriptions, or custom backend.

> **Project status:** D1 in progress. The Xcode project, test target, and verification harness are established; feature implementation has not started.

## The v1 experience

- One household list for groceries, errands, and ad-hoc store items.
- A built-in, store-organized catalog of 256 items, plus reusable household custom items.
- Optional quantity, unit, and note on every list item.
- Category ordering to match the household's regular store.
- Completed items kept in a collapsed section until manually cleared.
- Templates for recurring lists and a print-friendly email export.
- iCloud/CloudKit sharing with invited Apple ID collaborators.
- Full local operation while offline, with synchronization when connectivity returns.
- Large tap targets, swipe actions, Dynamic Type, and VoiceOver support.

## Product specification

The [product specification](<./%20Forgot%20the%20Milk%20--%20Product%20Specs.md>) is the source of truth for product behavior and implementation. It defines:

- the v1 boundary and explicitly deferred features;
- data model, screen behavior, collaboration, synchronization, and conflict rules;
- four independently testable delivery slices;
- the automated-test harness and manual release gate; and
- the complete seed catalog.

Read the specification before making implementation or scope decisions.

## Planned technology

| Area | Choice |
| --- | --- |
| Platform | iOS 17+ |
| Language and UI | Swift 5.9+ and SwiftUI |
| Local data | SwiftData |
| Collaboration | CloudKit and `CKShare` |
| Bundle ID | `com.hoaglun.forgotthemilk` |
| CloudKit container | `iCloud.com.hoaglun.forgotthemilk` |
| Dependencies | None; use Apple frameworks only |

## Delivery plan

1. **D1 — Foundation and catalog:** app shell, local data model, deterministic seed catalog, and persisted list behavior.
2. **D2 — Item workflow:** catalog picker, custom items, metadata, category order, and accessibility.
3. **D3 — Reuse and export:** templates plus plain-text email/share-sheet export.
4. **D4 — Collaboration:** CloudKit sharing, accepted invitations, offline reconciliation, and recovery states.

Every delivery must build, pass its assigned tests, and leave `main` runnable. See the specification for acceptance criteria.

## Getting started for contributors

1. Read the product specification and begin with D1 only.
2. Keep SwiftUI views separate from domain/use-case, persistence, and CloudKit-sync layers.
3. Make local persistence the source of truth; CloudKit is a reconciliation layer, not a UI dependency.
4. Build the deterministic XCTest harness alongside each delivery. Tests must use fakes for CloudKit, connectivity, mail, and share-sheet presentation.
5. Do not add deferred v2 features without updating the specification first.

## Apple setup required before D4

The owner must create and configure the App ID and CloudKit container in the Apple Developer account before real sharing can be tested:

- App ID: `com.hoaglun.forgotthemilk`
- CloudKit container: `iCloud.com.hoaglun.forgotthemilk`
- iCloud/CloudKit entitlement enabled for the signed development build

The D4 release gate includes manual two-Apple-ID sharing, offline/reconnect, large-text, and VoiceOver smoke tests.

## Privacy

Forgot the Milk collects no analytics and uses no tracking or custom backend. Shared household data is stored through the user's iCloud/CloudKit account; email or system sharing occurs only when the user explicitly invokes it.

## License

No license has been selected yet. Do not assume permission to reuse or redistribute this project until a license is added.
