# Forgot the Milk — Product Specification

## 1. Product and release boundary

An iPhone-first household shopping-list app for two or more iCloud users. It has one combined shopping list: groceries, household errands, and ad-hoc store items live together and are ordered by category. The app is free, contains no ads, and runs without a custom backend.

**v1 outcome:** either household member can add, annotate, check off, and share a reliably synchronized list—even while temporarily offline.

**Target:** iOS 17+, Swift 5.9+, SwiftUI, SwiftData for the local store, CloudKit private database plus `CKShare` for collaboration. App bundle identifier: `com.hoaglun.forgotthemilk`; CloudKit container: `iCloud.com.hoaglun.forgotthemilk`. UIKit may be used only where a platform API requires it. No third-party dependencies.

**Out of v1:** multiple store layouts, custom categories, coupons/reusable-bag reminders, notifications, themes, data export/backup, voice input, widget, Watch app, location/time reminders, search/filter, and full free-form natural-language parsing. Keep data-model extension points where cheap, but do not build their UI or behavior.

## 2. Product rules

1. There is exactly one active household list per shared household. It contains items from all categories plus any ad-hoc item.
2. A list item is either **needed** or **completed**. Completing does not delete it; reopening makes it needed again.
3. Needed items are grouped and ordered by the household's configured category order, then by ascending item `sortOrder` within each category. New items, and items moved to another category, append to the bottom of that category. Completed items appear in a collapsed `Completed (n)` section at the bottom.
4. Each item has a required display name and optional quantity/unit and note. Examples: `Milk — 1 gallon`; note: `the red one`.
5. Catalog items are reusable definitions identified by their stable catalog ID, not their display label. Adding one creates a new list-item instance; the same catalog item may be on the list only once while needed. If it is already completed, adding it reopens that instance rather than duplicating it. Identical labels in different categories are distinct catalog entries and must both be preserved.
6. An ad-hoc entry has a name and may be assigned a category. Its default category is `Other / errands`, and it is shown after catalog categories unless the user changes it.
7. All local mutations must succeed without a network connection. Sync resumes opportunistically when iCloud/Internet return.
8. Concurrent edits to different records both persist. Concurrent edits to the same record use whole-record last-writer-wins, determined by the later CloudKit server modification timestamp; v1 has no field-level merge or conflict dialog. Do not silently discard a local unsynced mutation that CloudKit rejects or cannot reconcile: surface a sync error and provide Retry. The UI must refresh after remote changes.
9. A template is a named snapshot of the *needed-item selections and their quantity, unit, note, category, and ordering*—not a snapshot of completion state. Applying a template adds/reopens its items without removing other currently needed items.
10. When a user accepts a shared household list after creating a personal list, preserve the personal list locally without merging it. Make the accepted household list the active list. v1 provides no list switcher; the preserved personal list is retained for future recovery or multi-list support.

## 3. Information model

Use stable UUIDs for local identity and persist CloudKit record identifiers/share metadata separately. Use `createdAt`, `updatedAt`, and a monotonic or timestamp-based ordering field on user-editable records.

| Entity | Required fields | Notes |
| --- | --- | --- |
| `HouseholdList` | id, title, categoryOrder, shareMetadata | Seed a personal list on first launch; its share metadata is nil until shared. |
| `Category` | id, name, defaultOrder, isSystem | v1 system categories are editable in order but not renamed/deleted. Use the source document's second-level shopping groups (for example, `Fresh vegetables` and `Personal care`) plus `Other / errands`. Do not show `FOODSTUFFS` or `HOUSEHOLD` as app categories. |
| `CatalogItem` | id, name, categoryID, defaultQuantity, defaultUnit, defaultNote, scope | Seeded items have `scope = builtIn` and are local, deterministic reference data that never syncs. A user may save a custom item with `scope = household`; those reusable catalog items sync to collaborators. |
| `ListItem` | id, listID, catalogItemID?, name, categoryID, quantity?, unit?, note?, state, sortOrder, createdAt, updatedAt | `state` is `needed` or `completed`; preserve values after completion. `sortOrder` controls ascending display order within the category. |
| `Template` | id, listID, name, entries, createdAt, updatedAt | `entries` embeds value snapshots; templates sync to collaborators. |

