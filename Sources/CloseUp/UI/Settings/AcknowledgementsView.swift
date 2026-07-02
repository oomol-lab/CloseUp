import SwiftUI

private struct Acknowledgement: Identifiable {
    var id: String { name }
    let name: String
    let license: String
    let url: URL
}

/// The open-source dependencies CloseUp builds on, shown as a sheet from the
/// About pane. Library + license names are proper nouns, rendered verbatim.
struct AcknowledgementsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private let items: [Acknowledgement] = [
        Acknowledgement(name: "Sparkle", license: "Sparkle License",
                        url: URL(string: "https://github.com/sparkle-project/Sparkle")!),
        Acknowledgement(name: "KeyboardShortcuts", license: "MIT License",
                        url: URL(string: "https://github.com/sindresorhus/KeyboardShortcuts")!),
        Acknowledgement(name: "PermissionFlow", license: "MIT License",
                        url: URL(string: "https://github.com/jaywcjlove/PermissionFlow")!),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(appState.loc("Acknowledgements"))
                    .font(DS.Font.windowTitle)
                Spacer()
                Button(appState.loc("Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(DS.Spacing.xl)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        Link(destination: item.url) {
                            HStack(spacing: DS.Spacing.md) {
                                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                    Text(verbatim: item.name)
                                        .font(DS.Font.rowTitle)
                                        .foregroundStyle(.primary)
                                    Text(verbatim: item.license)
                                        .font(DS.Font.rowSubtitle)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, DS.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                        if item.id != items.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.sm)
                .overlayScrollers()
            }
        }
        .frame(width: DS.Window.acknowledgementsWidth, height: DS.Window.acknowledgementsHeight)
        .environment(\.locale, appState.locale)
    }
}
