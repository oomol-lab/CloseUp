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
}
