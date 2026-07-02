import KeyboardShortcuts

// The in-Mission-Control action shortcuts (close/minimize/zoom/hide/quit and the
// ⌥ batch variants) must NOT be global hotkeys — `⌘W` registered globally would
// swallow every window-close system-wide. They are declared WITHOUT a `default:`
// (which would auto-register on first launch) and are kept permanently
// `disable()`d so the matching happens only inside the event tap while Mission
// Control is open. Their stored value is still read via
// `KeyboardShortcuts.getShortcut(for:)` and edited with the native Recorder.
extension KeyboardShortcuts.Name {
    // In-Mission-Control actions (never globally registered).
    nonisolated(unsafe) static let closeWindow = Self("closeWindow")
    nonisolated(unsafe) static let minimizeWindow = Self("minimizeWindow")
    nonisolated(unsafe) static let zoomWindow = Self("zoomWindow")
    nonisolated(unsafe) static let hideApp = Self("hideApp")
    nonisolated(unsafe) static let quitApp = Self("quitApp")
    nonisolated(unsafe) static let closeAllWindows = Self("closeAllWindows")
    nonisolated(unsafe) static let minimizeAllWindows = Self("minimizeAllWindows")
    nonisolated(unsafe) static let hideAllExceptHovered = Self("hideAllExceptHovered")
}
