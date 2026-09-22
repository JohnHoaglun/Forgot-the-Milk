import Foundation

struct SyncJournal: Codable, Equatable {
    var baselines: [UUID: Date] = [:]
    var localVersions: [UUID: Date] = [:]
    var pendingDeletions: [UUID: SyncEntityType] = [:]

    private static let storageKey = "com.hoaglun.forgotthemilk.syncJournal"

    static func load(from defaults: UserDefaults) -> SyncJournal {
        guard let data = defaults.data(forKey: storageKey) else {
            return SyncJournal()
        }
        return (try? JSONDecoder().decode(SyncJournal.self, from: data)) ?? SyncJournal()
    }

    func persist(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
