import Foundation
import CloseUpKit

/// The user's language choice: follow the system, or pin a specific language.
enum LanguagePreference: Hashable {
    case system
    case specific(SupportedLanguage)

    private static let key = "appLanguage"

    static func load(from defaults: UserDefaults = .standard) -> LanguagePreference {
        guard let raw = defaults.string(forKey: key), raw != "system" else { return .system }
        return SupportedLanguage(rawValue: raw).map(LanguagePreference.specific) ?? .system
    }

    func save(to defaults: UserDefaults = .standard) {
        switch self {
        case .system: defaults.set("system", forKey: Self.key)
        case .specific(let language): defaults.set(language.rawValue, forKey: Self.key)
        }
    }

    /// The concrete language to render, resolving `.system` against the OS.
    var effectiveLanguage: SupportedLanguage {
        switch self {
        case .system: SupportedLanguage.resolve(preferredLanguages: Locale.preferredLanguages)
        case .specific(let language): language
        }
    }
}
