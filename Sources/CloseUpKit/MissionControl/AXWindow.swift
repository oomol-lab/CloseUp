import AppKit
import ApplicationServices

// Private APIs, used identically by OpenMissionControl / DockDoor / alt-tab —
// all notarized Developer-ID apps. They bar Mac App Store distribution (out of
// scope) but are stable across macOS releases on Intel + Apple Silicon.

/// Returns the CGWindowID backing an `AXUIElement` (macOS 10.10+).
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: inout CGWindowID) -> AXError

/// Wakes / toggles Mission Control & Exposé from the Dock.
@_silgen_name("CoreDockSendNotification")
private func CoreDockSendNotification(_ notification: CFString, _ unknown: Int32) -> Void

/// Undocumented-but-stable window attribute reporting native full-screen state
/// (the window occupies its own Space). There is no public `kAX…` constant and
/// AppKit exposes no Swift symbol, but `AXFullScreen` is the de-facto signal every
/// window manager (yabai, Amethyst, …) reads for this. A standard window returns a
/// CFBoolean; an unreadable/absent value is treated as "not full-screen".
private let kAXFullScreenAttribute = "AXFullScreen"

private extension Duration {
    /// This duration in milliseconds, for the capability-resolve latency log lines.
    var milliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}

/// Process-global cap on the Accessibility messaging timeout. Every AX read in
/// this process blocks its calling thread until the TARGET app's run loop
/// answers, bounded only by this timeout — and the system default is both long
/// and version-dependent (measured ~1.5 s on macOS 26; 6 s historically). On
/// the overlay's hover path that default was a MainActor freeze whenever the
/// hovered app was busy. alt-tab-macos, DockDoor, and yabai all cap it at 1 s
/// for exactly this reason; CloseUp does the same at engine start. NB the cap
/// must be set on the SYSTEM-WIDE element — that (and only that) applies it to
/// every message this process sends; a timeout set on an app element binds to
/// that exact ref only and does NOT propagate to elements copied out of it.
public enum AXMessaging {
    public static func capGlobalTimeout(seconds: Float) {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), seconds)
    }
}

/// Discriminated result of one AX attribute read. `absent` means the app
/// ANSWERED and the value is not there (authoritative — e.g. a window with no
/// minimize button); `failed` means the app did NOT answer (messaging timeout /
/// busy / dead element — `kAXErrorCannotComplete` et al). The two demand
/// opposite handling: absence feeds an authoritative `.resolved`, failure must
/// poison the resolve into `.indeterminate` so a busy app is retried instead of
/// being remembered as buttonless. The old helper collapsed both into `nil`,
/// which is what made a transient failure indistinguishable from a popover.
private enum AXRead<T> {
    case value(T)
    case absent
    case failed
}

/// Result of matching CGWindowIDs to an app's AX window elements.
private struct AXWindowMatches {
    var matches: [CGWindowID: AXUIElement] = [:]
    /// A `kAXErrorCannotComplete` was seen along the way — an unmatched target
    /// may simply not have been enumerable right now, so "no match" is NOT
    /// authoritative and must resolve `.indeterminate`, never `.none`.
    var sawFailure = false
}

private extension AXUIElement {
    /// One AX attribute read with the error discriminated — see `AXRead`.
    /// `.noValue` / `.attributeUnsupported` are answers ("not there"); every
    /// other non-success (`.cannotComplete` timeout, `.invalidUIElement`, …)
    /// is a failure. The `as? T` bridge mirrors the CF bridging the old helper
    /// relied on (CFArray → [AXUIElement], CFBoolean → Bool, CFString → String).
    func read<T>(_ attribute: String, as type: T.Type) -> AXRead<T> {
        var value: CFTypeRef?
        switch AXUIElementCopyAttributeValue(self, attribute as CFString, &value) {
        case .success:
            guard let cast = value as? T else { return .absent }
            return .value(cast)
        case .noValue, .attributeUnsupported:
            return .absent
        default:
            return .failed
        }
    }

