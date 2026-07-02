import SwiftUI

/// The root of the Settings window — a tabbed pane layout following the system
/// Settings idiom. Panes are added in their respective feature phases.
struct SettingsRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            GeneralSettingsPane()
                .tabItem { Label(appState.loc("General"), systemImage: "gearshape") }

            ShortcutsSettingsPane()
                .tabItem { Label(appState.loc("Shortcuts"), systemImage: "command") }

            UpdatesSettingsPane()
                .tabItem { Label(appState.loc("Updates"), systemImage: "arrow.down.circle") }

            AboutPane()
                .tabItem { Label(appState.loc("About"), systemImage: "info.circle") }
        }
        .frame(width: DS.Window.settingsWidth, height: DS.Window.settingsHeight)
        .onDisappear { appState.stopAccessibilityWatch() }
    }
}
