import AppKit
import SwiftUI

/// The status-bar (menu-bar) dropdown. Rendered as a native `NSMenu` by
/// `MenuBarExtra(.menu)`, so every label is pre-resolved through `appState.loc`
/// to follow the in-app language override rather than the system language.
struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var appState = appState

        Toggle(appState.loc("Enable"), isOn: $appState.isEnabled)

        Divider()

        if appState.updateController.canCheckForUpdates {
            Button(appState.loc("Check for Updates…")) {
                appState.updateController.checkForUpdates()
            }
        }

        Button(appState.loc("Settings…")) {
            openSettings()
            frontSettingsWindow()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button(appState.loc("Quit CloseUp")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    /// Bring the Settings window all the way to the front of the desktop.
    ///
    /// CloseUp is an accessory (`LSUIElement`) app, so the system does not
    /// activate it when one of its windows opens — and the SwiftUI Settings
    /// window is an ordinary level-0 window, so it would otherwise open *behind*
    /// whatever app is frontmost. `NSApp.activate()` is cooperative and can be
    /// denied (it is, when the menu is driven without a genuine app switch), so
    /// it cannot be relied on alone; `orderFrontRegardless()` guarantees the
    /// window rises above other apps either way (the non-deprecated equivalent of
    /// the old `activate(ignoringOtherApps:)`). `openSettings()` may create the
    /// window asynchronously, so retry briefly until it exists.
    private func frontSettingsWindow(attempt: Int = 0) {
        NSApp.activate()
        if let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue.contains("Settings") == true
        }) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else if attempt < 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                frontSettingsWindow(attempt: attempt + 1)
            }
        }
    }
}
