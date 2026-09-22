import Foundation
import SwiftData
import SwiftUI

@main
struct ForgotTheMilkApp: App {
    private let container: ModelContainer
    private let export: EmailExport
    private let sync: SyncCoordinator

    init() {
        do {
            container = try Self.makeContainer()
        } catch {
            fatalError("Failed to create the model container: \(error)")
        }
        export = EmailExportFactory.make()
        let dependencies = Self.makeSyncDependencies()
        sync = SyncCoordinator(
            context: container.mainContext,
            client: dependencies.client,
            connectivity: SystemConnectivityMonitor(),
            shareSheet: dependencies.shareSheet
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container, export: export, sync: sync)
        }
    }

    private static func makeSyncDependencies() -> (client: any CloudKitClient, shareSheet: any ShareSheetPresenting) {
        #if DEBUG
        // DEBUG-only launch argument seam: "fakeCloudKit" routes sync to an
        // in-memory fake client for deterministic UI testing, and
        // "fakeCloudKitUnavailable" additionally reports iCloud as
        // unavailable. The system share sheet is replaced with a no-op
        // presenter in that mode.
        if CommandLine.arguments.contains("fakeCloudKit") {
            let client = FakeCloudKitClient(deviceID: "app")
            if CommandLine.arguments.contains("fakeCloudKitUnavailable") {
                client.authentication = .unavailable
            }
            return (client, NoopShareSheetPresenter())
        }
        #endif
        return (RealCloudKitClient(), SystemShareSheetPresenter())
    }

    private static let databaseName = "ForgotTheMilk.sqlite"

    private static var databaseURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent(databaseName)
    }

    private static func makeContainer() throws -> ModelContainer {
        #if DEBUG
        // DEBUG-only launch arguments are deterministic UI-test seams:
        // "resetDatabaseOnLaunch" clears the store and app-owned defaults,
        // "contentSizeCategory=<size>" forces a Dynamic Type size.
        if CommandLine.arguments.contains("resetDatabaseOnLaunch") {
            let fileManager = FileManager.default
            for suffix in ["", "-wal", "-shm"] {
                try? fileManager.removeItem(at: URL(fileURLWithPath: databaseURL.path + suffix))
            }
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        }
        #endif

        let configuration = ModelConfiguration(url: databaseURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: HouseholdList.self, Category.self, CatalogItem.self, ListItem.self, Template.self,
            configurations: configuration
        )
        try AppSeeding.seedIfNeeded(context: container.mainContext)
        return container
    }
}

struct RootView: View {
    let container: ModelContainer
    let export: EmailExport
    let sync: SyncCoordinator

    @Environment(\.scenePhase) private var scenePhase

    #if DEBUG
    private var debugTypeSize: DynamicTypeSize? {
        guard let argument = CommandLine.arguments.first(where: { $0.hasPrefix("contentSizeCategory=") }) else {
            return nil
        }
        let value = String(argument.dropFirst("contentSizeCategory=".count))
        switch value {
        case "xSmall": return .xSmall
        case "small": return .small
        case "medium": return .medium
        case "large": return .large
        case "xLarge": return .xLarge
        case "xxLarge": return .xxLarge
        case "xxxLarge": return .xxxLarge
        case "accessibilityMedium", "accessibility1": return .accessibility1
        case "accessibilityLarge", "accessibility2": return .accessibility2
        case "accessibilityXLarge", "accessibility3": return .accessibility3
        case "accessibilityXXLarge", "accessibility4": return .accessibility4
        case "accessibilityXXXLarge", "accessibility5": return .accessibility5
        default: return nil
        }
    }
    #endif

    var body: some View {
        let base = root
            .modelContainer(container)
            .task {
                sync.start()
            }
            .onOpenURL { url in
                Task {
                    await sync.acceptShareURL(url)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    sync.foreground()
                }
            }
        #if DEBUG
        if let debugState = export.debugState {
            base.overlay { DebugExportSheetHost(state: debugState) }
        } else {
            base
        }
        #else
        base
        #endif
    }

    @ViewBuilder
    private var root: some View {
        #if DEBUG
        if let size = debugTypeSize {
            ListView(export: export, sync: sync).dynamicTypeSize(size)
        } else {
            ListView(export: export, sync: sync)
        }
        #else
        ListView(export: export, sync: sync)
        #endif
    }
}
