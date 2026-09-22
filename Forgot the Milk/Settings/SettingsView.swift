import SwiftUI

struct SettingsView: View {
    let sync: SyncCoordinator
    var settings: SettingsStore = SettingsStore()

    @State private var isConfirmingStopSharing = false

    private var isICloudAvailable: Bool {
        sync.authStatus == .authorized
    }

    var body: some View {
        List {
            accountSection
            sharingSection
            unitsSection
            aboutSection
        }
        .navigationTitle("Settings")
        .alert("Stop sharing?", isPresented: $isConfirmingStopSharing) {
            Button("Stop Sharing", role: .destructive) {
                Task { await sync.stopSharing() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your list stays on this device. Collaborators lose access to the shared list.")
        }
    }

    private var accountSection: some View {
        Section("iCloud") {
            LabeledContent("Account", value: accountStatusText)
                .accessibilityIdentifier("settings-account-status")
            LabeledContent("Sync", value: syncStatusText)
                .accessibilityIdentifier("settings-sync-status")
            if let lastSyncedAt = sync.state.lastSyncedAt {
                LabeledContent("Last synced", value: lastSyncedAt.formatted(date: .abbreviated, time: .shortened))
                    .accessibilityIdentifier("settings-last-synced")
            }
            if sync.state.pendingCount > 0 {
                LabeledContent("Pending changes", value: "\(sync.state.pendingCount)")
                    .accessibilityIdentifier("settings-pending-count")
            }
            if case .error = sync.state.status {
                Button("Retry sync") {
                    sync.retry()
                }
                .accessibilityIdentifier("settings-retry-button")
                .accessibilityHint("Attempts to sync again")
            }
            if case .offline = sync.state.status {
                Text("You're offline. Your list still works and syncs when you're back online.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings-offline-note")
            }
        }
    }

    private var sharingSection: some View {
        Section("Sharing") {
            if let info = sync.shareInfo {
                ForEach(info.participants, id: \.self) { participant in
                    LabeledContent(participantDisplayName(participant), value: participantDetails(participant))
                }
                if info.isOwner {
                    Button("Stop Sharing", role: .destructive) {
                        isConfirmingStopSharing = true
                    }
                    .accessibilityIdentifier("settings-stop-sharing-button")
                    .accessibilityHint("Removes collaborator access and keeps your list on this device")
                    .disabled(!isICloudAvailable)
                }
            } else {
                Text("This list isn't shared yet.")
                    .accessibilityIdentifier("settings-not-shared")
            }
            Button("Share List") {
                Task { await sync.startSharing() }
            }
            .accessibilityIdentifier("settings-share-list-button")
            .accessibilityHint("Creates or reuses the share and opens the share sheet")
            .disabled(!isICloudAvailable)
            if !isICloudAvailable {
                Text("Sign in to iCloud on this device to share your list. Sharing works again once you're signed in.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings-sharing-recovery-hint")
            }
        }
    }

    private var unitsSection: some View {
        Section("Units") {
            Picker(
                "Default unit system",
                selection: Binding(
                    get: { settings.unitSystem },
                    set: { newValue in
                        var updated = settings
                        updated.unitSystem = newValue
                    }
                )
            ) {
                ForEach(UnitSystem.allCases, id: \.self) { system in
                    Text(unitSystemName(system)).tag(system)
                }
            }
            .accessibilityIdentifier("settings-unit-system-picker")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Text("Forgot the Milk stores your lists on this device and uses only your iCloud account to share them. There is no custom backend, analytics, or tracking.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings-about-text")
        }
    }

    private var accountStatusText: String {
        switch sync.authStatus {
        case nil:
            return "Checking…"
        case .authorized:
            return "Signed in"
        case .notDetermined:
            return "Not set up"
        case .restricted:
            return "Restricted"
        case .unavailable:
            return "Unavailable"
        case .couldNotDetermine:
            return "Unknown"
        }
    }

    private var syncStatusText: String {
        switch sync.state.status {
        case .idle:
            return "Up to date"
        case .syncing:
            return "Syncing…"
        case .offline:
            return "Offline"
        case .error(let kind):
            return errorText(kind)
        }
    }

    private func errorText(_ kind: SyncErrorKind) -> String {
        switch kind {
        case .authentication:
            return "iCloud sign-in needed"
        case .permissionDenied:
            return "Permission denied"
        case .quota:
            return "iCloud storage is full"
        case .network:
            return "Network problem"
        case .partialFailure:
            return "Some changes didn't sync"
        case .conflict:
            return "Sync conflict"
        case .unknown:
            return "Sync problem"
        }
    }

    private func unitSystemName(_ system: UnitSystem) -> String {
        switch system {
        case .imperial:
            return "Imperial"
        case .metric:
            return "Metric"
        }
    }

    private func participantDisplayName(_ participant: ShareParticipant) -> String {
        participant.isOwner ? "\(participant.name) (Owner)" : participant.name
    }

    private func participantDetails(_ participant: ShareParticipant) -> String {
        var parts: [String] = [participant.permission == .readWrite ? "Can edit" : "Read only"]
        if participant.status == .invited {
            parts.append("Invited")
        }
        return parts.joined(separator: " · ")
    }
}
