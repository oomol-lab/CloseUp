import Combine
import CloseUpKit
import SwiftUI

/// General settings: the master enable toggle, launch-at-login, which overlay
/// controls appear, and the in-app language override.
struct GeneralSettingsPane: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section {
                Toggle(isOn: $appState.isEnabled) {
                    Text(appState.loc("Enable CloseUp"))
                    Text(appState.loc("Show window controls in Mission Control."))
                        .settingsFooter()
                }
                Toggle(appState.loc("Launch at login"), isOn: $appState.launchAtLogin)
                Toggle(appState.loc("Hide Menu Bar Icon"), isOn: $appState.hideMenuBarIcon)
            }

            Section {
                LabeledContent {
                    statusBadge
                } label: {
                    Text(appState.loc("Accessibility"))
                }

                if !appState.accessibilityGranted {
                    Button(appState.loc("Open Accessibility Settings…")) {
                        appState.requestAccessibilityAccess()
                    }
                }
            } header: {
                Text(appState.loc("Permission"))
            } footer: {
                Text(appState.loc("CloseUp needs Accessibility access to read the windows in Mission Control and to close, minimize, hide, or quit them. It never records your screen."))
                    .settingsFooter()
            }

            Section {
                Toggle(appState.loc("Close"), isOn: $appState.overlaySettings.showClose)
                Toggle(appState.loc("Minimize"), isOn: $appState.overlaySettings.showMinimize)
                Toggle(appState.loc("Maximize"), isOn: $appState.overlaySettings.showZoom)
            } header: {
                Text(appState.loc("Controls"))
            } footer: {
                Text(appState.loc("Choose which controls appear on each window in Mission Control."))
                    .settingsFooter()
            }

            Section {
                Picker(selection: $appState.languagePreference) {
                    Text(appState.loc("Follow System")).tag(LanguagePreference.system)
                    Divider()
                    ForEach(SupportedLanguage.allCases) { language in
                        Text(language.nativeName).tag(LanguagePreference.specific(language))
                    }
                } label: {
                    Text(appState.loc("Language"))
                }
            } footer: {
                Text(appState.loc("Changes apply immediately."))
                    .settingsFooter()
            }
        }
        .formStyle(.grouped)
        .overlayScrollers()
        .onAppear { appState.refreshAccessibilityStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.refreshAccessibilityStatus()
        }
    }

    private var statusBadge: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: appState.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(appState.accessibilityGranted ? DS.Palette.success : DS.Palette.warning)
            Text(appState.loc(appState.accessibilityGranted ? "Granted" : "Not granted"))
                .foregroundStyle(.secondary)
        }
    }

}
