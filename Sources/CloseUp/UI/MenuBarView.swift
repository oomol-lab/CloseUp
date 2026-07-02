import AppKit
import SwiftUI

/// The status-bar (menu-bar) dropdown. Rendered as a native `NSMenu` by
/// `MenuBarExtra(.menu)`, so every label is pre-resolved through `appState.loc`
/// to follow the in-app language override rather than the system language.
struct MenuBarView: View {
    @Environment(AppState.self) private var appState

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
            // AppKit-managed window shared with the reopen handler; SwiftUI's
            // `Settings` scene can't be opened from the reopen path in an
            // accessory app, so CloseUp does not use it. See `SettingsWindowController`.
            appState.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button(appState.loc("Quit CloseUp")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
