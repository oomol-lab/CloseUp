import AppKit
import SwiftUI

/// About pane: icon, name, version, license, project link, and the open-source
/// dependencies CloseUp is built with. Brand/proper nouns stay verbatim.
struct AboutPane: View {
    @Environment(AppState.self) private var appState

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    @State private var showingAcknowledgements = false

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: DS.Size.aboutIcon, height: DS.Size.aboutIcon)

            Text(verbatim: "CloseUp")
                .font(DS.Font.appName)

            Text(verbatim: version)
                .font(DS.Font.version)
                .foregroundStyle(.secondary)

            Text(appState.loc("Open source under GPL-3.0."))
                .font(DS.Font.copyright)
                .foregroundStyle(.secondary)

            HStack(spacing: DS.Spacing.lg) {
                Link(destination: URL(string: "https://github.com/oomol-lab/CloseUp")!) {
                    Text(verbatim: "GitHub")
                }
                Button(appState.loc("Acknowledgements")) { showingAcknowledgements = true }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.Palette.accent)
            }
            .font(DS.Font.version)
            .padding(.top, DS.Spacing.xs)
        }
        .padding(DS.Spacing.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAcknowledgements) {
            AcknowledgementsView()
                .environment(appState)
                .environment(\.locale, appState.locale)
        }
    }
}
