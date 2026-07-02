import CloseUpKit
import KeyboardShortcuts
import SwiftUI

/// Customize every shortcut. Each row pairs the native recorder with its own
/// "restore default" icon button, so one binding can be reverted without
/// touching the others. The row label is a `LocalizedStringKey` (not the
/// recorder's own title) so it follows the in-app language override; the
/// recorder itself is created title-less.
struct ShortcutsSettingsPane: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section {
                // `allCases` order is the display order (single-window verbs,
                // then the ⌥ batch variants); each row's label key comes from
                // `MissionControlShortcut.titleKey`, shared with the overlay
                // buttons so the two surfaces can never drift.
                ForEach(MissionControlShortcut.allCases, id: \.self) { shortcut in
                    ShortcutRow(shortcut: shortcut)
                }
            } footer: {
                footer("Active only while Mission Control is open.")
            }
        }
        .formStyle(.grouped)
        .overlayScrollers()
    }

    private func footer(_ key: String) -> some View {
        Text(appState.loc(key))
            .settingsFooter()
    }
}

/// One shortcut row: the native recorder plus a reset-to-default icon that is
/// enabled only while the binding differs from its default chord. `isAtDefault`
/// is tracked locally and refreshed from the recorder's `onChange` (and on the
/// reset itself) so the icon dims the instant a row returns to its default.
private struct ShortcutRow: View {
    @Environment(AppState.self) private var appState
    let shortcut: MissionControlShortcut

    @State private var isAtDefault = true

    var body: some View {
        LabeledContent {
            HStack(spacing: DS.Spacing.sm) {
                KeyboardShortcuts.Recorder(for: shortcut.name) { _ in
                    isAtDefault = appState.isShortcutAtDefault(shortcut)
                }
                Button {
                    appState.restoreShortcutDefault(shortcut)
                    isAtDefault = true
                } label: {
                    Label(appState.loc("Restore Default"), systemImage: "arrow.uturn.backward")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help(appState.loc("Restore Default"))
                .disabled(isAtDefault)
            }
        } label: {
            Text(LocalizedStringKey(shortcut.titleKey))
        }
        .onAppear { isAtDefault = appState.isShortcutAtDefault(shortcut) }
    }
}
