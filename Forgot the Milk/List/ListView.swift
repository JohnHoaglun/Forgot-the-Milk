import Foundation
import SwiftData
import SwiftUI

struct ListView: View {
    let export: EmailExport

    @Query private var lists: [HouseholdList]
    @Query private var categories: [Category]
    @Query private var items: [ListItem]
    @Query private var allTemplates: [Template]

    @Environment(\.modelContext) private var modelContext
    @AppStorage("list.completedSection.expanded") private var completedExpanded = false

    @State private var deleteCandidate: ListItem?
    @State private var isConfirmingDelete = false
    @State private var isConfirmingClear = false
    @State private var editTarget: ListItem?
    @State private var isEditingCategories = false
    @State private var isShowingSaveTemplateSheet = false
    @State private var isShowingManageTemplatesSheet = false
    @State private var applyCandidate: Template?
    @State private var isConfirmingApply = false
    @State private var applyReport: ApplyReport?

    private var list: HouseholdList? {
        lists.first
    }

    private var grouped: GroupedList {
        guard let list else {
            return GroupedList(sections: [], completed: [])
        }
        return ListGrouping.group(categories: categories, items: items, categoryOrder: list.categoryOrder)
    }

    private var isListEmpty: Bool {
        grouped.sections.isEmpty && grouped.completed.isEmpty
    }

