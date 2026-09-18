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

    private static let unitSystemKey = "settings.unitSystem"
}