    /// The title-bar button element for `attribute` (`kAXCloseButton` etc.).
    /// CF casts are unchecked, so the CFTypeID comparison is the real type
    /// check (some apps answer with a non-element value).
    func readButton(_ attribute: String) -> AXRead<AXUIElement> {
        var value: CFTypeRef?
        switch AXUIElementCopyAttributeValue(self, attribute as CFString, &value) {
        case .success:
            guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return .absent }
            return .value(value as! AXUIElement) // swiftlint-safe: type id checked above
        case .noValue, .attributeUnsupported:
            return .absent
        default:
            return .failed
        }
    }

    /// Match `targets` (CGWindowIDs) to this application element's window
    /// elements in one pass: one `AXWindows` copy, then — only for targets the
    /// fast path missed — one `AXChildren` scan filtered to `AXRole ==
    /// AXWindow` (some apps surface a window only there, so an AXWindows array
    /// that is success-but-thin must not blank the overlay or no-op an action).
    /// `self` is the `AXUIElementCreateApplication` element.
    func matchWindows(_ targets: Set<CGWindowID>) -> AXWindowMatches {
        var result = AXWindowMatches()
        var remaining = targets

        func scan(_ elements: [AXUIElement]) {
            for element in elements {
                guard !remaining.isEmpty else { return }
                var id = CGWindowID(0)
                switch _AXUIElementGetWindow(element, &id) {
                case .success:
                    if remaining.remove(id) != nil { result.matches[id] = element }
                case .cannotComplete:
                    result.sawFailure = true
                default:
                    break // not a window-backed element — skip
                }
            }
        }

        var listReadFailed = false
        switch read(kAXWindowsAttribute, as: [AXUIElement].self) {
        case .value(let windows): scan(windows)
        case .absent: break
        case .failed:
            result.sawFailure = true
            listReadFailed = true
        }
        // The AXChildren fallback exists for apps whose list is answered but
        // THIN. When the windows-list read itself FAILED (the app is not
        // answering), skip it — a second read against the same wedged app just
        // stacks another full messaging timeout onto the caller's thread.
        if !remaining.isEmpty, !listReadFailed {
            switch read(kAXChildrenAttribute, as: [AXUIElement].self) {
            case .value(let children):
                scan(children.filter { child in
                    if case .value(let role) = child.read(kAXRoleAttribute, as: String.self) {
                        role == kAXWindowRole as String
                    } else {
                        false
                    }
                })
            case .absent: break
            case .failed: result.sawFailure = true
            }
        }
        return result
    }

    /// This application element's window whose backing `CGWindowID` is
    /// `windowID` — the action-path (performer) entry point, which does not
    /// need the failure discrimination.
    func axWindow(matching windowID: CGWindowID) -> AXUIElement? {
        matchWindows([windowID]).matches[windowID]
    }

    /// Every window element of this application element — `AXWindows` fast path,
    /// then the `AXChildren` scan filtered to `AXRole == AXWindow`. This is the
    /// app's FULL window list, including minimized and other-Space windows that
    /// are not on-screen Mission Control thumbnails.
    var allAXWindows: [AXUIElement] {
        if case .value(let windows) = read(kAXWindowsAttribute, as: [AXUIElement].self), !windows.isEmpty {
            return windows
        }
        guard case .value(let children) = read(kAXChildrenAttribute, as: [AXUIElement].self) else { return [] }
        return children.filter { child in
            if case .value(let role) = child.read(kAXRoleAttribute, as: String.self) {
                role == kAXWindowRole as String
            } else {
                false
            }
        }
    }

    func pressButton(_ attribute: String) -> Bool {
        guard case .value(let button) = readButton(attribute) else { return false }
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }
}

/// The live capability resolver: reads a window's Accessibility element to see
/// which title-bar buttons it actually has. Requires Accessibility trust;
/// returns `.unavailable` when not trusted so the caller can fall back to the
/// legacy "show every enabled action" behaviour instead of an empty overlay
/// everywhere. All reads discriminate transient failure (`.indeterminate`)
/// from authoritative absence — see `CapabilityResolution`.
@MainActor
public final class AccessibilityCapabilityResolver: WindowCapabilityResolving {
    public init() {}

    public func resolution(for window: WindowInfo) -> CapabilityResolution {
        Self.resolutions(for: [window])[window.windowID] ?? .indeterminate
    }

    /// Resolve a whole window set in one pass, grouped per owning app so each
    /// app pays ONE windows-list copy + id match for all of its windows (the
    /// naive per-window resolve re-copies the list every time). `nonisolated`
    /// on purpose: the engine's session prewarm runs this off the main actor
    /// (AX messaging is plain C IPC; alt-tab and DockDoor run the same reads on
    /// background queues at scale), so the first-touch per-app connection cost
    /// (~25–45 ms measured) never lands on the hover path.
    public nonisolated static func resolutions(for windows: [WindowInfo]) -> [CGWindowID: CapabilityResolution] {
        guard AXIsProcessTrusted() else {
            return Dictionary(windows.map { ($0.windowID, CapabilityResolution.unavailable) }, uniquingKeysWith: { first, _ in first })
        }
        var out: [CGWindowID: CapabilityResolution] = [:]
        for (pid, group) in Dictionary(grouping: windows, by: \.ownerPID) {
            out.merge(resolveGroup(pid: pid, windows: group)) { first, _ in first }
        }
        return out
    }

    private nonisolated static func resolveGroup(pid: pid_t, windows: [WindowInfo]) -> [CGWindowID: CapabilityResolution] {
        let clock = ContinuousClock()
        let start = clock.now
        let app = AXUIElementCreateApplication(pid)
        let matched = app.matchWindows(Set(windows.map(\.windowID)))
        let matchEnd = clock.now

        var out: [CGWindowID: CapabilityResolution] = [:]
        for window in windows {
            guard let element = matched.matches[window.windowID] else {
                // No matching AX window: with a clean scan this is authoritative
                // (an auxiliary surface not in the app's window list → no
                // overlay); after any failed read it is unknowable right now.
                out[window.windowID] = matched.sawFailure
                    ? .indeterminate
                    : .resolved(WindowCapabilities.none)
                continue
            }
            out[window.windowID] = resolve(element)
        }
        let end = clock.now
        let owner = windows.first?.ownerName ?? "?"
        Log.missionControl.debug("capability resolve app=\(owner, privacy: .public) windows=\(windows.count, privacy: .public) matched=\(matched.matches.count, privacy: .public)\(matched.sawFailure ? " FAILED" : "", privacy: .public) match=\((matchEnd - start).milliseconds, format: .fixed(precision: 1), privacy: .public)ms attrs=\((end - matchEnd).milliseconds, format: .fixed(precision: 1), privacy: .public)ms")
        return out
    }

