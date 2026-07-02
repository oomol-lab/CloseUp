import SwiftUI

/// CloseUp's single source of truth for visual design — spacing, radii, sizes,
/// color, typography, and motion. Caseless namespaced enums (zero runtime cost,
/// no accidental init). Reference these tokens everywhere; never inline literals.
///
/// The whole app reads as one coherent, system-native design language in both
/// light and dark appearance. Values follow a 4-pt rhythm and the macOS control
/// scale (13-pt baseline, not iOS). See `docs/DESIGN.md` for the full spec.
///
/// > Inside `.formStyle(.grouped)` Forms the Form owns its insets — do **not**
/// > add spacing/padding there. These tokens apply to custom views (About,
/// > Update, overlay, confirmations).
enum DS {

    // MARK: - Spacing (4-pt grid)

    enum Spacing {
        /// 2 — icon↔caption gap, vertical micro-pad.
        static let xxs: CGFloat = 2
        /// 4 — tight inline.
        static let xs: CGFloat = 4
        /// 6 — compact stacks.
        static let sm: CGFloat = 6
        /// 8 — default control gap.
        static let md: CGFloat = 8
        /// 12 — row HStack (icon↔text).
        static let lg: CGFloat = 12
        /// 16 — window content padding inside custom panels.
        static let xl: CGFloat = 16
        /// 32 — About-window rhythm blocks / hero padding.
        static let section: CGFloat = 32
    }

    // MARK: - Element sizes

    enum Size {
        /// 128 — app icon on the About screen.
        static let aboutIcon: CGFloat = 128
    }

    // MARK: - Window & sheet sizes

    enum Window {
        /// 600 × 460 — the Settings window, a fixed size (~4:3, the common,
        /// readable proportion for a tabbed macOS settings window). Fixing both
        /// dimensions keeps the window stable across tabs (no jump on switch, per
        /// HIG) and gives the tallest pane (Shortcuts, 8 rows) room without scroll.
        static let settingsWidth: CGFloat = 600
        static let settingsHeight: CGFloat = 460
        static let acknowledgementsWidth: CGFloat = 360
        static let acknowledgementsHeight: CGFloat = 320
    }

    // MARK: - Color (semantic; adapts to light/dark automatically)

    enum Palette {
        /// Brand accent (AccentColor asset — light + dark + high-contrast
        /// variants). Set as the target Global Accent Color so it also reaches
        /// AppKit pickers/checkboxes/focus rings.
        static let accent = Color.accentColor
        /// Positive result (up to date, granted).
        static let success = Color.green
        /// Warning / attention.
        static let warning = Color.orange

        // Overlay traffic-light buttons. Deliberately a neutral gray-white — not
        // the vivid stoplight colors — to match native Mission Control. These
        // are fixed (not semantic) values: the Mission
        // Control backdrop is always a darkened wallpaper regardless of the app's
        // light/dark appearance, so the button must read against a dark ground in
        // both, which a system semantic color would not guarantee.
        /// Light gray-white button fill.
        static let overlayButtonFill = Color(white: 0.97)
        /// Graphite glyph centered in the button (close ✕ / minimize − / zoom).
        static let overlayButtonSymbol = Color(white: 0.22)
        /// Hairline edge separating the light button from the dark backdrop.
        static let overlayButtonBorder = Color.black.opacity(0.18)
        /// Soft drop shadow lifting the button off the darkened backdrop.
        static let overlayButtonShadow = Color.black.opacity(0.25)
    }

    // MARK: - Overlay cluster

    enum Overlay {
        /// Hovered traffic-light lift (a render-only scale — never reflows siblings).
        static let hoverLift: CGFloat = 1.12
        /// Hairline border width around a button circle.
        static let buttonBorderWidth: CGFloat = 0.5
        /// Drop-shadow blur radius under a button.
        static let buttonShadowRadius: CGFloat = 1.5
        /// Drop-shadow vertical offset under a button.
        static let buttonShadowYOffset: CGFloat = 0.5
    }

    // MARK: - Typography (semantic macOS styles — never `.system(size:)`)

    enum Font {
        /// About app name — ~22pt semibold.
        static let appName = SwiftUI.Font.title.weight(.semibold)
        /// Update-window header title — ~17pt bold.
        static let windowTitle = SwiftUI.Font.title2.bold()
        /// List-row title, settings labels — 13pt.
        static let rowTitle = SwiftUI.Font.body
        /// Version / secondary value — 12pt.
        static let version = SwiftUI.Font.callout
        /// Dense metadata — 10pt.
        static let rowSubtitle = SwiftUI.Font.caption2
        /// Form section footers — 10pt.
        static let sectionFooter = SwiftUI.Font.footnote
        /// Copyright line — 10pt.
        static let copyright = SwiftUI.Font.caption
    }

    // MARK: - Motion

    enum Motion {
        /// Overlay button appear/disappear.
        static let overlay = Animation.easeOut(duration: 0.15)
    }
}

// MARK: - Availability-bridging styles

extension View {
    /// Form section footer text — 10pt footnote in secondary color.
    func settingsFooter() -> some View {
        self.font(DS.Font.sectionFooter).foregroundStyle(.secondary)
    }

    /// Tahoe's `.glass` button style, degrading to `.bordered` pre-26
    /// (the deployment floor predates Liquid Glass; these two helpers are the
    /// only sanctioned way to use glass styles — never call them directly).
    @ViewBuilder
    func dsGlassButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// Tahoe's `.glassProminent` button style, degrading to
    /// `.borderedProminent` pre-26.
    @ViewBuilder
    func dsGlassProminentButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}
