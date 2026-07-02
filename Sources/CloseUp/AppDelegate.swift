import AppKit
import CloseUpKit
import SwiftUI

/// Owns the shared `AppState` and starts the overlay engine at launch. Using a
/// delegate guarantees startup runs even though menu-bar scenes are lazy.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    /// AppKit-managed Settings window (owned here, not by `AppState`, so its
    /// SwiftUI content — which retains `AppState` — does not form a retain cycle).
    private lazy var settingsWindowController = SettingsWindowController(appState: appState)

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState.start()
        // Route the menu's "Settings…" item to the same AppKit-managed window
        // that the reopen handler uses (SwiftUI's `Settings` scene can't be opened
        // from `applicationShouldHandleReopen` in an accessory app).
        appState.settingsPresenter = { [weak self] in self?.settingsWindowController.show() }

        #if DEBUG
        // On-screen verification hook: render the settings UI in a real window at
        // launch (optionally pinning a language) so it can be screenshotted
        // headlessly. Debug-only, env-gated — compiled out of release builds.
        if ProcessInfo.processInfo.environment["CLOSEUP_OPEN_SETTINGS"] == "1" {
            if let code = ProcessInfo.processInfo.environment["CLOSEUP_LANG"],
               let language = SupportedLanguage(rawValue: code) {
                appState.languagePreference = .specific(language)
            }
            NSApp.setActivationPolicy(.regular)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.settingsWindowController.show()
            }
        }
        #endif

        freeReboundMenuShortcuts()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        freeReboundMenuShortcuts()
    }

    /// The KeyboardShortcuts recorder refuses any chord already used by a main-menu
    /// item. CloseUp deliberately repurposes Cmd+M / Cmd+H / Cmd+Opt+H as in-Mission-
    /// Control actions, so clear those default app-menu key equivalents (they are
    /// vestigial for an accessory menu-bar app). Cmd+Q is intentionally kept so the
    /// standard Quit still works; deleting it is recoverable via the per-shortcut
    /// "Restore Default" reset button.
    private func freeReboundMenuShortcuts() {
        guard let mainMenu = NSApp.mainMenu else { return }
        func walk(_ menu: NSMenu) {
            for item in menu.items {
                let key = item.keyEquivalent.lowercased()
                let mods = item.keyEquivalentModifierMask
                if (key == "m" && mods == .command)
                    || (key == "h" && mods == .command)
                    || (key == "h" && mods == [.command, .option]) {
                    item.keyEquivalent = ""
                    item.keyEquivalentModifierMask = []
                }
                if let sub = item.submenu { walk(sub) }
            }
        }
        walk(mainMenu)
    }

    /// Re-opening the app (Finder/Spotlight/`open` launch of the already-running
    /// instance) opens Settings, matching the convention that reopening a
    /// menu-bar app surfaces its main window. This is the recovery route for a
    /// user who hid the menu-bar icon: it must NOT reset the hide flag (the user
    /// asked to keep the icon hidden), and Settings is where they can un-hide it
    /// or reach Quit. `SettingsWindowController` raises the window above other
    /// apps since an accessory (`LSUIElement`) app is not auto-activated.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindowController.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.stop()
    }
}
