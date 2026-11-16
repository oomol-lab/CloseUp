import CoreGraphics

/// What a middle-click in Mission Control acts on.
public enum MiddleClickTarget: Equatable, Sendable {
    /// A traffic-light button of the hovered window — pressed exactly as a left
    /// click would press it.
    case button(index: Int, windowID: CGWindowID)
    /// A thumbnail body — the window is closed. Carries the whole `WindowInfo`
    /// (frame included), so a thumbnail that moved between press and release no
    /// longer equals the pressed target and is left alone.
    case window(WindowInfo)
    /// A click CloseUp declines to act on but must still consume. Mission Control
    /// treats a middle-click it receives on a thumbnail as SELECTING that window
    /// (verified on macOS 27: it exits and switches on the release), so passing a
    /// declined click through would turn "not safe to close right now" into
    /// "switch to that window".
    case blocked

    /// Whether a release on `other` completes a click pressed on `self`: the same
    /// button, or the same window with its frame within `tolerance` whole pixels
    /// (the engine's settle tolerance — 0 except in degraded settle, where the
    /// cached frames legitimately drift a pixel or two between two refreshes).
    /// `.blocked` completes nothing.
    public func isCompleted(by other: MiddleClickTarget?, tolerance: Int) -> Bool {
        switch (self, other) {
        case let (.button(index, windowID), .button(otherIndex, otherWindowID)):
            index == otherIndex && windowID == otherWindowID
        case let (.window(pressed), .window(released)):
            MiddleClickPolicy.framesCurrent(cached: pressed, live: released, tolerance: tolerance)
        default:
            false
        }
    }
}

/// Everything the engine knows about one middle-button event, as plain values so
/// the routing rule below is unit-tested instead of living in event-tap glue.
public struct MiddleClickContext: Equatable, Sendable {
    /// Mission Control's exposé surface is on screen right now — false in the
    /// close-miss debounce tail, where the tap lingers but the thumbnails are stale.
    public var surfacePresent: Bool
    /// The thumbnail frames are holding still (the engine's settle gate).
    public var layoutSettled: Bool
    /// A pass-through left click is dismissing Mission Control; its exit animation
    /// is about to move every thumbnail.
    public var dismissing: Bool
    /// The user's "middle-click a window to close it" setting.
    public var closesWindows: Bool
    /// The traffic-light button under the point, if the cluster is showing there.
    public var buttonHit: MiddleClickTarget?
    /// The frontmost thumbnail under the point in the engine's CACHED window list
    /// (refreshed by a ~100 ms poll).
    public var windowAtPoint: WindowInfo?
    /// The frontmost thumbnail under the point in a list enumerated AT THIS EVENT.
    /// It must agree with the cached one (`MiddleClickPolicy.framesCurrent`) — the
    /// settle gate alone lags the screen by up to a refresh tick — and it, not the
    /// cached entry, becomes the target, so the press/release pairing compares
    /// what was actually on screen at each event.
    public var liveWindowAtPoint: WindowInfo?
    /// The engine's settle tolerance in whole pixels (0, or the degraded-settle
    /// value), applied to the cached-vs-live comparison.
    public var settleTolerance: Int
    /// Whether the window under the point is KNOWN to have a close button (the session's
    /// capability cache). Unknown counts as no: a popover, a full-screen tile or a
    /// not-yet-resolved window is never closed blind.
    public var windowCanClose: Bool

    public init(
        surfacePresent: Bool,
        layoutSettled: Bool,
        dismissing: Bool,
        closesWindows: Bool,
        buttonHit: MiddleClickTarget?,
        windowAtPoint: WindowInfo?,
        liveWindowAtPoint: WindowInfo?,
        settleTolerance: Int,
        windowCanClose: Bool
    ) {
        self.surfacePresent = surfacePresent
        self.layoutSettled = layoutSettled
        self.dismissing = dismissing
        self.closesWindows = closesWindows
        self.buttonHit = buttonHit
        self.windowAtPoint = windowAtPoint
        self.liveWindowAtPoint = liveWindowAtPoint
        self.settleTolerance = settleTolerance
        self.windowCanClose = windowCanClose
    }
}

/// Pure routing rule for a middle-click while Mission Control is open.
public enum MiddleClickPolicy {
    /// `kCGMouseButtonCenter`. The `otherMouse*` event types cover EVERY button
    /// from 2 up, so the back/forward side buttons (3, 4) arrive on the same
    /// types and must be told apart by number.
    public static let middleButtonNumber: Int64 = 2

    public static func isMiddleButton(_ buttonNumber: Int64) -> Bool {
        buttonNumber == middleButtonNumber
    }

