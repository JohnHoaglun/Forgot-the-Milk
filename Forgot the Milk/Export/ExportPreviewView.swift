#if DEBUG
import SwiftUI

struct ExportPreviewView: View {
    let pending: ExportDebugState.Pending
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(pending.viaMail ? "Mail (deterministic fake)" : "Share sheet (deterministic fake)")
                        .accessibilityIdentifier(pending.viaMail ? "export-via-mail-indicator" : "export-via-share-indicator")
                }
                Section("Subject") {
                    Text(pending.subject.isEmpty ? "(none)" : pending.subject)
                        .accessibilityIdentifier("export-subject-text")
                }
                Section("Body") {
                    Text(pending.body)
                        .accessibilityIdentifier("export-body-text")
                }
            }
            .navigationTitle("Export preview")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .accessibilityIdentifier("export-dismiss-button")
                }
            }
        }
        .accessibilityIdentifier("export-preview-sheet")
    }
}

struct DebugExportSheetHost: View {
    let state: ExportDebugState

    var body: some View {
        @Bindable var state = state
        return EmptyView()
            .sheet(item: $state.pending) { pending in
                ExportPreviewView(pending: pending) {
                    state.pending = nil
                }
            }
    }
}
#endif
