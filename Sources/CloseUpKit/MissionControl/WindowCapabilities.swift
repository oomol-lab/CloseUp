/// Which title-bar controls a specific window actually exposes, resolved from its
/// Accessibility element (the presence of `kAXCloseButton` / `kAXMinimizeButton`
/// / `kAXZoomButton`). CloseUp shows a traffic-light only for a control the window
/// really has — so a popover / sheet / panel without a standard close button gets
/// no spurious lights. The filter is AX-driven for exactly this reason:
/// `CGWindowList` alone cannot tell a real window from a chrome-less auxiliary
/// one, which is why this needs Accessibility.
public struct WindowCapabilities: Equatable, Sendable {
    public let canClose: Bool
    public let canMinimize: Bool
    public let canZoom: Bool

    public init(canClose: Bool, canMinimize: Bool, canZoom: Bool) {
        self.canClose = canClose
        self.canMinimize = canMinimize
        self.canZoom = canZoom
    }

    /// No actionable title-bar button — e.g. an auxiliary window or one not found
    /// in the app's AX window list. Yields an empty overlay.
    public static let none = WindowCapabilities(canClose: false, canMinimize: false, canZoom: false)

    /// Of `requested` (the settings-enabled actions, already in left-to-right
    /// display order), the subset this window actually supports. close/minimize/
    /// zoom each require their AX title-bar button to exist; hide/quit are
    /// app-level (no window button) so they pass through unchanged.
    public func supported(from requested: [WindowAction]) -> [WindowAction] {
        requested.filter { action in
            switch action {
            case .close: canClose
            case .minimize: canMinimize
            case .zoom: canZoom
            case .hide, .quit: true
            }
        }
    }
}

/// Outcome of resolving a window's capabilities via Accessibility. Three-way,
/// because "the app answered and this window has no buttons" and "the app did
/// not answer" demand opposite treatment: the former is authoritative (a
/// popover / sheet / full-screen tile → keep the overlay dark), the latter is
/// transient (a busy app timing out `kAXErrorCannotComplete` → worth retrying,
/// never worth caching). Collapsing the two — the old `WindowCapabilities?`
/// contract — is what left a window stuck dark after one transient failure
/// (nothing re-resolved while the cursor stayed on it).
public enum CapabilityResolution: Equatable, Sendable {
    /// Accessibility is not granted — the caller should fall back to showing
    /// every enabled action (the legacy no-AX behaviour).
    case unavailable
    /// The app answered; these are the window's actual title-bar buttons
    /// (`.none` means a genuinely buttonless surface or a full-screen tile).
    case resolved(WindowCapabilities)
    /// The app failed to answer (messaging timeout / busy / element died
    /// mid-read). Unknown — retry later, show nothing now, cache nothing.
    case indeterminate
}

/// Pure policy mapping one `CapabilityResolution` to what the overlay engine
/// should display, remember, and retry. Kept in CloseUpKit so the
/// transient-vs-authoritative rules are unit-tested decision logic, not engine
/// glue.
public enum OverlayCapabilityPolicy {
    /// The engine-facing consequence of one resolve.
    public struct Outcome: Equatable, Sendable {
        /// What to intersect the enabled actions with; `nil` = show every
        /// enabled action (the AX-untrusted fallback).
        public let display: WindowCapabilities?
        /// Non-`nil` → remember for the rest of the session (cache-first hover
        /// path). Only authoritative non-empty resolutions are cached: `.none`
        /// might be an app still warming up, and indeterminate is by definition
        /// unknown — caching either could pin a real window dark all session.
        public let cache: WindowCapabilities?
        /// Whether a background re-resolve is worthwhile (bounded by the
        /// engine): `true` for `.none` (may be transient warm-up) and
        /// indeterminate (the app may answer next time).
        public let retry: Bool

        public init(display: WindowCapabilities?, cache: WindowCapabilities?, retry: Bool) {
            self.display = display
            self.cache = cache
            self.retry = retry
        }
    }

    public static func outcome(for resolution: CapabilityResolution) -> Outcome {
        switch resolution {
        case .unavailable:
            Outcome(display: nil, cache: nil, retry: false)
        case .resolved(let capabilities) where capabilities != WindowCapabilities.none:
            Outcome(display: capabilities, cache: capabilities, retry: false)
        case .resolved:
            Outcome(display: WindowCapabilities.none, cache: nil, retry: true)
        case .indeterminate:
            Outcome(display: WindowCapabilities.none, cache: nil, retry: true)
        }
    }
}

/// Outcome-class counts of one background-resolve batch, for the one-shot
/// "prewarm all-dark" field tripwire: a session whose windows are real Mission
/// Control thumbnails should virtually always resolve at least ONE window with
/// buttons — a batch of several windows where none did is the fingerprint of the
/// AX matching pipeline breaking OS-wide (e.g. `_AXUIElementGetWindow` no longer
/// pairing AX elements with CGWindowIDs, or trusted-but-failing AX reads), which
/// presents in the field as "no lights anywhere, permission granted".
public struct CapabilityBatchSummary: Equatable, Sendable {
    /// Windows that resolved with at least one title-bar button.
    public let withButtons: Int
    /// Windows that authoritatively resolved buttonless (`.resolved(.none)`).
    public let none: Int
    /// Windows whose app failed to answer (`.indeterminate`).
    public let indeterminate: Int
    /// Windows reported while Accessibility is untrusted (`.unavailable`).
    public let unavailable: Int

    public init(of resolutions: some Sequence<CapabilityResolution>) {
        var withButtons = 0, none = 0, indeterminate = 0, unavailable = 0
        for resolution in resolutions {
            switch resolution {
            case .resolved(let capabilities) where capabilities != WindowCapabilities.none:
                withButtons += 1
            case .resolved:
                none += 1
            case .indeterminate:
                indeterminate += 1
            case .unavailable:
                unavailable += 1
            }
        }
        self.withButtons = withButtons
        self.none = none
        self.indeterminate = indeterminate
        self.unavailable = unavailable
    }

    /// True when Accessibility answered (trusted) yet not one window in the
    /// batch resolved a single button. `.unavailable` batches are excluded: the
    /// untrusted path is a known mode with its own fallback (show every enabled
    /// action) and its own log fingerprint (`observer armed … trusted=n`), so
    /// flagging it here would be noise, not signal.
    public var isAllDark: Bool {
        withButtons == 0 && unavailable == 0 && (none + indeterminate) > 0
    }

    /// Compact form for the one `.notice` tripwire log line.
    public var logDescription: String {
        "buttons=\(withButtons) none=\(none) indeterminate=\(indeterminate) unavailable=\(unavailable)"
    }
}

/// Resolves a window's `WindowCapabilities` from its live Accessibility element.
@MainActor
public protocol WindowCapabilityResolving {
    /// The window's capability resolution — see `CapabilityResolution` for the
    /// three-way contract (`.unavailable` = AX untrusted → caller shows all
    /// enabled actions; `.resolved(.none)` = authoritative no-overlay;
    /// `.indeterminate` = transient failure → show nothing, retry).
    func resolution(for window: WindowInfo) -> CapabilityResolution
}
