import Foundation
import CloseUpKit
import ObjectiveC
import os

/// Third-party packages localize their own UI strings with
/// `NSLocalizedString(bundle: .module)`, which resolves against the *system*
/// language and ignores the in-app override — the exact mixed-language failure
/// the i18n rules forbid. `NSBundle` instances are uniqued by path, so
/// re-classing the package's resource bundle here also redirects the
/// package-internal `.module` lookups to the app's chosen language.
@MainActor
enum ThirdPartyBundleLocalization {
    /// SPM resource bundles Xcode copies into `Contents/Resources`, named
    /// `<package>_<target>.bundle`. Every entry needs a guard test pinning the
    /// name and its per-language `.lproj` coverage (`LocalizationGuardTests`),
    /// since both silently break on a package bump.
    private static let bundleNames = ["KeyboardShortcuts_KeyboardShortcuts"]

    static func apply(language: SupportedLanguage) {
        LanguageOverrideBundle.language.withLock { $0 = language }
        for name in bundleNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "bundle"),
                  let bundle = Bundle(url: url),
                  !(bundle is LanguageOverrideBundle)
            else { continue }
            object_setClass(bundle, LanguageOverrideBundle.self)
        }
    }
}

/// Swapped in for a third-party resource bundle via `object_setClass`, so it
/// must not add stored instance state. Resolves every string in the app's
/// chosen language, falling back to English — never the system language.
private final class LanguageOverrideBundle: Bundle, @unchecked Sendable {
    // OSAllocatedUnfairLock instead of Synchronization.Mutex: same shape
    // (state-protecting withLock), but available from macOS 13 — Mutex is
    // 15-only and the deployment floor is 14 (see project.yml).
    static let language = OSAllocatedUnfairLock<SupportedLanguage>(initialState: .english)

    override func localizedString(forKey key: String, value: String?, table: String?) -> String {
        let language = Self.language.withLock { $0 }
        let lprojName = language.preferredLocalization(from: localizations) ?? "en"
        guard let path = path(forResource: lprojName, ofType: "lproj"),
              let lproj = Bundle(path: path)
        else {
            return super.localizedString(forKey: key, value: value, table: table)
        }
        return lproj.localizedString(forKey: key, value: value, table: table)
    }
}
