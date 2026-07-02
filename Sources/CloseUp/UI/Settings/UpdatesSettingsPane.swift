import CloseUpKit
import SwiftUI

/// Update preferences: the automatic-check toggle, a last-checked timestamp
/// (formatted in the app locale), and a manual check button. The check opens
/// Sparkle's flow only when an update actually exists.
struct UpdatesSettingsPane: View {
    @Environment(AppState.self) private var appState
    @AppStorage(UpdateChannel.usesBetaDefaultsKey) private var usesBeta = false

    var body: some View {
        Form {
            Section {
                Picker(appState.loc("Channel"), selection: $usesBeta) {
                    Text(appState.loc("Stable")).tag(false)
                    Text(appState.loc("Beta")).tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: usesBeta) { appState.updateController.channelDidChange() }
            } header: {
                Text(appState.loc("Channel"))
            } footer: {
                Text(appState.loc("Stable ships tagged releases. Beta tracks the nightly build — newer features, less tested."))
                    .settingsFooter()
            }

            Section {
                Toggle(appState.loc("Automatically check for updates"), isOn: autoCheckBinding)
                LabeledContent(appState.loc("Last checked"), value: lastCheckedText)
                Button(appState.loc("Check for Updates…")) {
                    appState.updateController.checkForUpdates()
                }
                .disabled(!appState.updateController.canCheckForUpdates)
            } footer: {
                Text(footerText)
                    .settingsFooter()
            }
        }
        .formStyle(.grouped)
        .overlayScrollers()
    }

    private var autoCheckBinding: Binding<Bool> {
        Binding(
            get: { appState.updateController.automaticallyChecksForUpdates },
            set: { appState.updateController.automaticallyChecksForUpdates = $0 }
        )
    }

    private var lastCheckedText: String {
        guard let date = appState.updateController.lastUpdateCheckDate else {
            return appState.loc("Never")
        }
        return date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened).locale(appState.locale)
        )
    }

    private var footerText: String {
        if appState.updateController.canCheckForUpdates {
            return appState.loc("CloseUp updates automatically using a signed, notarized release feed.")
        }
        return appState.loc("Update checks are unavailable in development builds.")
    }
}
