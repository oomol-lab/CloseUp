import Foundation

/// Which overlay controls are shown, persisted as a single JSON blob. Defaults
/// = close + minimize + maximize all on; hide/quit are keyboard-only and never
/// appear as overlay buttons.
///
/// Forward/backward-compatible: every field decodes present-or-default, so a blob
/// written by an older build (missing a later toggle) still loads, and a blob
/// from a newer build (extra keys) loads on the fields this build knows. Each
/// default reproduces the pre-field behavior.
public struct OverlaySettings: Codable, Equatable, Sendable {
    public var showClose: Bool
    public var showMinimize: Bool
    public var showZoom: Bool

    public init(
        showClose: Bool = true,
        showMinimize: Bool = true,
        showZoom: Bool = true
    ) {
        self.showClose = showClose
        self.showMinimize = showMinimize
        self.showZoom = showZoom
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = OverlaySettings()
        showClose = try c.decodeIfPresent(Bool.self, forKey: .showClose) ?? d.showClose
        showMinimize = try c.decodeIfPresent(Bool.self, forKey: .showMinimize) ?? d.showMinimize
        showZoom = try c.decodeIfPresent(Bool.self, forKey: .showZoom) ?? d.showZoom
    }

    /// Whether a given action's button is enabled. Hide/quit are keyboard-only
    /// and never appear as overlay buttons, so they are always disabled here.
    public func isEnabled(_ action: WindowAction) -> Bool {
        switch action {
        case .close: showClose
        case .minimize: showMinimize
        case .zoom: showZoom
        case .hide, .quit: false
        }
    }

    /// The enabled actions in left-to-right overlay order. Always non-empty in
    /// practice (the settings UI keeps at least close on), but callers must
    /// tolerate an empty result — an empty overlay simply doesn't show.
    public var enabledActions: [WindowAction] {
        WindowAction.allCases.filter(isEnabled)
    }
}
