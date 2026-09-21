//
//  Forgot_the_MilkUITests.swift
//  Forgot the MilkUITests
//
//  D2 UI coverage: catalog/custom entry, metadata, duplicate/reopen rule,
//  complete/restore, delete, category reorder (drag handles), Dynamic Type,
//  and VoiceOver labels.
//  D3 UI coverage: templates (save, apply, rename, delete) and the email
//  export flow through the DEBUG deterministic fakes (share-sheet fallback
//  and configured mail), plus large-text usage of the new surfaces.
//
//  Every test launches with the DEBUG-only `resetDatabaseOnLaunch` argument
//  so it starts from a clean, seeded store. Persistence tests terminate the
//  app and relaunch without the reset argument.
//

import XCTest

final class Forgot_the_MilkUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        app.terminate()
    }

    // MARK: - Helpers

    private func launch(resetDatabase: Bool = true, typeSize: String? = nil, extraArguments: [String] = []) {
        var arguments: [String] = []
        if resetDatabase {
            arguments.append("resetDatabaseOnLaunch")
        }
        if let typeSize {
            arguments.append("contentSizeCategory=\(typeSize)")
        }
        arguments.append(contentsOf: extraArguments)
        app.launchArguments = arguments
        app.launch()
    }

    private func relaunch() {
        app.terminate()
        launch(resetDatabase: false)
    }

    private func openCatalogPicker() {
        let addButton = app.buttons["add-item-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add Item button should be visible")
        addButton.tap()
        XCTAssertTrue(app.buttons["custom-item-entry"].waitForExistence(timeout: 5), "Catalog picker should be visible")
    }

    private func returnToList() {
        // While the catalog search field is focused, its active search bar
        // replaces the navigation bar, so the back button is unreachable.
        // Collapse the search first; the close button only exists then.
        let closeSearch = app.buttons["close"]
        if closeSearch.waitForExistence(timeout: 1) {
            closeSearch.tap()
        }
        let back = app.navigationBars["Add Item"].buttons.firstMatch
        guard back.waitForExistence(timeout: 5) else {
            let navBars = app.navigationBars.allElementsBoundByIndex
                .prefix(5)
                .map { $0.label ?? "(no label)" }
            let buttons = app.buttons.allElementsBoundByIndex
                .prefix(30)
                .map { $0.label ?? "(no label)" }
            saveScreenshot(named: "returnToList")
            XCTFail("Picker back button not visible. Navigation bars: \(navBars). Buttons: \(buttons)")
            return
        }
        back.tap()
        XCTAssertTrue(app.buttons["add-item-button"].waitForExistence(timeout: 5), "List should be visible")
    }

    /// Finds a button by its accessibility label (used for elements whose
    /// accessibility identifier is a stable but unguessable UUID).
    private func button(withLabel label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func staticText(withLabel label: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Searches the catalog for the item name (scrolling a possibly
    /// off-screen row into the visible area) and returns the picker row
    /// whose accessibility label is `label`. Fails with a snapshot of the
    /// visible buttons when the row does not appear.
    private func catalogRow(name: String, label: String) -> XCUIElement {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Catalog search field should be visible")
        searchField.tap()
        app.typeText(name)

        // Rows that are already needed are not buttons (no NavigationLink),
        // so match any element type by accessibility label.
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch
        if !row.waitForExistence(timeout: 5) {
            let visible = app.buttons.allElementsBoundByIndex
                .prefix(30)
                .map { $0.label ?? "(no label)" }
            saveScreenshot(named: "catalogRow")
            XCTFail("Catalog row '\(label)' not visible after searching for '\(name)'. Visible buttons: \(visible)")
        }
        return row
    }

    /// Expands the completed section only if it is collapsed, then returns
    /// the completed row with the given accessibility label.
    private func showCompletedItem(labeled label: String) -> XCUIElement {
        let row = button(withLabel: label)
        if !row.exists {
            let toggle = app.buttons["completed-section-toggle"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Completed section toggle should be visible")
            toggle.tap()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Completed row '\(label)' should be visible")
        return row
    }

    private func addCatalogItem(_ name: String, quantity: String? = nil, unit: String? = nil, note: String? = nil) {
        openCatalogPicker()
        catalogRow(name: name, label: name).tap()

        let save = app.buttons["item-form-save-button"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Item form should be visible")

        if let quantity {
            app.textFields["item-form-quantity-field"].tap()
            app.typeText(quantity)
        }
        if let unit {
            app.textFields["item-form-unit-field"].tap()
            app.typeText(unit)
        }
        if let note {
            app.textFields["item-form-note-field"].tap()
            app.typeText(note)
        }

        save.tap()
        returnToList()
    }

    private func addCustomItem(_ name: String, quantity: String? = nil, unit: String? = nil, note: String? = nil, saveToCatalog: Bool = false) {
        openCatalogPicker()
        app.buttons["custom-item-entry"].tap()

        let save = app.buttons["item-form-save-button"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Custom item form should be visible")

        // Toggle before any text entry so the keyboard never covers it.
        if saveToCatalog {
            // If the picker's search field is active its search bar (and
            // keyboard) can cover the toggle; collapse it first.
            let closeSearch = app.buttons["close"]
            if closeSearch.waitForExistence(timeout: 1) {
                closeSearch.tap()
            }
            let toggle = app.switches["save-to-catalog-toggle"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Save to catalog toggle should be visible")
            // The element is the whole row; its center is the label, which
            // does not toggle. Tap the switch at the row's trailing edge.
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            // The accessibility value can lag the tap, so poll briefly.
            let deadline = Date().addingTimeInterval(2)
            while !switchIsOn(toggle) && Date() < deadline {
                usleep(50_000)
            }
            XCTAssertTrue(switchIsOn(toggle), "Save to catalog toggle should be on")
        }

        app.textFields["item-form-name-field"].tap()
        app.typeText(name)
        if let quantity {
            app.textFields["item-form-quantity-field"].tap()
            app.typeText(quantity)
        }
        if let unit {
            app.textFields["item-form-unit-field"].tap()
            app.typeText(unit)
        }
        if let note {
            app.textFields["item-form-note-field"].tap()
            app.typeText(note)
        }

        save.tap()
        returnToList()
    }

    private func openEditSheet(for name: String) {
        let row = app.staticTexts[name]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Row for \(name) should be visible")
        row.tap()
        let save = app.buttons["item-form-save-button"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Edit form should be visible")
    }

    private func categoryRow(_ name: String) -> XCUIElement {
        app.descendants(matching: .any)["category-row-\(name)"]
    }

    private func saveScreenshot(named name: String) {
        guard let data = app.screenshot().pngRepresentation as Data? else { return }
        try? data.write(to: URL(fileURLWithPath: "/tmp/fmm-\(name).png"))
    }

    private func waitUntil(_ timeout: TimeInterval, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            usleep(100_000)
        }
    }

    // MARK: - Entry

    func testEmptyListShowsEmptyState() {
        launch()
        XCTAssertTrue(app.staticTexts["Your list is empty"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["empty-state-add-button"].exists)
    }

    func testAddCatalogItemWithMetadata() {
        launch()
        addCatalogItem("Milk", quantity: "2", unit: "liters", note: "whole milk")

        XCTAssertTrue(staticText(withLabel: "Dairy (1)").exists)
        XCTAssertTrue(app.staticTexts["Milk"].exists)
        XCTAssertTrue(staticText(withLabel: "2 liters \u{00B7} whole milk").exists)
        XCTAssertTrue(button(withLabel: "Mark Milk as completed").exists)
    }

    func testAddCustomItemWithMetadata() {
        launch()
        addCustomItem("Sourdough", quantity: "1", unit: "loaf", note: "for sandwiches")

        XCTAssertTrue(staticText(withLabel: "Other / errands (1)").exists)
        XCTAssertTrue(app.staticTexts["Sourdough"].exists)
        XCTAssertTrue(staticText(withLabel: "1 loaf \u{00B7} for sandwiches").exists)
    }

    func testInvalidCustomFormCannotSave() {
        launch()
        openCatalogPicker()
        app.buttons["custom-item-entry"].tap()

        let save = app.buttons["item-form-save-button"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)
        XCTAssertTrue(app.staticTexts["Name is required."].exists)

        app.textFields["item-form-name-field"].tap()
        app.typeText("Sourdough")

        XCTAssertTrue(save.isEnabled)
        XCTAssertFalse(app.staticTexts["Name is required."].exists)

        app.buttons["item-form-cancel-button"].tap()
        returnToList()
    }

    // MARK: - Persistence and editing

    func testMetadataPersistsAfterRelaunch() {
        launch()
        addCustomItem("Sourdough", quantity: "1", unit: "loaf", note: "for sandwiches")

        relaunch()

        XCTAssertTrue(app.staticTexts["Sourdough"].waitForExistence(timeout: 5))
        XCTAssertTrue(staticText(withLabel: "Other / errands (1)").exists)
        XCTAssertTrue(staticText(withLabel: "1 loaf \u{00B7} for sandwiches").exists)
    }

    func testEditMetadataPersistsAfterRelaunch() {
        launch()
        addCustomItem("Sourdough")

        openEditSheet(for: "Sourdough")
        app.textFields["item-form-note-field"].tap()
        app.typeText("stale, for toast")
        app.buttons["item-form-save-button"].tap()

        relaunch()

        XCTAssertTrue(app.staticTexts["stale, for toast"].waitForExistence(timeout: 5))
    }

    func testCancelEditDiscardsChanges() {
        launch()
        addCustomItem("Sourdough")

        openEditSheet(for: "Sourdough")
        app.textFields["item-form-note-field"].tap()
        app.typeText("should not persist")
        app.buttons["item-form-cancel-button"].tap()

        XCTAssertFalse(app.staticTexts["should not persist"].exists)
        XCTAssertTrue(app.staticTexts["Sourdough"].exists)
    }

    // MARK: - Duplicate and reopen

    func testCatalogDuplicateAndReopen() {
        launch()
        addCatalogItem("Milk")

        openCatalogPicker()
        catalogRow(name: "Milk", label: "Milk, already added")
        returnToList()

        button(withLabel: "Mark Milk as completed").tap()
        XCTAssertTrue(button(withLabel: "Completed items, 1").exists)

        openCatalogPicker()
        catalogRow(name: "Milk", label: "Milk, completed, tap to add again").tap()
        app.buttons["item-form-save-button"].tap()
        returnToList()

        XCTAssertTrue(button(withLabel: "Mark Milk as completed").exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == 'Milk'")).count, 1)
        XCTAssertFalse(button(withLabel: "Completed items, 1").exists)
    }

    // MARK: - Complete, restore, delete

    func testCompleteAndRestoreItem() {
        launch()
        addCatalogItem("Milk")

        button(withLabel: "Mark Milk as completed").tap()
        XCTAssertFalse(button(withLabel: "Mark Milk as completed").exists)
        XCTAssertTrue(button(withLabel: "Completed items, 1").exists)

        showCompletedItem(labeled: "Mark Milk as needed").tap()

        XCTAssertTrue(button(withLabel: "Mark Milk as completed").exists)
        XCTAssertFalse(button(withLabel: "Completed items, 1").exists)
    }

    func testSwipeActionCompletesItem() {
        launch()
        addCatalogItem("Apples")

        revealTrailingActions(onItem: "Apples")
        let complete = app.buttons["Complete"].firstMatch
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()

        XCTAssertTrue(button(withLabel: "Completed items, 1").exists)
    }

    /// Taps the row's trailing Delete swipe action until the confirmation
    /// alert is visible, retrying when the tap lands elsewhere (closing a
    /// stray edit form first).
    private func openDeleteDialog(forItem name: String) {
        for _ in 1...4 {
            if app.buttons["item-form-save-button"].exists {
                app.buttons["item-form-cancel-button"].firstMatch.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
            // A fast swipeLeft() on the item's name can be read as a tap and
            // open the edit form instead of revealing the trailing actions;
            // the press-and-drag reveal in revealTrailingActions is reliable.
            revealTrailingActions(onItem: name)
            let delete = app.buttons["Delete"].firstMatch
            guard delete.waitForExistence(timeout: 3) else { continue }
            // If the edit form opened anyway, its own Delete button matches;
            // cancel it and retry from the top of the loop.
            guard !app.buttons["item-form-save-button"].exists else { continue }
            delete.tap()
            if app.alerts.firstMatch.waitForExistence(timeout: 3) { return }
        }
        XCTFail("Delete confirmation alert did not appear for \(name)")
    }

    func testDeleteItem() {
        launch()
        addCatalogItem("Milk")

        openDeleteDialog(forItem: "Milk")
        let confirm = app.alerts.firstMatch.buttons["Delete"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()

        XCTAssertTrue(
            app.staticTexts["Your list is empty"].waitForExistence(timeout: 3),
            "List should be empty after deleting the only item"
        )
    }

    func testCancelDeleteKeepsItem() {
        launch()
        addCatalogItem("Milk")

        openDeleteDialog(forItem: "Milk")
        let cancel = app.alerts.firstMatch.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        cancel.tap()

        XCTAssertTrue(app.staticTexts["Milk"].exists)
    }

    func testDeleteFromEditSheet() {
        launch()
        addCatalogItem("Milk")

        openEditSheet(for: "Milk")
        app.buttons["item-form-delete-button"].tap()
        let confirm = app.buttons["form-delete-confirm-button"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(
            app.staticTexts["Your list is empty"].waitForExistence(timeout: 3),
            "List should be empty after deleting the only item"
        )
    }

    // MARK: - Catalog

    func testSaveCustomItemToCatalog() {
        launch()
        addCustomItem("Sourdough", quantity: "1", unit: "loaf", saveToCatalog: true)
        XCTAssertTrue(app.staticTexts["Sourdough"].exists)

        relaunch()

        XCTAssertTrue(app.staticTexts["Sourdough"].waitForExistence(timeout: 5))

        openCatalogPicker()
        catalogRow(name: "Sourdough", label: "Sourdough, already added")
    }

    func testCatalogSearchFiltersEntries() {
        launch()
        openCatalogPicker()
        catalogRow(name: "tof", label: "Tofu")
        XCTAssertFalse(button(withLabel: "Milk").exists)
    }

    // MARK: - Category reorder

    func testCategoryReorderPersists() {
        launch()
        addCatalogItem("Asparagus")
        addCatalogItem("Apples")
        addCatalogItem("Milk")

        app.buttons["edit-categories-button"].tap()
        let vegetables = categoryRow("Fresh vegetables")
        let fruits = categoryRow("Fresh fruits")
        XCTAssertTrue(vegetables.waitForExistence(timeout: 5), "Category edit row for Fresh vegetables should be visible")
        XCTAssertTrue(fruits.exists)

        // Drag the leading row's reorder handle onto the next row.
        let handle = vegetables.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        let target = fruits.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        handle.press(forDuration: 1.0, thenDragTo: target)

        waitUntil(5) {
            let movedVegetables = categoryRow("Fresh vegetables")
            let movedFruits = categoryRow("Fresh fruits")
            return movedFruits.exists && movedVegetables.exists
                && movedFruits.frame.minY < movedVegetables.frame.minY
        }
        XCTAssertLessThan(categoryRow("Fresh fruits").frame.minY, categoryRow("Fresh vegetables").frame.minY,
                          "Fresh fruits should move above Fresh vegetables in the edit list")

        app.buttons["done-categories-button"].tap()

        let fruitsHeader = staticText(withLabel: "Fresh fruits (1)")
        XCTAssertTrue(fruitsHeader.waitForExistence(timeout: 5))
        let vegetablesHeader = staticText(withLabel: "Fresh vegetables (1)")
        XCTAssertTrue(vegetablesHeader.exists)
        XCTAssertLessThan(fruitsHeader.frame.minY, vegetablesHeader.frame.minY)

        relaunch()

        let reopenedFruits = staticText(withLabel: "Fresh fruits (1)")
        XCTAssertTrue(reopenedFruits.waitForExistence(timeout: 5))
        let reopenedVegetables = staticText(withLabel: "Fresh vegetables (1)")
        XCTAssertTrue(reopenedVegetables.exists)
        XCTAssertLessThan(reopenedFruits.frame.minY, reopenedVegetables.frame.minY)
    }

    /// Reveals the trailing swipe actions (Complete / Delete) for a row.
    /// A press-and-drag over the row's leading area (starting on the
    /// completion toggle) is recognized as the row's swipe gesture; a long
    /// drag from the row's trailing edge misfires and toggles completion.
    private func revealTrailingActions(onItem name: String) {
        let marker = button(withLabel: "Mark \(name) as completed")
        XCTAssertTrue(marker.waitForExistence(timeout: 5), "Row for \(name) should be visible")
        marker.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            .press(forDuration: 0.5, thenDragTo: marker.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)))
    }

    private func switchIsOn(_ element: XCUIElement) -> Bool {
        if let value = element.value as? String { return value == "1" }
        if let value = element.value as? NSNumber { return value.intValue == 1 }
        return false
    }

    // MARK: - Accessibility

    func testDynamicTypeAccessibilitySize() {
        launch(resetDatabase: true, typeSize: "accessibility1")
        addCatalogItem("Milk", quantity: "2", unit: "liters", note: "whole milk, keep refrigerated")

        XCTAssertTrue(app.staticTexts["Milk"].exists)
        XCTAssertTrue(staticText(withLabel: "Dairy (1)").exists)
        XCTAssertTrue(button(withLabel: "Mark Milk as completed").exists)
    }

    func testVoiceOverLabels() {
        launch()
        addCatalogItem("Milk")

        XCTAssertTrue(button(withLabel: "Mark Milk as completed").exists)
        button(withLabel: "Mark Milk as completed").tap()
        let restore = showCompletedItem(labeled: "Mark Milk as needed")
        XCTAssertTrue(restore.exists)
    }

    // MARK: - D3 templates

    /// Taps the templates menu button, trying the accessibility identifier
    /// first and falling back to the "Templates" label if the identifier
    /// does not propagate through the Menu.
    private func openTemplatesMenu() {
        let byID = app.buttons["templates-menu-button"]
        let menuButton = byID.waitForExistence(timeout: 5) ? byID : app.buttons["Templates"].firstMatch
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Templates menu button should be visible")
        menuButton.tap()
    }

    /// Returns a menu item by identifier, falling back to its label.
    private func menuButton(_ identifier: String, _ label: String) -> XCUIElement {
        let byID = app.buttons[identifier]
        if byID.waitForExistence(timeout: 5) { return byID }
        let byLabel = app.buttons[label].firstMatch
        XCTAssertTrue(byLabel.waitForExistence(timeout: 5), "Menu item '\(label)' should be visible")
        return byLabel
    }

    private func waitUntil(timeout: TimeInterval = 10, description: String, _ condition: () -> Bool) {
        var remaining = timeout
        let poll: TimeInterval = 0.2
        while !condition() {
            guard remaining > 0 else {
                XCTFail("\(description): condition not met after \(timeout)s")
                return
            }
            Thread.sleep(forTimeInterval: poll)
            remaining -= poll
        }
    }

    private func identifiedLabel(_ identifier: String) -> String {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", identifier))
            .firstMatch.label
    }

    private func saveTemplate(named name: String) {
        openTemplatesMenu()
        menuButton("templates-menu-save-button", "Save as template").tap()
        let sheet = app.staticTexts["Save as template"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Save template sheet should be visible")
        app.textFields["template-name-field"].tap()
        app.typeText(name)
        app.buttons["save-template-save-button"].tap()
        XCTAssertTrue(app.buttons["add-item-button"].waitForExistence(timeout: 5), "List should be visible")
    }

    func testTemplatesMenuEmptyShowsNoTemplates() {
        launch()
        openTemplatesMenu()

        XCTAssertTrue(app.descendants(matching: .any)["templates-menu-empty"].waitForExistence(timeout: 5))
        XCTAssertTrue(menuButton("templates-menu-save-button", "Save as template").exists)
        XCTAssertTrue(menuButton("templates-menu-manage-button", "Manage templates").exists)
    }

    func testSaveTemplateFromToolbar() {
        launch()
        addCatalogItem("Milk", quantity: "2", unit: "liters", note: "whole")

        saveTemplate(named: "Weekly")

        XCTAssertTrue(app.staticTexts["Milk"].exists)
        openTemplatesMenu()
        menuButton("templates-menu-manage-button", "Manage templates").tap()
        XCTAssertTrue(app.descendants(matching: .any)["template-row-Weekly"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 item"].exists)
        app.buttons["manage-templates-done-button"].tap()
        XCTAssertTrue(app.buttons["add-item-button"].waitForExistence(timeout: 5), "List should be visible")
    }

    func testSaveTemplateUnavailableWhenListEmpty() {
        launch()
        openTemplatesMenu()
        menuButton("templates-menu-save-button", "Save as template").tap()

        XCTAssertTrue(app.staticTexts["Add items to your list before saving a template."].waitForExistence(timeout: 5))
        app.buttons["save-template-cancel-button"].tap()
        XCTAssertTrue(app.buttons["add-item-button"].waitForExistence(timeout: 5), "List should be visible")
    }

    func testDuplicateTemplateNameIsRejectedInSheet() {
        launch()
        addCatalogItem("Milk")
        saveTemplate(named: "Weekly")

        openTemplatesMenu()
        menuButton("templates-menu-save-button", "Save as template").tap()
        app.textFields["template-name-field"].tap()
        app.typeText("weekly")

        XCTAssertTrue(app.staticTexts["A template with this name already exists."].exists)
        XCTAssertFalse(app.buttons["save-template-save-button"].isEnabled)
        app.buttons["save-template-cancel-button"].tap()
    }

    func testApplyTemplateRestoresDeletedItems() {
        launch()
        addCatalogItem("Milk", quantity: "2", unit: "liters", note: "whole")
        addCatalogItem("Apples")
        saveTemplate(named: "Weekly")

        openDeleteDialog(forItem: "Milk")
        app.alerts.firstMatch.buttons["Delete"].firstMatch.tap()
        openDeleteDialog(forItem: "Apples")
        app.alerts.firstMatch.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Your list is empty"].exists)

        openTemplatesMenu()
        app.buttons["Weekly"].firstMatch.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), "Apply confirmation should be visible")
        XCTAssertTrue(app.alerts.firstMatch.staticTexts["Adds or reopens 2 items from Weekly."].exists)
        app.alerts.firstMatch.buttons["Apply"].firstMatch.tap()

        let report = app.alerts.firstMatch
        XCTAssertTrue(report.waitForExistence(timeout: 5), "Apply report should be visible")
        XCTAssertTrue(report.staticTexts["Weekly applied"].exists)
        XCTAssertTrue(report.staticTexts["added 2."].exists)
        report.buttons["Done"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Milk"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Apples"].exists)
    }

    func testApplyTemplateNoChangesNeeded() {
        launch()
        addCatalogItem("Milk")
        saveTemplate(named: "Weekly")

        openTemplatesMenu()
        app.buttons["Weekly"].firstMatch.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), "Apply confirmation should be visible")
        app.alerts.firstMatch.buttons["Apply"].firstMatch.tap()

        let report = app.alerts.firstMatch
        XCTAssertTrue(report.staticTexts["No changes needed: items are already on the list."].waitForExistence(timeout: 5))
        report.buttons["Done"].firstMatch.tap()
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == 'Milk'")).count, 1)
    }

    func testRenameTemplate() {
        launch()
        addCatalogItem("Milk")
        saveTemplate(named: "Weekly")

        openTemplatesMenu()
        menuButton("templates-menu-manage-button", "Manage templates").tap()
        let rename = app.buttons["Rename"]
        XCTAssertTrue(rename.waitForExistence(timeout: 5), "Rename button should be visible")
        rename.tap()

        let nameField = app.textFields["rename-template-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Rename name field should be visible")
        nameField.tap()
        let backspace = app.keyboards.firstMatch.keys["delete"]
        guard backspace.waitForExistence(timeout: 5) else {
            let labels = app.keyboards.firstMatch.keys.allElementsBoundByIndex.compactMap { $0.label }
            XCTFail("Keyboard backspace key not available after focusing the name field; keys: \(labels)")
            return
        }
        // A cleared, focused SwiftUI TextField reports its placeholder as the AX value.
        let placeholder = "Template name"
        func cleared() -> Bool {
            let value = (nameField.value as? String) ?? ""
            return value.isEmpty || value == placeholder
        }
        waitUntil(timeout: 5, description: "Keyboard backspace key is hittable") {
            app.keyboards.firstMatch.keys["delete"].isHittable
        }
        var taps = 0
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline, !cleared() {
            // Re-query each pass and tap only when hittable: a stale element
            // reference or a key still settling can fail the AX
            // scroll-to-visible action that tap() performs.
            let key = app.keyboards.firstMatch.keys["delete"]
            guard key.isHittable else {
                Thread.sleep(forTimeInterval: 0.2)
                continue
            }
            key.tap()
            taps += 1
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertTrue(cleared(), "Name field should be cleared before validating the empty state (taps: \(taps), last value: \(nameField.value as? String ?? "nil"))")

        let renameButton = app.buttons["rename-template-rename-button"]
        waitUntil(description: "Rename button disabled for an empty name") {
            renameButton.exists && !renameButton.isEnabled
        }
        XCTAssertTrue(app.staticTexts["Name is required."].waitForExistence(timeout: 5))
        app.typeText("Bakery")
        waitUntil(description: "Rename button enabled for a valid name") {
            renameButton.exists && renameButton.isEnabled
        }
        renameButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["template-row-Bakery"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Weekly"].exists)
        app.buttons["manage-templates-done-button"].tap()
    }

    func testDeleteTemplateKeepsItems() {
        launch()
        addCatalogItem("Milk")
        saveTemplate(named: "Weekly")

        openTemplatesMenu()
        menuButton("templates-menu-manage-button", "Manage templates").tap()
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "Delete button should be visible")
        delete.tap()

        let confirmTitle = app.staticTexts["Delete Weekly?"]
        XCTAssertTrue(confirmTitle.waitForExistence(timeout: 5), "Delete confirmation should be visible")
        let confirm = app.buttons["delete-template-confirm-button"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Delete button in confirmation should be visible")
        confirm.tap()
        XCTAssertTrue(app.descendants(matching: .any)["manage-templates-empty"].waitForExistence(timeout: 5))

        app.buttons["manage-templates-done-button"].tap()
        XCTAssertTrue(app.staticTexts["Milk"].waitForExistence(timeout: 5))
    }

    // MARK: - D3 email export (DEBUG fakes)

    func testEmailListButtonDisabledWhenNothingNeeded() {
        launch(extraArguments: ["fakeEmailExport"])
        XCTAssertFalse(app.buttons["email-list-button"].firstMatch.isEnabled)
    }

    func testEmailExportFallsBackToShareSheet() {
        launch(extraArguments: ["fakeEmailExport"])
        addCatalogItem("Milk", quantity: "2", unit: "liters", note: "whole")

        app.buttons["email-list-button"].firstMatch.tap()

        XCTAssertTrue(app.descendants(matching: .any)["export-via-share-indicator"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["(none)"].exists)
        let body = identifiedLabel("export-body-text")
        XCTAssertEqual(body, "Dairy\n  Milk \u{2014} 2 liters \u{2014} whole")
        app.buttons["export-dismiss-button"].tap()
        XCTAssertTrue(app.buttons["add-item-button"].waitForExistence(timeout: 5), "List should be visible")
    }

    func testEmailExportUsesMailWhenConfigured() {
        launch(extraArguments: ["fakeEmailExport", "fakeMailConfigured"])
        addCatalogItem("Milk")

        app.buttons["email-list-button"].firstMatch.tap()

        XCTAssertTrue(app.descendants(matching: .any)["export-via-mail-indicator"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["My List"].exists)
        let body = identifiedLabel("export-body-text")
        XCTAssertEqual(body, "Dairy\n  Milk")
        app.buttons["export-dismiss-button"].tap()
    }

    func testDynamicTypeTemplateAndExportSurfaces() {
        launch(typeSize: "accessibility1", extraArguments: ["fakeEmailExport"])
        addCatalogItem("Milk", quantity: "2", unit: "liters", note: "whole")

        openTemplatesMenu()
        menuButton("templates-menu-save-button", "Save as template").tap()
        let nameField = app.textFields["template-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Template name field should be visible at large text")
        nameField.tap()
        app.typeText("Weekly")
        app.buttons["save-template-save-button"].tap()

        app.buttons["email-list-button"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["export-body-text"].waitForExistence(timeout: 5))
    }
}
