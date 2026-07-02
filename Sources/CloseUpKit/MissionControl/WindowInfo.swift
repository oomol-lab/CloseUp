import CoreGraphics
import Foundation

/// A real on-screen window, distilled from one `CGWindowListCopyWindowInfo`
/// entry. The frame is in **CoreGraphics global coordinates** (origin top-left
/// of the main display, +Y down) — the same space `CGEvent.location` reports, so
/// hit-testing happens entirely in CG space and the bottom-left flip is deferred
/// to the moment an `NSWindow` frame is needed (`OverlayGeometry`).
public struct WindowInfo: Equatable, Sendable {
    public let windowID: CGWindowID
    public let ownerPID: pid_t
    public let ownerName: String
    public let frame: CGRect

    public init(windowID: CGWindowID, ownerPID: pid_t, ownerName: String, frame: CGRect) {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.frame = frame
    }

    /// Parse one `CGWindowListCopyWindowInfo` dictionary. Returns `nil` if the
    /// entry lacks the fields needed to act on the window (id, pid, bounds).
    public init?(cgEntry entry: [String: Any]) {
        guard let windowID = entry[kCGWindowNumber as String] as? CGWindowID,
              let ownerPID = (entry[kCGWindowOwnerPID as String] as? pid_t),
              let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat],
              let x = bounds["X"], let y = bounds["Y"],
              let width = bounds["Width"], let height = bounds["Height"]
        else { return nil }

        self.windowID = windowID
        self.ownerPID = ownerPID
        self.ownerName = entry[kCGWindowOwnerName as String] as? String ?? ""
        self.frame = CGRect(x: x, y: y, width: width, height: height)
    }
}

public extension Array where Element == WindowInfo {
    /// The actionable app windows in a `CGWindowListCopyWindowInfo` result:
    /// only layer 0 (`kCGWindowLayer`, the standard window layer) is kept, minus
    /// any owner named in `excludingOwners` and any owner pid in
    /// `excludingPIDs`. The pid exclusion is what actually drops the Dock:
    /// `kCGWindowOwnerName` is LOCALIZED ("程序坞", "Dock", …), so a name match
    /// alone silently fails on every non-English system and the Dock's layer-0
    /// surface joins the hover candidates — hovering it resolves no AX window
    /// and the lights go dark. Exclude system owners by pid, never by their
    /// display name; the name set remains only as an English-system
    /// belt-and-suspenders. (The engine keeps CloseUp's own windows actionable
    /// and drops its overlay window by id instead.)
    static func actionable(
        from entries: [[String: Any]],
        excludingOwners excluded: Set<String> = ["Dock"],
        excludingPIDs excludedPIDs: Set<pid_t> = []
    ) -> [WindowInfo] {
        entries.compactMap { entry -> WindowInfo? in
            guard (entry[kCGWindowLayer as String] as? Int) == 0 else { return nil }
            guard let info = WindowInfo(cgEntry: entry) else { return nil }
            guard !excluded.contains(info.ownerName) else { return nil }
            guard !excludedPIDs.contains(info.ownerPID) else { return nil }
            // A degenerate (zero-area) window can never be hovered; skip it.
            guard info.frame.width > 1, info.frame.height > 1 else { return nil }
            return info
        }
    }

    /// The topmost window whose frame contains `point` (CG coordinates).
    /// `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` returns windows in
    /// front-to-back order, so the first match is the frontmost.
    func frontmost(containing point: CGPoint) -> WindowInfo? {
        first { $0.frame.contains(point) }
    }

    /// Like `frontmost(containing:)` but also treats a band of `topOverhang`
    /// points **above** each window's top edge as part of the window, so a window
    /// can be ACQUIRED on first approach from the straddle zone the overlay cluster
    /// occupies (the cluster hangs `buttonSize/2 + clusterPadding` above the
    /// thumbnail's top edge — a cursor reaching for it is not yet inside any raw
    /// frame). In CG coordinates the top edge is `minY` and "above" is smaller Y.
    /// The live engine's `overCurrentCluster` stickiness only KEEPS an
    /// already-hovered window; this is what lets the *first* hover land there too.
    func frontmost(containing point: CGPoint, topOverhang: CGFloat) -> WindowInfo? {
        first { window in
            if window.frame.contains(point) { return true }
            let band = CGRect(
                x: window.frame.minX,
                y: window.frame.minY - topOverhang,
                width: window.frame.width,
                height: topOverhang
            )
            return band.contains(point)
        }
    }

    /// Keep only windows whose overlay anchor (top-left + `inset`) lands inside
    /// some display.
    ///
    /// While Mission Control re-tiles after a Space switch, `CGWindowList`
    /// transiently reports a window at a garbage/off-screen position (observed:
    /// the same window flicking between an on-screen x and x≈-250 within one
    /// animation). If such a mis-placed window happens to sit in front and cover
    /// the cursor, `frontmost(containing:)` picks it and the overlay is anchored
    /// off-screen — the user sees *no* control on the window they're actually
    /// hovering. Dropping off-screen-anchored windows lets the hit-test fall
    /// through to the real, correctly-placed window underneath. `displays` are
    /// the active display bounds in the same CG (top-left origin) space as the
    /// window frames (`CGDisplayBounds`).
    func anchoredOnScreen(displays: [CGRect], inset: CGFloat) -> [WindowInfo] {
        guard !displays.isEmpty else { return self }
        return filter { window in
            let anchor = CGPoint(x: window.frame.minX + inset, y: window.frame.minY + inset)
            return displays.contains { $0.contains(anchor) }
        }
    }
}
