import CoreGraphics
import Foundation

/// The undocumented-but-stable system internals that fingerprint Mission Control
/// being on screen. They are version-fragile, so they live here in ONE place on
/// purpose — centralizing them gives forward-compat headroom when a macOS
/// release changes them (macOS 27 did — see below).
public enum MissionControlSurface {
    /// The Dock draws its exposé surface at this window layer for the whole time
    /// Mission Control is visible on macOS ≤26 — the reliable signal for BOTH
    /// opening and closing a session there.
    public static let exposeLayer = 18

    /// macOS 27 "Golden Gate" moved the exposé surface OUT of the Dock: while
    /// Mission Control is visible, `WindowManager` (the Stage Manager process,
    /// `com.apple.WindowManager`) owns one screen-sized window per display at
    /// THIS layer, and the Dock owns nothing beyond its ordinary layer-20 bar
    /// (verified on 26A5368g, beta 2: Dock layers during MC = {20}, WindowManager
    /// layers = {19 fullscreen ×displays, 17 sentinel, 14 Spaces strips, 2, 0}).
    /// The Dock also stopped posting the `AXExpose*` notifications there, so this
    /// poll signal is the ONLY open-detection on 27. NB WindowManager exists
    /// since Ventura and owns only offscreen (negative-layer) windows while MC is
    /// closed, so matching its layer-19 window is as tight a fingerprint as the
    /// Dock's layer-18 was; Stage Manager interplay is unverified (no test
    /// machine with it enabled) — if a false session ever surfaces, suspect that.
    public static let windowManagerExposeLayer = 19

    /// Whether `windows` (a raw `CGWindowListCopyWindowInfo` array) contains a
    /// live exposé surface — the Dock-owned layer-18 window (macOS ≤26) or the
    /// WindowManager-owned layer-19 window (macOS 27+). Checked as an OR of both
    /// generations rather than a version switch: each signal is pid+layer-exact,
    /// neither occurs outside Mission Control on the other's OS, and the OR
    /// self-selects without trusting version numbers. This is the authority for
    /// both opening and ending a session.
    public static func exposeSurfacePresent(
        in windows: [[String: Any]], dockPID: pid_t?, windowManagerPID: pid_t?
    ) -> Bool {
        windows.contains { window in
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = window[kCGWindowLayer as String] as? Int
            else { return false }
            return (dockPID != nil && pid == dockPID && layer == exposeLayer)
                || (windowManagerPID != nil && pid == windowManagerPID && layer == windowManagerExposeLayer)
        }
    }

    /// One-line summary of every window sitting at a NON-standard layer
    /// (`kCGWindowLayer != 0`), for the field tripwire that fires when a session
    /// opened (AX expose notification) but this surface was never observed before
    /// teardown — the fingerprint of a macOS release moving the exposé surface to
    /// a different layer or owning process. Groups identical `owner(pid)@layer`
    /// windows (keeping the largest bounds as the representative size, since the
    /// screen-sized one is the interesting one), sorts layer-descending, and caps
    /// the output so the single `.notice` log line stays readable. Layer-0 app
    /// windows are the normal case and would only be noise.
    public static func layerDiagnostic(in windows: [[String: Any]], maxGroups: Int = 30) -> String {
        struct Group { var count = 0; var maxArea: CGFloat = -1; var size = "" }
        var groups: [String: Group] = [:]
        for window in windows {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer != 0 else { continue }
            let pid = (window[kCGWindowOwnerPID as String] as? pid_t) ?? -1
            let owner = (window[kCGWindowOwnerName as String] as? String) ?? "?"
            let key = "\(owner)(\(pid))@\(layer)"
            var group = groups[key] ?? Group()
            group.count += 1
            if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
               let width = bounds["Width"], let height = bounds["Height"],
               width * height > group.maxArea {
                group.maxArea = width * height
                group.size = "\(Int(width))x\(Int(height))"
            }
            groups[key] = group
        }
        guard !groups.isEmpty else { return "(no non-zero-layer windows)" }
        let layerOf: (String) -> Int = { Int($0.split(separator: "@").last ?? "") ?? 0 }
        let sorted = groups.sorted {
            let lhs = layerOf($0.key)
            let rhs = layerOf($1.key)
            return lhs != rhs ? lhs > rhs : $0.key < $1.key
        }
        let shown = sorted.prefix(maxGroups).map { key, group -> String in
            let size = group.size.isEmpty ? "" : ":\(group.size)"
            let count = group.count > 1 ? "×\(group.count)" : ""
            return "\(key)\(size)\(count)"
        }
        let overflow = sorted.count > maxGroups ? " +\(sorted.count - maxGroups) more" : ""
        return shown.joined(separator: " ") + overflow
    }
}