    /// Resolve one matched window element: full-screen gate first, then the
    /// three button probes. Any failed read short-circuits to `.indeterminate`
    /// (never guess a busy app's buttons — and never pay more than one timeout).
    private nonisolated static func resolve(_ element: AXUIElement) -> CapabilityResolution {
        // A native full-screen window lives in its own Space; in Mission Control
        // its thumbnail sits in the top Spaces strip where the straddling cluster
        // anchors off-screen (the "wrong position" bug), and traffic-light
        // controls make no sense on a Space tile anyway. So show no overlay on a
        // full-screen app at all. NB the AX tree still exposes the
        // close/minimize/zoom buttons for a full-screen window, so this must be
        // an explicit check — their presence alone would light it up.
        switch element.read(kAXFullScreenAttribute, as: Bool.self) {
        case .value(true): return .resolved(WindowCapabilities.none)
        case .failed: return .indeterminate
        case .value(false), .absent: break
        }
        var present: [Bool] = []
        for attribute in [kAXCloseButtonAttribute, kAXMinimizeButtonAttribute, kAXZoomButtonAttribute] {
            switch element.readButton(attribute) {
            case .value: present.append(true)
            case .absent: present.append(false)
            case .failed: return .indeterminate
            }
        }
        return .resolved(WindowCapabilities(
            canClose: present[0],
            canMinimize: present[1],
            canZoom: present[2]
        ))
    }
}

/// Performs a `WindowAction` on a real window identified by its `WindowInfo`.
@MainActor
public protocol WindowActionPerforming {
    func perform(_ action: WindowAction, on window: WindowInfo)
    /// Perform a window button action (close / minimize / zoom) on EVERY window of
    /// the app owning `pid` — the app's full AX window list — for the ⌥-batch
    /// shortcuts (⌥⌘W close-all and ⌥⌘M minimize-all).
    func performOnAllWindows(_ action: WindowAction, ofApp pid: pid_t)
    /// Wake Mission Control so a window the action brings forward settles
    /// correctly — called before zoom, which inherently activates its window.
    func wakeMissionControl()
}

/// The live performer: presses the window's own AX title-bar button for
/// close/minimize/zoom, and acts on the owning `NSRunningApplication` for
/// hide/quit. Requires Accessibility trust; a no-op (logged) otherwise.
@MainActor
public final class AccessibilityWindowActionPerformer: WindowActionPerforming {
    public init() {}

    public func perform(_ action: WindowAction, on window: WindowInfo) {
        switch action {
        case .close, .minimize, .zoom:
            pressTitleBarButton(action, on: window)
        case .hide:
            NSRunningApplication(processIdentifier: window.ownerPID)?.hide()
        case .quit:
            guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else { return }
            // Never terminate Finder — it owns the desktop and re-launches anyway,
            // so quitting it is pointless and disruptive. Also never quit CloseUp
            // itself (its own Settings window is actionable for close/minimize, but
            // ⌘Q must not kill the app from inside Mission Control).
            if app.bundleIdentifier == "com.apple.finder" { return }
            if app.bundleIdentifier == Bundle.main.bundleIdentifier { return }
            app.terminate()
        }
    }

    public func performOnAllWindows(_ action: WindowAction, ofApp pid: pid_t) {
        // Only the window-button actions are batchable per-window; hide/quit are
        // app-level and have no per-window button.
        guard let attribute = action.axButtonAttribute else { return }
        let app = AXUIElementCreateApplication(pid)
        // The app's FULL window list, so the batch closes / minimizes every window
        // of the app — including minimized and
        // other-Space windows that are not on-screen Mission Control thumbnails —
        // not just the captured ones.
        for window in app.allAXWindows {
            _ = window.pressButton(attribute)
        }
    }

    /// Wakes Mission Control (so a brought-forward window settles correctly) —
    /// used before a zoom, which inherently activates the window.
    public func wakeMissionControl() {
        CoreDockSendNotification("com.apple.expose.awake" as CFString, 0)
    }

    private func pressTitleBarButton(_ action: WindowAction, on window: WindowInfo) {
        guard let attribute = action.axButtonAttribute else { return }
        let app = AXUIElementCreateApplication(window.ownerPID)
        guard let target = app.axWindow(matching: window.windowID) else {
            Log.missionControl.error("no AX window matching id \(window.windowID, privacy: .public) for pid \(window.ownerPID, privacy: .public)")
            return
        }
        if !target.pressButton(attribute) {
            Log.missionControl.error("failed to press \(attribute, privacy: .public) on window \(window.windowID, privacy: .public)")
        }
    }
}
