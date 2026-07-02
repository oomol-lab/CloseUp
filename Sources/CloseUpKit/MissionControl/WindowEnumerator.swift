import CoreGraphics

/// Source of the currently on-screen, actionable app windows.
@MainActor
public protocol WindowEnumerating {
    /// `excludingPIDs` is the reliable system-owner filter (the Dock's pid);
    /// `excludingOwners` matches the LOCALIZED `kCGWindowOwnerName` and only
    /// works on English systems — see `[WindowInfo].actionable`.
    func actionableWindows(excludingOwners excluded: Set<String>, excludingPIDs excludedPIDs: Set<pid_t>) -> [WindowInfo]
}

/// The live enumerator backed by `CGWindowListCopyWindowInfo`.
@MainActor
public final class CGWindowListEnumerator: WindowEnumerating {
    public init() {}

    public func actionableWindows(excludingOwners excluded: Set<String>, excludingPIDs excludedPIDs: Set<pid_t>) -> [WindowInfo] {
        let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
            as? [[String: Any]] ?? []
        return [WindowInfo].actionable(from: raw, excludingOwners: excluded, excludingPIDs: excludedPIDs)
    }
}