Seed categories and catalog items from the authoritative list in [Appendix A](#appendix-a--seed-catalog). Treat its `FOODSTUFFS` and `HOUSEHOLD` headings as seed-data organization only; use their child headings as the visible categories. Built-in catalog records are local and deterministic on every installation; they never sync. Sync household list items, category order, templates, and `scope = household` catalog items. Each Appendix A entry is identified by its category and label; preserve repeated labels in different categories as distinct entries. Preserve item labels as written (including slash-separated alternatives). Normalize only for duplicate matching: trim whitespace, collapse internal spaces, case/diacritic-insensitive compare.

## 4. Screens and interactions

### 4.1 List (default screen)

- Navigation title: `Forgot the Milk`; show a compact sync-status indicator only when syncing, unavailable, or failed.
- Needed items appear by category in configured order. A category header shows needed count.
- Within a category, list items display by ascending `sortOrder`; a newly added item appears last. v1 has no manual item reordering.
- Row: large tap target, accessible checkbox, name, and a secondary summary for quantity/unit and note when supplied.
- Tap checkbox or swipe trailing to complete; swipe leading or explicit action to restore in Completed. Swipe trailing reveals Delete with confirmation.
- `+ Add` opens the item-entry flow. `Edit` enables category reordering using drag handles; persist the resulting category order.
- Completed items are collapsed by default. Users can expand/collapse them; this preference is device-local. Provide `Clear completed` with confirmation; it permanently removes completed list items. Never clear items automatically.
- Dynamic Type must not truncate the item name; rows grow vertically. All non-text actions require VoiceOver labels/hints.

### 4.2 Add / edit item

- Add flow starts with a searchable catalog picker grouped by category. Search here is allowed because it is part of selection, not v2 list filtering.
- Selecting a catalog entry opens details prefilled from defaults; Save adds/reopens it.
- `Add custom item` opens the same details form with an empty name and category picker defaulting to `Other / errands`. It creates a one-time synced list item unless the user selects `Save to catalog`; that option creates a reusable, synced household catalog item for future selection.
- Detail form fields: Name (required, 1–120 visible characters), Quantity (optional free text, 1–40), Unit (optional free text, 1–40), Note (optional, 1–280), Category (required). Disable Save until valid.
- An existing list item opens this form for editing. Delete is available from the form and requires confirmation.
- Unit-system setting supplies the initial unit suggestion only; it never converts entered quantities.

### 4.3 Templates

- List toolbar/menu provides `Save as template` and `Apply template`.
- Saving asks for a nonblank unique template name (case-insensitive, 1–80 characters) and snapshots needed items. If none are needed, explain why saving is unavailable.
- Applying requires confirmation that it will add/reopen template items; report the number changed. Users can rename or delete templates with confirmation for deletion.

### 4.4 Sharing and settings

- Settings contains: iCloud/account status, collaborators, Share List, Stop Sharing (owner only), default unit system (Imperial/Metric), and an About/privacy statement that no custom backend is used.
- `Share List` creates or reuses a `CKShare` and opens the system share sheet. Recipients must use an Apple ID and accept the share to collaborate in the app.
- Display collaborators and their permission level using CloudKit share metadata. The owner can stop sharing; doing so leaves their local list intact and explains that collaborators lose access.
- If iCloud is unavailable, show a plain-language state and keep local list editing enabled; sharing controls are disabled with a recovery instruction.

### 4.5 Email export

- `Email list` exports needed items only as a plain-text, category-grouped body suitable for printing. Include quantity/unit and note; exclude completed items and collaborator metadata.
- Use `MFMailComposeViewController` when mail is configured. Otherwise generate the same text and present the system share sheet so it can be copied or sent by another mail app.

## 5. Technical behavior

- Separate UI, domain/use-case, persistence, and CloudKit-sync layers. Views must not call CloudKit directly.
- Make local persistence the source of truth. Queue/reconcile sync changes so the list remains immediately usable offline.
- On launch and foreground: load local data immediately, then reconcile CloudKit in the background. Observe share changes while active or refresh when returning to foreground.
- Treat CloudKit authentication, permission, quota, network, partial failure, and conflict errors as recoverable states. Show non-blocking status plus a Retry action; never block local edits.
- Use production-safe logging with `OSLog`; do not log item notes, collaborator identities, or share URLs.
- Do not collect analytics, use tracking, or transmit data other than through the user's iCloud/CloudKit account and user-invoked mail/share action.

## 6. Delivery plan

Each delivery must build, pass its tests, and leave `main` runnable. Do not begin the next slice with knowingly failing tests.

### D1 — App foundation and seeded catalog

Deliver an iOS app shell, SwiftData schema, seed migration, and read-only list view with category grouping and completion state persisted across relaunch. D1 has no user-facing item-entry or category-reordering flow; tests/development fixtures may create items to exercise list behavior.

Acceptance criteria:

- First launch seeds every supplied category and catalog label exactly once.
- The list opens with no needed items; fixture-created local items support complete, restore, delete, and Clear completed.
- The seeded category order persists across relaunch; completed items are collapsed by default.
- App is usable offline from first launch.

### D2 — Entry, metadata, and accessibility

Deliver catalog picker, custom items, item editing, duplicate/reopen rule, quantity/unit/note display, category reorder, and accessibility pass.

Acceptance criteria:

- A user can add a seeded item or custom item with all optional metadata, and can save a custom item permanently to the synced household catalog.
- Invalid forms cannot save; valid edits persist after relaunch.
- Adding an already-needed catalog item does not create a duplicate; adding its completed counterpart restores it.
- Dynamic Type and VoiceOver paths work for add, complete, restore, edit, and delete.

### D3 — Templates and email export

Deliver template save/apply/manage and email/share-sheet export.

Acceptance criteria:

- Template snapshots preserve each needed entry's metadata and do not preserve completed state.
- Applying a template leaves unrelated needed items in place and reports changed count.
- Export contains only needed items, grouped by category, with optional metadata when present.
- Devices without a configured Mail account can still share/copy the generated text.

### D4 — CloudKit collaboration and recovery

Deliver private/shared CloudKit records, CKShare invitation/acceptance, remote-refresh behavior, offline queue/reconciliation, collaborator management, and visible recoverable error states.

Acceptance criteria:

- An owner can invite a second Apple ID; accepted users see and can edit the same list.
- A remote add/edit/complete becomes visible to the other device without app reinstall (foreground refresh is acceptable for v1).
- Local edits made offline remain visible locally and sync when connectivity returns.
- A sync error preserves local changes, communicates the issue, and Retry attempts reconciliation.
- Stopping a share removes collaborator access without deleting the owner's local list.

## 7. Test harness and release gate

Create one repeatable XCTest-based harness, runnable in CI and locally on a simulator. Inject `Clock`, UUID generator, persistence repository, CloudKit client, connectivity monitor, mail composer, and share-sheet presenter so tests do not require real iCloud, Mail, or network access. Include deterministic fakes plus a resettable in-memory SwiftData store.

| Level | Required coverage |
| --- | --- |
| Unit | Validation limits; duplicate normalization; add/reopen behavior; completion/restore; category sorting; template snapshot/apply; export text; sync-state reducer and retry behavior. |
| Repository/integration | SwiftData persistence and seed idempotency; migration from an empty store; queued offline mutations replayed in order; incoming remote changes merge according to the stated conflict policy. |
| UI | Add a catalog item and custom item; edit metadata; complete/restore/delete; reorder category; save/apply template; accessibility identifiers and VoiceOver labels; dynamic-type smoke test. |
| CloudKit contract | Fake-client tests for share creation/acceptance, permission display, partial failures, conflict, and stop-share. Maintain a separately gated manual two-Apple-ID smoke checklist for a development CloudKit container. |

Minimum automated cases:

1. Fresh seed contains every Appendix A entry exactly once, identified by its `(category, label)` pair, and no duplicate `(category, normalized label)` pair after a second launch.
2. Offline add → relaunch → reconnect results in exactly one remote item.
3. Two offline edits to the same item resolve predictably, with no crash or lost unsynced operation.
4. A shared recipient's edit reaches the owner's list after sync refresh.
5. Export omits completed items and includes `quantity unit` plus note only when populated.
6. Template apply is idempotent for already-needed entries and reopens completed entries.
7. Every destructive action presents confirmation, and cancel leaves data unchanged.

**Release gate:** all unit, integration, and UI tests pass on the current iOS simulator; no build warnings introduced; manual two-device sharing, offline/reconnect, large-text, and VoiceOver smoke tests pass; privacy strings and CloudKit container entitlements are verified in a signed development build.

## 8. Final implementation decisions

- **Decided:** use the dedicated CloudKit container `iCloud.com.hoaglun.forgotthemilk` for app bundle `com.hoaglun.forgotthemilk`. The owner invites participants with `readWrite` permission by default; do not offer a read-only permission choice in v1. The owner can stop sharing.
- **Decided:** completed items remain until the user selects `Clear completed` and confirms. They are never cleared automatically.
- **Decided:** D4 supports accepting a `CKShare` invitation after a fresh installation. Preserve and handle `CKShare.Metadata` during the app launch/activation flow so the recipient can join without a replacement invitation.

## Appendix A — Seed catalog

This is the authoritative v1 built-in catalog. The two top-level headings organize seed data only; each child heading is a visible, reorderable system category. Item labels must be seeded exactly as written.

### FOODSTUFFS

#### Fresh vegetables

- Asparagus
- Broccoli
- Carrots
- Cauliflower
- Celery
- Corn
- Cucumbers
- Lettuce / Greens
- Mushrooms
- Onions
- Peppers
- Potatoes
- Spinach
- Squash
- Zucchini
- Tomatoes

#### Fresh fruits

- Apples
- Avocados
- Bananas
- Berries
- Cherries
- Grapefruit
- Grapes
- Kiwis
- Lemons / Limes
- Melon
- Oranges
- Peaches
- Nectarines
- Pears
- Plums

#### Refrigerated items

- Bagels
- Chip dip
- English muffins
- Eggs / Fake eggs
- Fruit juice
- Hummus
- Ready-bake breads
- Tofu
- Tortillas

#### Frozen

- Breakfasts
- Burritos
- Fish sticks
- Ice cream / Sorbet
- Juice concentrate
- Pizza / Pizza Rolls
- Popsicles
- Fries / Tater tots
- TV dinners
- Vegetables
- Veggie burgers

#### Condiments / Sauces

- BBQ sauce
- Gravy
- Honey
- Hot sauce
- Jam / Jelly / Preserves
- Ketchup / Mustard
- Mayonnaise
- Pasta sauce
- Relish
- Salad dressing
- Salsa
- Soy sauce
- Steak sauce
- Syrup
- Worcestershire sauce

#### Various groceries

- Bouillon cubes
- Cereal
- Coffee / Filters
- Instant potatoes
- Lemon / Lime juice
- Mac & cheese
- Olive oil
- Pancake / Waffle mix
- Pasta
- Peanut butter
- Pickles
- Rice
- Tea
- Vegetable oil
- Vinegar

#### Canned foods

- Applesauce
- Baked beans
- Chili
- Fruit
- Olives
- Tinned meats
- Tuna / Chicken
- Soups
- Tomatoes
- Veggies

#### Spices & herbs

- Basil
- Black pepper
- Cilantro
- Cinnamon
- Garlic
- Ginger
- Mint
- Oregano
- Paprika
- Parsley
- Red pepper
- Salt
- Spice mix
- Vanilla extract

#### Dairy

- Butter / Margarine
- Cottage cheese
- Half & half
- Milk
- Sour cream
- Whipped cream
- Yogurt

#### Cheese

- Bleu cheese
- Cheddar
- Cottage cheese
- Cream cheese
- Feta
- Goat cheese
- Mozzarella / Provolone
- Parmesan
- Provolone
- Ricotta
- Sandwich slices
- Swiss

#### Meat

- Bacon / Sausage
- Beef
- Chicken
- Ground beef / Turkey
- Ham / Pork
- Hot dogs
- Lunchmeat
- Turkey

#### Seafood

- Catfish
- Crab
- Lobster
- Mussels
- Oysters
- Salmon
- Shrimp
- Tilapia
- Tuna

#### Beverages

- Beer
- Club soda / Tonic
- Champagne
- Gin
- Juice
- Mixers
- Red wine / White wine
- Rum
- Saké
- Soda pop
- Sports drink
- Whiskey
- Vodka

#### Baked goods

- Bagels / Croissants
- Buns / Rolls
- Cake / Cookies
- Donuts / Pastries
- Fresh bread
- Sliced bread
- Pie
- Pita bread

#### Baking

- Baking powder / Soda
- Bread crumbs
- Cake / Brownie mix
- Cake icing / Decorations
- Chocolate chips / Cocoa
- Flour
- Shortening
- Sugar
- Sugar substitute
- Yeast

#### Snacks

- Candy / Gum
- Cookies
- Crackers
- Dried fruit
- Granola bars / Mix
- Nuts / Seeds
- Oatmeal
- Popcorn
- Potato / Corn chips
- Pretzels

#### Themed meals

- Burger night
- Chili night
- Pizza night
- Spaghetti night
- Taco night
- Take-out deli food

#### Baby stuff

- Baby food
- Diapers
- Formula
- Lotion
- Baby wash
- Wipes

#### Pets

- Cat food / Treats
- Cat litter
- Dog food / Treats
- Flea treatment
- Pet shampoo

### HOUSEHOLD

#### Personal care

- Antiperspirant / Deodorant
- Bath soap / Hand soap
- Condoms / Other b.c.
- Cosmetics
- Cotton swabs / Balls
- Facial cleanser
- Facial tissue
- Feminine products
- Floss
- Hair gel / Spray
- Lip balm
- Moisturizing lotion
- Mouthwash
- Razors / Shaving cream
- Shampoo / Conditioner
- Sunblock
- Toilet paper
- Toothpaste
- Vitamins / Supplements

#### Medicine

- Allergy
- Antibiotic
- Antidiarrheal
- Aspirin
- Antacid
- Band-aids / Medical
- Cold / Flu / Sinus
- Pain reliever
- Prescription pick-up

#### Kitchen

- Aluminum foil
- Napkins
- Non-stick spray
- Paper towels
- Plastic wrap
- Sandwich / Freezer bags
- Wax paper

#### Cleaning products

- Air freshener
- Bathroom cleaner
- Bleach / Detergent
- Dish / Dishwasher soap
- Garbage bags
- Glass cleaner
- Mop head / Vacuum bags
- Sponges / Scrubbers

#### Office supplies

- CDRs / DVDRs
- Notepad / Envelopes
- Glue / Tape
- Printer paper
- Pens / Pencils
- Postage stamps

#### Other stuff

- Automotive
- Batteries
- Charcoal / Propane
- Flowers / Greeting card
- Insect repellent
- Light bulbs
- Newspaper / Magazine
- Random impulse buy
