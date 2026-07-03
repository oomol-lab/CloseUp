import CoreGraphics
import Foundation

/// The undocumented-but-stable Dock internal that fingerprints Mission Control
/// being on screen. It is version-fragile, so it lives here in ONE place on
/// purpose — centralizing it gives forward-compat headroom if a macOS release
/// changes it.
public enum MissionControlSurface {
    /// The Dock draws its exposé surface at this window layer for the whole time
    /// Mission Control is visible — the reliable signal for BOTH opening and
    /// closing a session.
    public static let exposeLayer = 18

    /// Whether `windows` (a raw `CGWindowListCopyWindowInfo` array) contains the
    /// Dock-owned layer-18 exposé surface. This is the authority for both opening
    /// and ending a session.
    public static func exposeSurfacePresent(in windows: [[String: Any]], dockPID: pid_t) -> Bool {
        windows.contains { window in
            (window[kCGWindowOwnerPID as String] as? pid_t) == dockPID
                && (window[kCGWindowLayer as String] as? Int) == exposeLayer
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
