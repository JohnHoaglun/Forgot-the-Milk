import Foundation
import SwiftData
import SwiftUI

struct SaveTemplateSheet: View {
    let listID: UUID
    let hasNeededItems: Bool
    let onSave: (String) -> Bool
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var allTemplates: [Template]
    @State private var name = ""

    private var existing: [Template] {
        allTemplates.filter { $0.listID == listID }
    }

    private var issues: [TemplateNameValidation.Issue] {
        TemplateNameValidation.issues(for: name, existing: existing)
    }

    var body: some View {
        NavigationStack {
            Form {
                if hasNeededItems {
                    Section("Name") {
                        TextField("Template name", text: $name)
                            .accessibilityIdentifier("template-name-field")
                    }
                    if !issues.isEmpty {
                        Section {
                            ForEach(issues, id: \.self) { issue in
                                Text(message(for: issue))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                } else {
                    Section {
                        Text("Add items to your list before saving a template.")
                            .accessibilityIdentifier("save-template-unavailable-text")
                    }
                }
            }
            .navigationTitle("Save as template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDone)
                        .accessibilityIdentifier("save-template-cancel-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if onSave(name) {
                            onDone()
                        }
                    }
                    .disabled(!hasNeededItems || !issues.isEmpty)
                    .accessibilityIdentifier("save-template-save-button")
                }
            }
        }
        .accessibilityIdentifier("save-template-sheet")
    }

    private func message(for issue: TemplateNameValidation.Issue) -> String {
        switch issue {
        case .nameRequired: return "Name is required."
        case .nameTooLong: return "Name must be \(TemplateNameValidation.limit) characters or fewer."
        case .nameNotUnique: return "A template with this name already exists."
        }
    }
}

struct ManageTemplatesSheet: View {
    let listID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTemplates: [Template]

    @State private var renameCandidate: Template?
    @State private var renameText = ""
    @State private var deleteCandidate: Template?

    private var templates: [Template] {
        allTemplates
            .filter { $0.listID == listID }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var renameIssues: [TemplateNameValidation.Issue] {
        guard let candidate = renameCandidate else { return [] }
        let others = templates.filter { $0.id != candidate.id }
        return TemplateNameValidation.issues(for: renameText, existing: others)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let candidate = renameCandidate {
                    renameSection(for: candidate)
                } else if let candidate = deleteCandidate {
                    deleteSection(for: candidate)
                } else {
                    listSection
                }
            }
            .navigationTitle("Templates")
            .toolbar {
                if renameCandidate == nil && deleteCandidate == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                        .accessibilityIdentifier("manage-templates-done-button")
                    }
                }
                if renameCandidate != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            renameCandidate = nil
                            renameText = ""
                        }
                        .accessibilityIdentifier("rename-template-cancel-button")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Rename") {
                            performRename()
                        }
                        .disabled(!renameIssues.isEmpty)
                        .accessibilityIdentifier("rename-template-rename-button")
                    }
                }
                if deleteCandidate != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            deleteCandidate = nil
                        }
                        .accessibilityIdentifier("delete-template-cancel-button")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Delete", role: .destructive) {
                            confirmDelete()
                        }
                        .accessibilityIdentifier("delete-template-confirm-button")
                    }
                }
            }
        }
    }

    private var listSection: some View {
        Group {
            if templates.isEmpty {
                ContentUnavailableView(
                    "No templates",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Save a template from the list toolbar to reuse a set of items.")
                )
                .accessibilityIdentifier("manage-templates-empty")
            } else {
                List {
                    ForEach(templates) { template in
                        templateRow(template)
                    }
                }
                .accessibilityIdentifier("manage-templates-list")
            }
        }
    }

    private func templateRow(_ template: Template) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(template.name)
                Text(entryCountText(template.entries.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Rename") {
                renameText = template.name
                renameCandidate = template
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("template-rename-button-\(template.name)")
            Button("Delete") {
                deleteCandidate = template
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("template-delete-button-\(template.name)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("template-row-\(template.name)")
    }

    private func renameSection(for candidate: Template) -> some View {
        Form {
            Section("Name") {
                TextField("Template name", text: $renameText)
                    .accessibilityIdentifier("rename-template-name-field")
            }
            if !renameIssues.isEmpty {
                Section {
                    ForEach(renameIssues, id: \.self) { issue in
                        Text(message(for: issue))
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .accessibilityIdentifier("rename-template-section")
    }

    private func deleteSection(for candidate: Template) -> some View {
        VStack(spacing: 16) {
            Text("Delete \(candidate.name)?")
                .font(.title3.bold())
                .accessibilityIdentifier("delete-template-title")
            Text("Items already added from this template are not affected.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("delete-template-message")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("delete-template-section")
    }

    private func entryCountText(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(count) items"
    }

    private func performRename() {
        guard let candidate = renameCandidate else { return }
        if TemplateUseCases(context: modelContext).rename(candidate, to: renameText) {
            renameCandidate = nil
        }
    }

    private func confirmDelete() {
        guard let candidate = deleteCandidate else { return }
        TemplateUseCases(context: modelContext).delete(candidate)
        deleteCandidate = nil
    }

    private func message(for issue: TemplateNameValidation.Issue) -> String {
        switch issue {
        case .nameRequired: return "Name is required."
        case .nameTooLong: return "Name must be \(TemplateNameValidation.limit) characters or fewer."
        case .nameNotUnique: return "A template with this name already exists."
        }
    }
}
