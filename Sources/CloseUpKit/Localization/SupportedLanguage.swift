import Foundation

/// The languages CloseUp ships. Raw values are the locale identifiers used both
/// for `.lproj` resources and the SwiftUI `\.locale` environment.
public enum SupportedLanguage: String, CaseIterable, Sendable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case portuguese = "pt"
    case russian = "ru"

    public var id: String { rawValue }
    public var localeIdentifier: String { rawValue }

    /// Endonym, for the language picker.
    public var nativeName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .french: "Français"
        case .german: "Deutsch"
        case .spanish: "Español"
        case .portuguese: "Português"
        case .russian: "Русский"
        }
    }

    /// Best `.lproj` name for this language among a bundle's available
    /// localizations (e.g. a third-party package's resource bundle), or `nil`
    /// when the bundle doesn't ship it. Reuses `match(_:)`, so regional
    /// variants count: `.traditionalChinese` finds "zh-TW", `.portuguese`
    /// finds "pt-BR".
    public func preferredLocalization(from available: [String]) -> String? {
        if let exact = available.first(where: {
            $0.compare(rawValue, options: .caseInsensitive) == .orderedSame
        }) {
            return exact
        }
        return available.first { Self.match($0) == self }
    }

    /// Best supported language for an ordered list of preferred BCP-47 codes
    /// (e.g. `Locale.preferredLanguages`), falling back to English.
    public static func resolve(preferredLanguages: [String]) -> SupportedLanguage {
        for code in preferredLanguages {
            if let match = match(code) { return match }
        }
        return .english
    }

    static func match(_ code: String) -> SupportedLanguage? {
        let parts = code.lowercased().split(separator: "-").map(String.init)
        guard let language = parts.first else { return nil }

        // Exact identifier (e.g. "zh-Hans").
        if parts.count >= 2 {
            let languageScript = "\(parts[0])-\(parts[1])"
            if let match = allCases.first(where: { $0.rawValue.lowercased() == languageScript }) {
                return match
            }
        }

        // Chinese without an explicit script: infer from region.
        if language == "zh" {
            let traditionalRegions: Set<String> = ["tw", "hk", "mo", "hant"]
            let regionOrScript = parts.count >= 2 ? parts[1] : ""
            return traditionalRegions.contains(regionOrScript) ? .traditionalChinese : .simplifiedChinese
        }

        // Language-only (e.g. "ja", "fr-CA" → "fr").
        return allCases.first { $0.rawValue.lowercased() == language }
    }
}
