import Foundation
import Testing

@testable import CloseUpKit

/// Anchor for locating the test bundle's embedded resources.
private final class BundleToken {}

/// Repo-wide i18n guards. The app renders in an in-app language override, so two
/// failure classes only ever show up at runtime, in a language the developer
/// isn't running: strings localized by *someone else's* bundle leaking into UI,
/// and catalog keys that are missing or only partially translated. These tests
/// scan the app sources and the string catalog instead of waiting for a
/// mixed-language screenshot. `CloseUpKit` itself is non-UI, so only
/// `Sources/CloseUp` is scanned.
@Suite("Localization guards")
struct LocalizationGuardTests {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // CloseUpKitTests/
        .deletingLastPathComponent() // Tests/
        .deletingLastPathComponent()

    private static let appSources = repoRoot.appending(path: "Sources/CloseUp")
    private static let catalog = appSources.appending(path: "Localizable.xcstrings")

    private static func appSwiftFiles() throws -> [(name: String, text: String)] {
        let enumerator = try #require(
            FileManager.default.enumerator(at: appSources, includingPropertiesForKeys: nil)
        )
        var files: [(String, String)] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            files.append((url.lastPathComponent, try String(contentsOf: url, encoding: .utf8)))
        }
        #expect(!files.isEmpty, "no Swift sources found under \(appSources.path)")
        return files
    }

    private static func catalogStrings() throws -> [String: [String: Any]] {
        let data = try Data(contentsOf: catalog)
        let doc = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(doc["strings"] as? [String: [String: Any]])
    }

    @Test("UI layer never displays system-localized error text")
    func noLocalizedDescriptionInAppLayer() throws {
        for (name, text) in try Self.appSwiftFiles() {
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let code = line.prefix(upTo: line.firstRange(of: "//")?.lowerBound ?? line.endIndex)
                if code.contains("localizedDescription"), !line.contains("i18n-exempt") {
                    Issue.record("\(name):\(index + 1) uses localizedDescription — map the error to a catalog key instead")
                }
            }
        }
    }

    @Test("string catalog is fully translated for every supported language")
    func catalogIsComplete() throws {
        let required = SupportedLanguage.allCases.filter { $0 != .english }.map(\.localeIdentifier)
        for (key, entry) in try Self.catalogStrings() {
            let localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]
            for language in required {
                guard let unit = localizations[language]?["stringUnit"] as? [String: Any],
                      unit["state"] as? String == "translated"
                else {
                    Issue.record("catalog key \"\(key)\" is missing a finished \(language) translation")
                    continue
                }
            }
        }
    }

    @Test("window titles are never bridged from a LocalizedStringKey")
    func noLiteralNavigationTitles() throws {
        for (name, text) in try Self.appSwiftFiles() {
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let code = line.prefix(upTo: line.firstRange(of: "//")?.lowerBound ?? line.endIndex)
                if code.contains(".navigationTitle(\""), !line.contains("i18n-exempt") {
                    Issue.record("\(name):\(index + 1) bridges a LocalizedStringKey into the window title — use a pre-resolved string")
                }
            }
        }
    }

    @Test("KeyboardShortcuts recorder titles are never bare string literals")
    func recorderTitlesAreLocalized() throws {
        // A bare string binds to the `String` initializer (renders verbatim,
        // bypassing the language override). Force the localized overload with
        // `LocalizedStringKey("…")`.
        for (name, text) in try Self.appSwiftFiles() {
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let code = line.prefix(upTo: line.firstRange(of: "//")?.lowerBound ?? line.endIndex)
                if code.contains(".Recorder(\""), !line.contains("i18n-exempt") {
                    Issue.record("\(name):\(index + 1) passes a bare string to KeyboardShortcuts.Recorder — wrap it in LocalizedStringKey(\"…\")")
                }
            }
        }
    }

    @Test("redirected third-party bundles exist and cover every supported language")
    func thirdPartyBundlesCoverAllLanguages() throws {
        let source = try String(
            contentsOf: Self.appSources.appending(path: "Localization/ThirdPartyBundleLocalization.swift"),
            encoding: .utf8
        )
        let names = source.matches(of: try Regex<(Substring, Substring)>(#""([A-Za-z0-9]+_[A-Za-z0-9]+)""#))
            .map { String($0.1) }
        try #require(!names.isEmpty, "no redirected bundle names found in ThirdPartyBundleLocalization.swift")

        for name in names {
            guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "bundle"),
                  let bundle = Bundle(url: url)
            else {
                Issue.record("resource bundle \"\(name)\" not found — SPM bundle renamed on a package bump?")
                continue
            }
            for language in SupportedLanguage.allCases
            where language.preferredLocalization(from: bundle.localizations) == nil {
                Issue.record("\(name).bundle ships no \(language.localeIdentifier) localization — its UI would fall back to English")
            }
        }
    }

    @Test("keys resolved outside SwiftUI exist in the catalog")
    func dynamicKeysExistInCatalog() throws {
        // Keys reached via `loc(...)` / `AppKitStrings.string(...)` / `.help(...)`
        // are invisible to Xcode's extractor — a typo silently falls back to
        // English. Every such literal must be a real catalog key.
        let keys = Set(try Self.catalogStrings().keys)
        let callPattern = try Regex<(Substring, Substring)>(
            #"(?:\.loc\(|AppKitStrings\.string\(|\.help\()\s*"((?:[^"\\]|\\.)+)""#
        )
        for (name, text) in try Self.appSwiftFiles() {
            let referenced = text.matches(of: callPattern).map { String($0.1) }
            for key in referenced where !keys.contains(key) {
                Issue.record("\(name) resolves \"\(key)\" but Localizable.xcstrings has no such key")
            }
        }
    }

    @Test("every .sheet re-injects the in-app locale override")
    func sheetsReinjectLocale() throws {
        // A `.sheet` bridges into its own AppKit window, which resets `\.locale`
        // to the system language — re-inject `.environment(\.locale, …locale)`.
        let reinjection = try Regex(#"\.environment\(\s*\\\.locale\s*,\s*(?:appState|state)\.locale\s*\)"#)
        for (name, text) in try Self.appSwiftFiles() {
            let lines = Array(text.split(separator: "\n", omittingEmptySubsequences: false))
            for (index, line) in lines.enumerated() {
                let code = line.prefix(upTo: line.firstRange(of: "//")?.lowerBound ?? line.endIndex)
                guard code.contains(".sheet(") else { continue }
                let window = lines[index..<min(index + 20, lines.count)].map { windowLine in
                    String(windowLine.prefix(upTo: windowLine.firstRange(of: "//")?.lowerBound ?? windowLine.endIndex))
                }.joined(separator: "\n")
                if window.firstMatch(of: reinjection) == nil {
                    Issue.record("\(name):\(index + 1) presents a .sheet without re-injecting \\.locale")
                }
            }
        }
    }
}
