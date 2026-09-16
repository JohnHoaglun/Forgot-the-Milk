import Foundation
import SwiftData

@testable import Forgot_the_Milk

// The ObjC runtime exposes a `Category` class that collides with the model name;
// this alias pins unqualified `Category` in test files to the app's model.
typealias Category = Forgot_the_Milk.Category

enum TestStore {
    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try makeContainer(configuration: configuration)
    }

    static func makeFileContainer(directory: URL, cleanExisting: Bool = true) throws -> ModelContainer {
        if cleanExisting {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent("store.sqlite\(suffix)"))
            }
        }
        let configuration = ModelConfiguration(url: directory.appendingPathComponent("store.sqlite"))
        return try makeContainer(configuration: configuration)
    }

    static func makeContext(_ container: ModelContainer) -> ModelContext {
        container.mainContext
    }

    private static func makeContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: HouseholdList.self, Category.self, CatalogItem.self, ListItem.self, Template.self,
            configurations: configuration
        )
    }
}
