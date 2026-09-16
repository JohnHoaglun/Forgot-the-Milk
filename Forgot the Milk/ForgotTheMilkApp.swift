import Foundation
import SwiftData
import SwiftUI

@main
struct ForgotTheMilkApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try Self.makeContainer()
        } catch {
            fatalError("Failed to create the model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }

    private static func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration()
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

    var body: some View {
        ListView()
            .modelContainer(container)
    }
}
