import Foundation
import CloseUpKit

/// Resolves a localized string from the app bundle for an explicit language.
///
/// SwiftUI surfaces re-resolve strings live via the injected `\.locale`. AppKit
/// surfaces that bypass SwiftUI — `NSMenu`, `NSStatusItem` tooltips, `NSAlert`,
/// `NSWindow.title` — don't, so they must look the string up in the chosen
/// language's `.lproj` directly. Keys are the English source strings (matching
/// `Localizable.xcstrings`).
@MainActor
enum AppKitStrings {
    static func string(_ key: String, language: SupportedLanguage) -> String {
        guard let path = Bundle.main.path(forResource: language.localeIdentifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // The source language (en) ships no .lproj — its catalog entries
            // are implicit, so the key *is* the English string. Never fall
            // back to `Bundle.main.localizedString`, which resolves with the
            // *system* language and would override an explicit choice.
            return key
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
