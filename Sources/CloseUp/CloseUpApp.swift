import SwiftUI

@main
struct CloseUpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    private var appState: AppState { delegate.appState }

    var body: some Scene {
        // Read `hideMenuBarIcon` DIRECTLY here so this Scene gains an Observation
        // dependency on it. A `Binding`'s get closure is the only other access and
        // it never runs during `body`, so without this read `App.body` is never
        // re-evaluated and `MenuBarExtra` would not re-read `isInserted` when the
        // flag changes — the Settings "Hide Menu Bar Icon" toggle and the reopen
        // recovery would only take effect on the next cold launch (a plain Binding
        // is a passive get/set pair, not an observation source).
        let hidden = appState.hideMenuBarIcon
        MenuBarExtra(isInserted: Binding(
            get: { !hidden },
            set: { appState.hideMenuBarIcon = !$0 }
        )) {
            MenuBarView()
                .localized(with: appState)
        } label: {
            // Native menu-bar glyph: a window carrying the control dots over a
            // second window — the menu-bar form of the app icon (window controls
            // on Mission Control). The system renders the SF Symbol as a template
            // and supplies the light/dark/active tint.
            Image(systemName: "macwindow.on.rectangle")
        }
        .menuBarExtraStyle(.menu)

        // No SwiftUI `Settings` scene: its `showSettingsWindow:` responder does
        // not open the window from the reopen handler in an accessory app (see
        // `SettingsWindowController`), so Settings is presented from a
        // self-managed `NSWindow` reached via `appState.openSettings()`.
    }
}

extension View {
    /// Inject the shared state plus the chosen locale, rebuilding the subtree
    /// on language change so every string re-resolves live (no restart).
    func localized(with appState: AppState) -> some View {
        environment(appState)
            .environment(\.locale, appState.locale)
            .id(appState.localeIdentifier)
    }
}
