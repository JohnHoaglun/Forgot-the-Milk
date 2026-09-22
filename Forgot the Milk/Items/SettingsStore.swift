import Foundation

enum UnitSystem: Int, Codable, CaseIterable {
    case imperial
    case metric
}

struct SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var unitSystem: UnitSystem {
        get {
            UnitSystem(rawValue: defaults.integer(forKey: Self.unitSystemKey)) ?? .imperial
        }
        set {
            defaults.set(newValue.rawValue, forKey: Self.unitSystemKey)
        }
    }

    var activeListID: UUID? {
        get {
            guard let raw = defaults.string(forKey: Self.activeListIDKey) else {
                return nil
            }
            return UUID(uuidString: raw)
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: Self.activeListIDKey)
                return
            }
            defaults.set(newValue.uuidString, forKey: Self.activeListIDKey)
        }
    }

    private static let unitSystemKey = "settings.unitSystem"
    private static let activeListIDKey = "settings.activeListID"
}