    /// The target of a middle-button event, or `nil` to leave it to Mission Control.
    ///
    /// A traffic-light hit wins and needs only a live surface (the cluster is on
    /// screen, so the layout is settled by construction). With the setting off
    /// everything else is `nil`: middle-click stays fully native. With it on, the
    /// middle button belongs to CloseUp. Closing is destructive, so it is gated
    /// hard — the frames must be at rest AND still where a live enumeration at the
    /// click finds them, Mission Control must not be on its way out, and the
    /// window must be known to have a close button — and a click
    /// that fails a gate is `.blocked`: consumed with no effect, because Mission
    /// Control would otherwise select the window under it. A dropped click costs
    /// the user a second click; a wrong target costs a window. While the frames
    /// are moving the cached window list cannot say what is under the point, so
    /// the whole screen is blocked; at rest, empty space is left to Mission Control.
    public static func target(for context: MiddleClickContext) -> MiddleClickTarget? {
        guard context.surfacePresent else { return nil }
        if let buttonHit = context.buttonHit { return buttonHit }
        guard context.closesWindows else { return nil }
        guard context.layoutSettled, !context.dismissing else { return .blocked }
        guard framesCurrent(
            cached: context.windowAtPoint, live: context.liveWindowAtPoint, tolerance: context.settleTolerance
        ) else { return .blocked }
        // Target the EVENT-TIME snapshot: the pairing then measures how far the
        // thumbnail really moved between press and release. Pairing on the cached
        // entry would compare the cache with itself and miss a drift that stays
        // within tolerance of the cache at each event but exceeds it across them.
        guard let window = context.liveWindowAtPoint else { return nil }
        return context.windowCanClose ? .window(window) : .blocked
    }
}

public extension MiddleClickPolicy {
    /// Whether the thumbnail a LIVE enumeration finds under the click point is the
    /// one the cached, settled layout has there (same window id, same frame).
    ///
    /// The engine's window list is refreshed by a ~100 ms poll, and `layoutSettled`
    /// flips only when that poll sees the frames move. So for up to one tick after
    /// a re-tile begins — most reliably right after a close, which re-tiles the
    /// remaining thumbnails on macOS ≤26 — the layout still reads as settled while
    /// the cached frames are the OLD ones, and a quick second click would resolve
    /// to whatever window USED to be under the pointer. Comparing against a list
    /// enumerated at the event closes that gap for every cause of staleness, not
    /// just a close. `tolerance` is the engine's settle tolerance in whole pixels
    /// (0 normally, the degraded-settle value when the OS keeps thumbnails in
    /// perpetual micro-motion), so the two gates agree on what "still" means.
    static func framesCurrent(cached: WindowInfo?, live: WindowInfo?, tolerance: Int) -> Bool {
        switch (cached, live) {
        case (nil, nil):
            true
        case let (cached?, live?):
            cached.windowID == live.windowID && !ThumbnailLayout.didRetile(
                from: [cached.windowID: cached.frame], to: [live.windowID: live.frame], tolerance: tolerance
            )
        default:
            false
        }
    }
}

/// Pairs a middle-button press with its release so the click is consumed WHOLE:
/// a press that lands on a target is swallowed, and so is its release — Mission
/// Control never sees half of a click CloseUp acted on. The action fires on the
/// release, and only if the release resolves to the same target as the press, so
/// dragging off before letting go cancels (as with any button). A `.blocked`
/// press is swallowed whole and never fires.
public struct MiddleClickPairing: Equatable, Sendable {
    public struct Release: Equatable, Sendable {
        /// Swallow the release event (its press was swallowed).
        public let swallow: Bool
        /// The target to act on, if the click completed on it.
        public let fire: MiddleClickTarget?

        public init(swallow: Bool, fire: MiddleClickTarget?) {
            self.swallow = swallow
            self.fire = fire
        }
    }

    private var armed: MiddleClickTarget?

    public init() {}

    /// Record a press. Returns whether to swallow it. A press on nothing also
    /// disarms a stale press whose release never reached the tap.
    public mutating func press(_ target: MiddleClickTarget?) -> Bool {
        armed = target
        return target != nil
    }

    /// Resolve a release against the armed press, disarming either way. Fires the
    /// RELEASE target (the window as last seen) when it completes the press — see
    /// `MiddleClickTarget.isCompleted(by:tolerance:)`.
    public mutating func release(_ target: MiddleClickTarget?, tolerance: Int = 0) -> Release {
        defer { armed = nil }
        guard let armed else { return Release(swallow: false, fire: nil) }
        return Release(swallow: true, fire: armed.isCompleted(by: target, tolerance: tolerance) ? target : nil)
    }

    public mutating func reset() {
        armed = nil
    }
}
