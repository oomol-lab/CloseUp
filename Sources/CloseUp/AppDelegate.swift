import AppKit
import CloseUpKit
import SwiftUI

/// Owns the shared `AppState` and starts the overlay engine at launch. Using a
/// delegate guarantees startup runs even though menu-bar scenes are lazy.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState.start()

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
                self.showSettingsForScreenshot()
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

    #if DEBUG
    private var screenshotWindow: NSWindow?

    private func showSettingsForScreenshot() {
        let root = SettingsRootView().localized(with: appState)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: DS.Window.settingsWidth, height: DS.Window.settingsHeight),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "CloseUp"
        window.contentView = NSHostingView(rootView: root)
        window.center()
        window.isReleasedWhenClosed = false
        screenshotWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    #endif

    /// Re-opening the app (Finder/Spotlight launch of the already-running
    /// instance) un-hides the menu-bar icon. It is the only route to Settings/Quit,
    /// so a hidden-icon user needs this recovery: reset the hide flag instead of
    /// opening a window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if appState.hideMenuBarIcon { appState.hideMenuBarIcon = false }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.stop()
    }
}