    private var templates: [Template] {
        guard let list else { return [] }
        return allTemplates
            .filter { $0.listID == list.id }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Forgot the Milk")
                .toolbar { toolbarContent }
        }
        .sheet(item: $editTarget) { item in
            ItemFormView(mode: .edit(item))
        }
        .sheet(isPresented: $isShowingSaveTemplateSheet) {
            if let list {
                SaveTemplateSheet(
                    listID: list.id,
                    hasNeededItems: grouped.totalNeeded > 0,
                    onSave: { name in
                        TemplateUseCases(context: modelContext).save(named: name, for: list.id) == .saved
                    },
                    onDone: { isShowingSaveTemplateSheet = false }
                )
            }
        }
        .sheet(isPresented: $isShowingManageTemplatesSheet) {
            if let list {
                ManageTemplatesSheet(listID: list.id)
            }
        }
        .alert(applyConfirmationTitle, isPresented: $isConfirmingApply) {
            Button("Apply") {
                performApply()
            }
            Button("Cancel", role: .cancel) {
                applyCandidate = nil
            }
        } message: {
            if let template = applyCandidate {
                Text("Adds or reopens \(template.entries.count) items from \(template.name).")
            }
        }
        .alert(applyReportTitle, isPresented: applyReportPresented) {
            Button("Done", role: .cancel) {}
        } message: {
            Text(applyReport?.message ?? "")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !isEditingCategories {
            ToolbarItem(placement: .topBarLeading) {
                Button("Edit") {
                    isEditingCategories = true
                }
                .accessibilityIdentifier("edit-categories-button")
                .accessibilityHint("Reorder the categories on this list")
            }
            ToolbarItem(placement: .topBarTrailing) {
                templatesMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    performExport()
                } label: {
                    Label("Email list", systemImage: "paperplane")
                        .accessibilityIdentifier("email-list-button")
                        .accessibilityHint("Emails or shares the items you still need")
                }
                .disabled(grouped.totalNeeded == 0)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CatalogPickerView()
                } label: {
                    Label("Add Item", systemImage: "plus")
                        .accessibilityIdentifier("add-item-button")
                }
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    isEditingCategories = false
                }
                .accessibilityIdentifier("done-categories-button")
            }
        }
    }

    private var templatesMenu: some View {
        Menu {
            if templates.isEmpty {
                Text("No templates")
                    .accessibilityIdentifier("templates-menu-empty")
            } else {
                ForEach(templates) { template in
                    Button {
                        applyCandidate = template
                        isConfirmingApply = true
                    } label: {
                        Label(template.name, systemImage: "checkmark")
                    }
                }
            }
            Divider()
            Button {
                isShowingSaveTemplateSheet = true
            } label: {
                Label("Save as template", systemImage: "plus")
            }
            .accessibilityIdentifier("templates-menu-save-button")
            Button {
                isShowingManageTemplatesSheet = true
            } label: {
                Label("Manage templates", systemImage: "ellipsis.circle")
            }
            .accessibilityIdentifier("templates-menu-manage-button")
        } label: {
            Label("Templates", systemImage: "rectangle.on.rectangle")
                .accessibilityIdentifier("templates-menu-button")
                .accessibilityHint("Save, apply, or manage item templates")
        }
    }

    private var applyConfirmationTitle: String {
        if let name = applyCandidate?.name {
            return "Apply \(name)?"
        }
        return "Apply template?"
    }

    private var applyReportTitle: String {
        applyReport?.title ?? "Template applied"
    }

    private var applyReportPresented: Binding<Bool> {
        Binding(
            get: { applyReport != nil },
            set: { if !$0 { applyReport = nil } }
        )
    }

    private struct ApplyReport {
        let title: String
        let message: String
    }

    private func performApply() {
        guard let list, let template = applyCandidate else { return }
        let report = TemplateUseCases(context: modelContext).apply(template, to: list.id)
        var changes: [String] = []
        if report.added > 0 { changes.append("added \(report.added)") }
        if report.reopened > 0 { changes.append("reopened \(report.reopened)") }
        let message = changes.isEmpty
            ? "No changes needed: items are already on the list."
            : changes.joined(separator: ", ") + "."
        applyCandidate = nil
        isConfirmingApply = false
        applyReport = ApplyReport(title: "\(template.name) applied", message: message)
    }

    private func performExport() {
        guard let list else { return }
        let body = ListExport.text(categories: categories, items: items, categoryOrder: list.categoryOrder)
        guard !body.isEmpty else { return }
        export.service.export(subject: list.title, body: body)
    }

    @ViewBuilder
    private var content: some View {
        if list == nil {
            Text("No list found")
                .foregroundStyle(.secondary)
        } else if isEditingCategories {
            categoryEditList
        } else {
            listContent
        }
    }

    private var listContent: some View {
        List {
            ForEach(grouped.sections) { section in
                Section {
                    ForEach(section.items) { item in
                        neededRow(for: item)
                    }
                } header: {
                    Text("\(section.name) (\(section.neededCount))")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                        .accessibilityIdentifier("category-header-\(section.categoryID)")
                }
            }

            if isListEmpty {
                ContentUnavailableView(
                    "Your list is empty",
                    systemImage: "cart",
                    description: Text("Items will appear here once they are added.")
                )
                NavigationLink {
                    CatalogPickerView()
                } label: {
                    Text("Add your first item")
                        .accessibilityIdentifier("empty-state-add-button")
                }
            }

            if !grouped.completed.isEmpty {
                completedSection
            }
        }
        .accessibilityIdentifier("list-view")
        .alert(deleteDialogMessage, isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                confirmDelete()
            }
            Button("Cancel", role: .cancel) {
                deleteCandidate = nil
            }
        }
        .alert("Clear \(grouped.completed.count) completed items?", isPresented: $isConfirmingClear) {
            Button("Clear", role: .destructive) {
                if let list {
                    mutate { $0.clearCompleted(listID: list.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var categoryEditList: some View {
        List {
            ForEach(orderedCategories) { category in
                categoryEditRow(for: category)
            }
            .onMove { source, destination in
                guard let list else { return }
                var order = orderedCategories.map(\.id)
                order.move(fromOffsets: source, toOffset: destination)
                ListUseCases(context: modelContext).setCategoryOrder(order, for: list.id)
            }
        }
        .environment(\.editMode, .constant(.active))
        .accessibilityIdentifier("category-edit-list")
        .accessibilityLabel("Reorder categories")
    }

    private func categoryEditRow(for category: Category) -> some View {
        HStack {
            Text(category.name)
            Spacer()
            Text("\(neededCount(in: category.id))")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.name)
        .accessibilityIdentifier("category-row-\(category.name)")
        .accessibilityActions {
            Button("Move up") {
                moveCategory(category, up: true)
            }
            Button("Move down") {
                moveCategory(category, up: false)
            }
        }
    }

    private func moveCategory(_ category: Category, up: Bool) {
        guard let list else { return }
        var order = orderedCategories.map(\.id)
        guard let from = order.firstIndex(of: category.id) else { return }
        if up {
            guard from > 0 else { return }
            order.move(fromOffsets: IndexSet(integer: from), toOffset: from - 1)
        } else {
            guard from < order.count - 1 else { return }
            order.move(fromOffsets: IndexSet(integer: from), toOffset: from + 2)
        }
        ListUseCases(context: modelContext).setCategoryOrder(order, for: list.id)
    }

    private var orderedCategories: [Category] {
        guard let list else { return [] }
        return ListGrouping.orderedCategories(categories, order: list.categoryOrder)
    }

    private func neededCount(in categoryID: UUID) -> Int {
        guard let list else { return 0 }
        return items.filter { $0.listID == list.id && $0.categoryID == categoryID && $0.state == .needed }.count
    }

    private func neededRow(for item: ListItem) -> some View {
        ListRow(item: item, onEdit: {
            editTarget = item
        }) {
            mutate { $0.complete(item) }
        }
        .swipeActions(edge: .trailing) {
            Button {
                mutate { $0.complete(item) }
            } label: {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(.green)

            Button(role: .destructive) {
                pendingDelete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func completedRow(for item: ListItem) -> some View {
        ListRow(item: item, onEdit: {
            editTarget = item
        }) {
            mutate { $0.restore(item) }
        }
        .swipeActions(edge: .leading) {
            Button {
                mutate { $0.restore(item) }
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(.blue)
        }
    }

    private var completedSection: some View {
        Section {
            if completedExpanded {
                ForEach(grouped.completed) { item in
                    completedRow(for: item)
                }
            }
        } header: {
            Button {
                completedExpanded.toggle()
            } label: {
                HStack {
                    Text("Completed (\(grouped.completed.count))")
                        .font(.title3)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(completedExpanded ? 0 : -90))
                }
                .foregroundStyle(.secondary)
                .textCase(nil)
            }
            .accessibilityLabel("Completed items, \(grouped.completed.count)")
            .accessibilityHint(completedExpanded ? "Collapse completed items" : "Expand completed items")
            .accessibilityIdentifier("completed-section-toggle")
        } footer: {
            if grouped.completed.count > 0 {
                Button(role: .destructive) {
                    isConfirmingClear = true
                } label: {
                    Text("Clear completed")
                }
                .accessibilityIdentifier("clear-completed-button")
                .accessibilityHint("Permanently removes all completed items")
            }
        }
    }

    private var deleteDialogMessage: String {
        if let name = deleteCandidate?.name {
            return "Delete \(name)?"
        }
        return "Delete item?"
    }

    private func pendingDelete(_ item: ListItem) {
        deleteCandidate = item
        isConfirmingDelete = true
    }

    private func confirmDelete() {
        if let item = deleteCandidate {
            mutate { $0.delete(item) }
        }
        deleteCandidate = nil
    }

    private func mutate(_ body: (ItemUseCases) -> Void) {
        let useCases = ItemUseCases(context: modelContext)
        body(useCases)
    }
}
