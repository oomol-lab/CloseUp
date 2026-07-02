import AppKit
import CloseUpKit
import SwiftUI

/// Orchestrates the Mission Control overlay: observes MC open/close, tracks the
/// hovered thumbnail, positions a passive overlay window over it, and routes
/// clicks (via the event tap + `OverlayGeometry`) and in-MC shortcuts to the
/// window-action performer. All decision logic lives in tested `CloseUpKit` pure
/// functions; this type is the thin platform-glue that wires them to live
/// observers, timers, and an `NSWindow`.
@MainActor
final class MissionControlEngine {
    /// Provides the enabled overlay actions (left-to-right) — read live so a
    /// settings change takes effect on the next session.
    private let actionsProvider: () -> [WindowAction]
    /// Resolves the key chord for an in-MC shortcut (defaults, or a
    /// KeyboardShortcuts-backed provider once that lands).
    private let chordProvider: (MissionControlShortcut) -> KeyChord?
    /// The locale the overlay renders in (the in-app language override).
    private let localeProvider: () -> Locale
    /// CloseUp's own process id, so its windows can be treated specially (its
    /// Settings window is actionable too).
    private let ownPID: pid_t = ProcessInfo.processInfo.processIdentifier

    private let enumerator: any WindowEnumerating
    private let performer: any WindowActionPerforming
    /// Resolves, per window, which title-bar controls actually exist (via AX) so
    /// the overlay only lights up real, closable/minimizable/zoomable windows —
    /// not popovers/sheets/panels. `nil` from it means Accessibility is unavailable
    /// and we fall back to showing every enabled action.
    private let capabilityResolver: any WindowCapabilityResolving
    private let observer = MissionControlObserver()
    private let tap = EventTap()

    private var overlayWindow: NSWindow?
    private var windows: [WindowInfo] = []
    private var hovered: WindowInfo?
    /// Cursor location at the last overlay resolve, used only as a SECONDARY guard to
    /// skip a redundant re-resolve when the cursor has not moved between 60 Hz ticks
    /// AND a window is already resolved/shown (`hovered != nil`) — when nothing is shown
    /// yet, a stationary cursor must keep re-resolving so a first resolve that transiently
    /// found no window still lights up once the thumbnail frame is reported on-screen
    /// (a deliberate cursor-didn't-move early-out — re-resolving every tick when the
    /// pointer is parked is wasted work). It is deliberately
    /// NOT seeded at `beginSession`: it is `nil` while the engine is idle (reset in
    /// `endSession`) and reset to `nil` again the instant the layout settles, so the
    /// FIRST post-settle resolve always fires and shows the lights even when the cursor
    /// is stationary — the fix for the "lights occasionally don't appear on a normal
    /// enter" bug (a Mission Control swipe never moves the cursor, so a seed here blocked
    /// that first show). Suppressing the still-entering / paused-mid-swipe case is the
    /// job of the exact frame-stability settle gate (`layoutSettled`), not this cursor
    /// guard — the enter/pause suppression is keyed off an exact whole-window-set
    /// commit signal, never cursor movement.
    private var lastMouseLocation: CGPoint?
    private var geometry: OverlayGeometry?
    /// The actions actually shown for the hovered window — the settings-enabled
    /// set intersected with the window's real AX capabilities. Drives both the
    /// rendered cluster and the click → action mapping (so button index N always
    /// matches what is on screen).
    private var currentActions: [WindowAction] = []
    /// Per-window capabilities from this session's SUCCESSFUL non-empty AX
    /// resolves — the hover path's FAST PATH: a cached window never pays AX IPC
    /// again (the resolve used to run on every hover change, ~25–45 ms on the
    /// first touch of each app, unbounded on a busy one — the "lights appear
    /// late on another app" complaint). Filled by the session prewarm
    /// (`requestBackgroundResolve`) usually before the first hover, and by the
    /// sync resolve on a miss. Only authoritative non-empty resolutions are
    /// stored (`OverlayCapabilityPolicy`): a `.none` might be an app still
    /// warming up and `.indeterminate` is unknown — caching either could pin a
    /// real window dark for the whole session, while a genuinely buttonless
    /// popover just re-resolves cheap and stays dark. Cache-first also means a
    /// transient failure can never blank a window that already showed real
    /// controls. Cleared at every session boundary.
    private var capabilityCache: [CGWindowID: WindowCapabilities] = [:]
    /// Window ids currently being resolved off the main actor (session prewarm
    /// / blank-hover retries), so overlapping requests never duplicate AX
    /// traffic. Entries clear when their batch merges; tasks always merge.
    private var backgroundResolveInFlight: Set<CGWindowID> = []
    /// How many background resolves came back blank (authoritative `.none` or
    /// `.indeterminate`) per window this session. Bounded by
    /// `maxBackgroundResolveRounds` so a genuine popover stops being re-queried
    /// after a few rounds, while a transiently-failing window still gets the
    /// retries that heal the "stuck dark until you hover away and back" bug.
    private var backgroundResolveRounds: [CGWindowID: Int] = [:]

    /// Background retry budget per window per session. Three rounds spaced by
    /// the ~100 ms fetch cadence cover the transient-failure window without
    /// hammering a genuine popover (each extra round is a few warm AX reads).
    private static let maxBackgroundResolveRounds = 3
    /// Monotonic session counter stamped onto every background-resolve batch, so
    /// a batch started in a PREVIOUS session can never merge into the current
    /// one — its resolutions are stale (e.g. a window that went full-screen
    /// between sessions would relight from the pre-transition read). Bumped at
    /// every `beginSession`.
    private var sessionGeneration = 0
    /// Set by `hideOverlay` (a click hid the lights) and cleared when the hover
    /// moves to a DIFFERENT window: while set, the passive re-show paths — a
    /// background-resolve merge, the suppression-clear timer — must NOT
    /// re-light the window the user just clicked. Without it, a prewarm batch
    /// still in flight at click time merges moments after a traffic-light hit
    /// and re-shows the lights on the just-acted window, the documented
    /// "post-click flash" class ("a button hit re-shows only on the next fresh
    /// hover"). A fresh hover (windowID change in `trackMouse`) is the one
    /// legitimate re-entry, and clearing there restores it.
    private var awaitFreshHoverAfterClick = false
    private let hoverState = OverlayHoverState()
    private var pivotHeight: CGFloat = 0

    private var mouseTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?
    /// Drives the whole session lifecycle off the reliable Dock-layer-18 signal
    /// (the AX expose notifications are unreliable under trackpad swipes). Lives
    /// for the engine's lifetime so it can *re-open* after a swipe's transient
    /// exposé-surface teardown, not just close.
    private var lifecycleTask: Task<Void, Never>?

    /// Observes `NSWorkspace.activeSpaceDidChangeNotification` for the whole
    /// lifetime of a running engine (not just while a session is live). A Space
    /// change does two jobs here:
    ///   1. re-syncs a live overlay to the now-active space's on-screen windows
    ///      (the Dock re-tiles thumbnails to match the new grid), and
    ///   2. **re-arms the Dock `AXObserver`** — the load-bearing fix for the
    ///      field bug where switching into a full-screen app's Space left the
    ///      observer permanently deaf, killing the overlay on *every* desktop
    ///      until relaunch. Re-arming must therefore survive past `endSession`.
    /// It does not, and cannot, cover merely *previewing* a non-active desktop's
    /// strip thumbnail (no public/private API exposes Mission Control's thumbnail
    /// layout) — a known limit shared with OpenMissionControl.
    private var spaceObserver: NSObjectProtocol?

    /// Low-frequency health poll that re-arms the observer if the Dock pid has
    /// changed under it. The Dock is an agent, so `NSWorkspace` posts no
    /// launch/terminate notification for it (verified — `didLaunchApplication`
    /// never fires for `com.apple.dock`); polling the pid is the only reliable
    /// way to catch a Dock crash/restart that would otherwise strand the
    /// `AXObserver` on a dead pid forever.
    private var healthTask: Task<Void, Never>?

    /// Whether an overlay session is live. The authority on this is the
    /// `lifecyclePoll` (the Dock's exposé layer-18 signal), NOT the AX expose
    /// notifications — those fire spuriously under trackpad swipes. The poll
    /// begins a session the moment MC is shown and ends it once MC is really gone,
    /// so a swipe that momentarily drops the exposé surface self-heals on the next
    /// tick instead of leaving the lights dead.
    private var sessionActive = false

    /// Whether the Dock's exposé surface (layer 18) was present at the last
    /// lifecycle-poll tick. `sessionActive` lingers ~600 ms after Mission Control
    /// actually closes (the close-miss debounce that lets a trackpad swipe's
    /// transient teardown self-heal), and the event tap stays installed that whole
    /// time — so an in-MC shortcut (⌘W/⌥⌘W/…) pressed in that tail would otherwise
    /// be swallowed and acted on the now-stale hovered thumbnail. Gating the action
    /// paths on this live signal keeps interception to *only while MC is open*
    /// (CLAUDE.md), without shortening the session/overlay debounce.
    private var mcSurfacePresent = false

    /// Last-seen thumbnail frames (by window id), used to tell when Mission Control's
    /// thumbnails are moving (frame churn) vs settled. Both the *enter* animation and
    /// a later re-tile (Space switch, boundary swipe, full-screen transition) move the
    /// thumbnails AND sink the overlay below the Dock's rebuilt exposé surface; the
    /// overlay is hidden while they move and rebuilt once they settle — the one
    /// recovery that also catches the no-Space-change boundary swipe (which fires
    /// neither `activeSpaceDidChange` nor an exposé-surface change). See
    /// `refreshWindows`.
    private var windowFrames: [CGWindowID: CGRect] = [:]
    /// Whether the thumbnail layout has settled enough to show the overlay. False at
    /// the start of every session and whenever a re-tile begins, so the lights never
    /// chase Mission Control's still-animating thumbnails — they appear only once the
    /// layout holds still (so the lights show only after MC has finished entering). This EXACT frame-stability gate (see `didRetile`) is
    /// now the SOLE authority on suppressing the still-entering / paused-mid-swipe case:
    /// the cursor guard no longer seeds, so a paused interactive scrub stays dark only
    /// because its thumbnails micro-jitter and never read as settled. Flipped by the
    /// settle detector in `refreshWindows`; gates `trackMouse`.
    private var layoutSettled = false
    /// Consecutive non-churning refreshes since the last motion (or session begin).
    /// The overlay is (re)shown once this reaches `settleTicks`, so the animation's
    /// mid-flight micro-pauses coalesce into a single show instead of a flurry.
    private var stableTicks = 0
    /// Countdown (in `trackMouse` ticks) of the post-settle window during which we
    /// keep re-asserting the overlay show, set at every settle and decremented each
    /// tick. The fast single-window enter (#3) is the case the settle-time show does
    /// not actually paint: on a real trackpad swipe `repositionOverlay` runs once but
    /// leaves the overlay HIDDEN (`isVisible == false`) — or, more rarely, orders it
    /// front before the Dock finishes compositing its layer-18 surface so it is stacked
    /// underneath ("sunk") though `isVisible` reports true. The show happens once and,
    /// with the cursor parked over the same window (an MC swipe never moves it), nothing
    /// re-resolved (windowID unchanged), so it stayed hidden until the hovered window
    /// changed (the user's "move out and back" recovery). This watch lets a *stationary*
    /// cursor self-heal — re-anchoring a fresh window when hidden, and unconditionally at
    /// a few forced ticks that span when the Dock may finish compositing; any cursor
    /// MOVEMENT re-checks regardless of the countdown (see `trackMouse`).
    private var sinkWatchTicks = 0

    /// Suppresses overlay re-show after a *pass-through* left click — one that
    /// dismisses Mission Control. MC's exit animation transiently re-tiles and
    /// mis-reports window frames, so without this `trackMouse` re-shows the lights
    /// (often anchored to a garbage top-left frame) for a frame or two before
    /// `endSession`, flashing on the desktop right after MC closes. Self-clearing,
    /// NOT a session-long latch: reset on session begin/end, plus a safety timer
    /// (`suppressReshowTask`) so a click that leaves MC open (e.g. empty space)
    /// can't strand the lights off for the rest of the session.
    private var suppressOverlayReshow = false
    private var suppressReshowTask: Task<Void, Never>?

    private var isRunning = false

    init(
        enumerator: any WindowEnumerating = CGWindowListEnumerator(),
        performer: any WindowActionPerforming = AccessibilityWindowActionPerformer(),
        capabilityResolver: any WindowCapabilityResolving = AccessibilityCapabilityResolver(),
        actionsProvider: @escaping () -> [WindowAction],
        chordProvider: @escaping (MissionControlShortcut) -> KeyChord? = { $0.defaultChord },
        localeProvider: @escaping () -> Locale = { .current }
    ) {
        self.enumerator = enumerator
        self.performer = performer
        self.capabilityResolver = capabilityResolver
        self.actionsProvider = actionsProvider
        self.chordProvider = chordProvider
        self.localeProvider = localeProvider
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true
        Log.missionControl.notice("engine start")
        // Cap the process-global AX messaging timeout: the system default
        // (~1.5 s on macOS 26, 6 s historically) is how a busy hovered app used
        // to freeze the MainActor for seconds inside one capability resolve.
        // 1 s is the value alt-tab-macos, DockDoor, and yabai all converge on.
        AXMessaging.capGlobalTimeout(seconds: 1.0)
        armObserver()
        installSpaceObserver()
        startHealthPoll()
        startLifecyclePoll()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        Log.missionControl.notice("engine stop")
        removeSpaceObserver()
        healthTask?.cancel(); healthTask = nil
        lifecycleTask?.cancel(); lifecycleTask = nil
        observer.stop()
        endSession()
    }

    /// (Re)attach the Dock `AXObserver`. Re-reading the Dock pid on every arm is
    /// what lets the pipeline recover after the Dock relaunches or the observer
    /// stops delivering across a full-screen Space transition. Cheap (a couple of
    /// AX calls) and safe to call repeatedly.
    private func armObserver() {
        observer.stop()
        observer.start { [weak self] state in
            self?.handleStateChange(state)
        }
    }

    private func handleStateChange(_ state: MissionControlState) {
        guard state.showsWindowOverlays else {
            // `AXExposeExit` / `AXExposeShowDesktop` are UNRELIABLE for teardown:
            // a 3-finger trackpad swipe fires `AXExposeExit` while Mission Control
            // stays open (even a swipe that changes no Space), which used to kill
            // the overlay for the rest of the session — lights gone on every window
            // until MC was reopened. So ignore them here; the close-poll (the Dock's
            // exposé layer-18 surface) is the authority on a *real* close. The AX
            // expose notifications are avoided entirely for teardown.
            Log.missionControl.debug("MC state \(state.rawValue, privacy: .public) — ignored (close decided by poll)")
            return
        }
        // Fast-path open: react instantly to the notification rather than waiting for
        // the next poll tick. If a session is already live (the poll beat this laggy
        // notification — it can arrive ~1 s after MC actually opened — or the Dock
        // re-fired it), there is nothing to do: the poll and the frame-churn settle
        // detector are authoritative for the running session, so resyncing here would
        // only force a redundant same-position hide/re-show right as the lights settle.
        // Real re-tiles (Space switch, boundary swipe) are caught by the churn detector;
        // an actual Space change additionally re-syncs via `handleActiveSpaceChange`.
        guard !sessionActive else { return }
        beginSession()
    }

    // MARK: - Session

    /// Stand the session resources up fresh. Both call sites are guarded by
    /// `sessionActive` (the notification fast-path returns early; the lifecycle poll
    /// only begins when inactive), so this never double-starts. A repeat open is
    /// simply ignored; a live Space change re-syncs via `resyncSession` from
    /// `handleActiveSpaceChange`.
    private func beginSession() {
        sessionActive = true
        sessionGeneration += 1
        // The session can be opened by the AX-expose fast-path before the lifecycle
        // poll next ticks; assume the surface is present so the first in-MC shortcut
        // isn't blocked for up to a poll interval. The poll keeps it honest.
        mcSurfacePresent = true
        resetSettleState() // keep the lights hidden until MC finishes entering
        windowFrames = [:]
        capabilityCache = [:]
        backgroundResolveRounds = [:] // fresh retry budget; in-flight ids clear at merge
        awaitFreshHoverAfterClick = false
        // Do NOT seed `lastMouseLocation` here: it stays `nil` (from `endSession`) so the
        // first resolve once the layout settles always shows the lights even with a
        // stationary cursor — a Mission Control swipe never moves the cursor, so seeding
        // it used to block that first show (the "lights occasionally don't appear on a
        // normal enter" bug). Keeping the paused-mid-swipe dark is the exact
        // frame-stability settle gate's job (`layoutSettled`), not the cursor guard.
        clearReshowSuppression() // fresh MC session — lights live again
        pivotHeight = Self.menuBarScreenHeight()
        refreshWindows()
        ensureOverlayWindow()
        Log.missionControl.notice("session begin (windows=\(self.windows.count, privacy: .public))")

        tap.start(handlers: EventTap.Handlers(
            onClick: { [weak self] point in self?.handleClick(at: point) ?? true },
            onSecondaryClick: { [weak self] point in self?.handleSecondaryClick(at: point) ?? true },
            onKey: { [weak self] code, flags in self?.handleKey(code, flags) ?? true }
        ))

        // Track the hovered thumbnail and periodically refresh the window list
        // (Mission Control re-tiles thumbnails away from real positions). Cancel
        // any stragglers first so a re-begin can never leak a second loop.
        mouseTask?.cancel()
        mouseTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.trackMouse()
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
        fetchTask?.cancel()
        fetchTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                // 100 ms (not 250) so the window list tracks Mission Control's
                // re-tile animation closely after a Space switch, when stale
                // frames are what strand the overlay.
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                self?.refreshWindows()
            }
        }
    }

    /// Mission Control draws a Dock-owned exposé surface at window **layer 18**
    /// for the whole time it is visible; polling for it is a *reliable* "is MC
    /// open?" signal (verified: layer-18 Dock windows exist only while MC is up).
    /// We drive the session on this, not on the AX expose notifications, which the
    /// Dock fires spuriously during trackpad swipes. Matched by the Dock pid (the
    /// owner name is localized — "程序坞" etc.) so it is locale-independent.
    /// Whether Mission Control's layer-18 exposé surface is on screen right now,
    /// read in ONE `CGWindowList` pass. This is the authority for opening AND
    /// ending a session. Matched against the LIVE Dock pid, not the observer's
    /// `armedDockPID`: the latter is `nil` until the AXObserver has armed and goes
    /// stale across a Dock relaunch, so coupling detection to it blinds opens
    /// during a Dock-down-at-launch race until the ~2 s health poll re-arms; the
    /// live pid self-heals immediately.
    private func missionControlSurfacePresent() -> Bool {
        guard let dockPID = MissionControlObserver.currentDockPID() else { return false }
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return MissionControlSurface.exposeSurfacePresent(in: info, dockPID: dockPID)
    }

    /// The authority on the session lifecycle (runs for the whole engine lifetime).
    /// Begins the moment MC is shown and ends once it is *really* gone. A trackpad
    /// swipe momentarily tears the exposé surface down and rebuilds it (~1 s); the
    /// session simply re-begins on the next tick, so the overlay self-heals instead
    /// of dying — including a swipe past the last desktop that changes no Space and
    /// emits no re-open notification.
    private func startLifecyclePoll() {
        lifecycleTask?.cancel()
        var closeMisses = 0
        lifecycleTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRunning else { return }
                // Backstop cadence: stay fast (120 ms) whenever the overlay can do
                // anything — a live session OR Accessibility granted (the AX-expose
                // notification can lag ~1 s, so the poll is what opens quickly). Back
                // off to a slow idle keepalive ONLY when untrusted AND idle, where the
                // feature is inert and fast polling is pure battery waste. The engine
                // restarts on grant and this re-checks each tick, so it speeds back up.
                let fast = self.sessionActive || AXIsProcessTrusted()
                try? await Task.sleep(for: fast ? .milliseconds(120) : .seconds(3))
                guard !Task.isCancelled, self.isRunning else { return }
                let surfacePresent = self.missionControlSurfacePresent()
                // Track the live surface so in-MC interception (handleKey / button
                // clicks) is active exactly while MC is on screen — `beginSession`
                // seeds it true for the AX-expose fast-path, and this keeps it honest.
                self.mcSurfacePresent = surfacePresent
                if surfacePresent {
                    closeMisses = 0
                    if !self.sessionActive { self.beginSession() }
                } else if self.sessionActive {
                    // Surface gone — stop intercepting shortcuts immediately (above),
                    // and tear the session down once it has stayed gone past the
                    // close-miss debounce.
                    closeMisses += 1
                    if closeMisses >= 5 { // ~600 ms gone — a genuine close
                        Log.missionControl.notice("lifecycle-poll: Mission Control gone → end session")
                        self.endSession()
                    }
                }
            }
        }
    }

    /// Re-pick the Y-flip pivot and hide the stale overlay until the now-active
    /// space's window list lands; `trackMouse` rebuilds geometry on the next tick.
    private func resyncSession() {
        pivotHeight = Self.menuBarScreenHeight()
        resetSettleState() // the new space re-tiles — hide until it settles
        hovered = nil
        overlayWindow?.orderOut(nil)
        refreshWindows()
        Log.missionControl.debug("resync: windows=\(self.windows.count, privacy: .public) pivot=\(Int(self.pivotHeight), privacy: .public)")
    }

    /// Idempotent teardown. Note it does **not** touch `spaceObserver` /
    /// `healthTask` — those live for the whole engine lifetime so a re-arm can
    /// still fire after Mission Control closes.
    private func endSession() {
        let wasLive = mouseTask != nil
        sessionActive = false
        mcSurfacePresent = false
        windowFrames = [:]
        capabilityCache = [:]
        backgroundResolveRounds = [:] // in-flight ids clear at merge (guarded by sessionActive)
        awaitFreshHoverAfterClick = false
        resetSettleState()
        lastMouseLocation = nil
        clearReshowSuppression() // MC closed; nothing left to re-show
        mouseTask?.cancel(); mouseTask = nil
        fetchTask?.cancel(); fetchTask = nil
        // NB: do NOT cancel `lifecycleTask` here — it runs for the engine's whole
        // lifetime and is what re-opens the session when MC comes back.
        tap.stop()
        clearOverlayContent()
        hovered = nil
        hoverState.hoveredIndex = nil
        if wasLive { Log.missionControl.notice("session end") }
    }

    /// Reset the settle/sink-watch gate to its session-start state: layout not yet
    /// settled, no consecutive still refreshes counted, and no post-settle re-anchor
    /// watch pending.
    private func resetSettleState() {
        layoutSettled = false
        stableTicks = 0
        sinkWatchTicks = 0
    }

    // MARK: - Recovery observers (Space change / Dock relaunch)

    private func installSpaceObserver() {
        guard spaceObserver == nil else { return }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleActiveSpaceChange() }
        }
    }

    private func removeSpaceObserver() {
        if let spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver)
            self.spaceObserver = nil
        }
    }

    private func handleActiveSpaceChange() {
        guard isRunning else { return }
        Log.missionControl.debug("active space changed → re-arm observer (sessionActive=\(self.sessionActive ? "y" : "n", privacy: .public))")
        // Re-arm the Dock observer: it can stop delivering after a transition into
        // a full-screen app's Space (and re-reading the pid also covers a Dock
        // relaunch). Idempotent + cheap; the next open re-fires through the fresh
        // observer.
        armObserver()
        // Overlay recovery across a Space change is handled uniformly by the
        // re-tile detector in `refreshWindows` (thumbnail-frame churn → rebuild the
        // overlay window once the layout settles), which ALSO covers the
        // no-Space-change boundary swipe that fires no `activeSpaceDidChange`. Here
        // we only hide the now-stale overlay until that settle; the rebuilt window
        // orders in ABOVE the Dock's re-tiled exposé surface (a reused one stays
        // sunk while still reporting a false `visible=y`).
        if sessionActive { resyncSession() }
    }

    private func startHealthPoll() {
        healthTask?.cancel()
        healthTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled, self.isRunning else { return }
                self.checkDockHealth()
            }
        }
    }

    /// Re-arm if the Dock pid changed under us (a crash/restart). Only acts on an
    /// actual change, so it never drops a pending notification by re-arming
    /// needlessly. The full-screen-Space wedge (pid unchanged but the observer
    /// went deaf) is covered separately by the `activeSpaceDidChange` re-arm.
    private func checkDockHealth() {
        let live = MissionControlObserver.currentDockPID()
        let armed = observer.armedDockPID
        guard let live, live != armed else { return }
        Log.missionControl.notice("Dock pid changed \(armed.map(String.init) ?? "nil", privacy: .public)→\(live, privacy: .public) → re-arm observer")
        armObserver()
    }

    private func refreshWindows() {
        let overlayID = overlayWindow.map { CGWindowID($0.windowNumber) }
        // Exclude the Dock by PID: `kCGWindowOwnerName` is LOCALIZED ("程序坞",
        // …), so the name-based exclusion silently misses on every non-English
        // system and the Dock's layer-0 surface joins the hover candidates —
        // hovering it resolves no AX window and the lights go dark. The name
        // set stays as an English-system belt-and-suspenders only.
        let dockPID = MissionControlObserver.currentDockPID()
        windows = enumerator.actionableWindows(
            excludingOwners: ["Dock"],
            excludingPIDs: dockPID.map { [$0] } ?? []
        )
            .filter { window in
                // Never the overlay window itself (it is a high-level window,
                // normally already dropped by the layer-0 filter — belt-and-suspenders).
                guard window.windowID != overlayID else { return false }
                // Keep real foreground apps (.regular) AND menu-bar/agent apps
                // (.accessory / LSUIElement) — the latter still show genuine
                // document/Settings windows as Mission Control thumbnails, so
                // dropping them was a coverage gap. CloseUp's own
                // windows (also .accessory) are included for the same reason. Only
                // .prohibited system surfaces (wallpaper / WindowServer — the stray
                // top-left cluster) are excluded; that coarse gate still matters in
                // the AX-untrusted path, where the capability resolver returns nil.
                return window.ownerPID == ownPID || Self.isOverlayableApp(window.ownerPID)
            }
            // Drop windows CGWindowList transiently reports off-screen while
            // Mission Control re-tiles after a Space switch, so such a mis-placed
            // window can't shadow the real one under the cursor and anchor the
            // overlay off-screen (the "no lights after swiping" bug).
            .anchoredOnScreen(displays: Self.activeDisplayBoundsCG(), inset: OverlayGeometry.edgeInset)

        // Prewarm + heal: resolve capabilities for any not-yet-cached window off
        // the main actor. At session begin this front-loads the per-app AX
        // warm-up (~25–45 ms each) so it is usually done before the first hover;
        // on later ticks it retries blank windows (bounded) and covers windows
        // that appear mid-session. The filter inside makes the steady state a
        // cheap no-op.
        if sessionActive { requestBackgroundResolve(windows) }

        // Gate the overlay on the thumbnail layout being SETTLED, detected by
        // frame churn. The same mechanism covers Mission Control's *enter* animation
        // and any later re-tile (Space switch, boundary swipe, full-screen transition):
        // while the thumbnails are moving the overlay stays hidden — showing it then
        // makes the lights chase the moving window (the "lights appear before MC
        // settles" bug) — and the moment the layout holds still we rebuild the overlay
        // window once (a fresh window orders in ABOVE the Dock's rebuilt exposé surface;
        // a reused one stays sunk and reports a false `visible=y`) and re-anchor it to
        // the settled position. Frame churn is also the only signal that catches the
        // no-Space-change boundary swipe (which fires neither `activeSpaceDidChange` nor
        // an exposé-surface change), and re-anchoring keeps the lights aligned after
        // the animation.
        let newFrames = Dictionary(windows.map { ($0.windowID, $0.frame) }, uniquingKeysWith: { first, _ in first })
        let hadBaseline = !windowFrames.isEmpty
        let churning = ThumbnailLayout.didRetile(from: windowFrames, to: newFrames)
        windowFrames = newFrames
        // The first refresh of a session only establishes the baseline — there is
        // nothing to compare against yet, so it is neither churning nor settled.
        guard sessionActive, hadBaseline else { return }

        if churning {
            // Thumbnails are moving — Mission Control's enter animation or a re-tile.
            // Hide the lights and wait: showing them now makes the overlay chase the
            // moving window (the visible bug). They re-appear once the layout settles.
            stableTicks = 0
            sinkWatchTicks = 0
            if layoutSettled {
                layoutSettled = false
                overlayWindow?.orderOut(nil)
                hovered = nil
                Log.missionControl.debug("layout churning → hide overlay until settle")
            }
        } else if !layoutSettled {
            stableTicks += 1
            if stableTicks >= Self.settleTicks { // held still → MC has finished tiling
                layoutSettled = true
                Log.missionControl.notice("layout settled → show overlay (windows=\(self.windows.count, privacy: .public))")
                // Clear the cursor guard so the very next resolve always shows, even with
                // a stationary cursor (the cursor never moves during an MC swipe). This is
                // what fixes the "lights occasionally don't appear on a normal enter" bug;
                // the unseeded guard then only suppresses redundant re-resolves on later
                // ticks. Applies equally to every re-tile's re-settle within a session.
                lastMouseLocation = nil
                // Re-assert the show for the next ~1.8 s: on a real trackpad swipe the
                // recreate below can leave the overlay hidden, or lose the z-order race
                // while the Dock keeps compositing its surface after the thumbnail
                // frames settled (the single-window case, #3). `trackMouse` re-anchors
                // a fresh window each tick it is hidden, plus at a few forced ticks, so
                // the lights land once the Dock has finished entering.
                sinkWatchTicks = Self.sinkWatchTickBudget
                // Rebuild the overlay window so it composites ABOVE the Dock's settled
                // exposé surface (a window ordered-in before the tiling finished stays
                // sunk while reporting a false `visible=y`), then anchor on the hover.
                recreateOverlayWindow()
                hovered = nil
                trackMouse() // re-anchor on the fresh window now, no inter-tick gap
            }
        }
    }

    /// How many consecutive still refreshes (~100 ms each) mark the layout as
    /// "settled". Two (~200 ms) debounces the enter/re-tile animation's mid-flight
    /// micro-pauses into a single show, with no perceptible delay once MC is at rest.
    private static let settleTicks = 2

    /// How many `trackMouse` ticks (~60 ms each) after a settle to keep re-asserting
    /// the overlay show. ~30 ticks (~1.8 s) comfortably outlasts the Dock finishing
    /// its enter composite on a real trackpad swipe, so a *stationary* cursor
    /// self-heals the fast-enter no-show (#3); after it elapses, only cursor movement
    /// re-checks (steady-state, zero cost).
    private static let sinkWatchTickBudget = 30

    /// Ticks (since settle) at which to re-anchor the overlay UNCONDITIONALLY during
    /// the watch, on top of the every-tick "hidden" recovery. A window we just ordered
    /// front can read as front-most in CGWindowList and as `isVisible` while the Dock
    /// still composites its surface visually over it, so neither the hidden check nor
    /// z-order detection catches that case; these spread-out forced re-anchors land a
    /// fresh window across the range of moments the Dock may finish its composite (#3).
    private static let forcedReanchorTicks: Set<Int> = [6, 14, 22, 28]

    /// Active display bounds in CG (top-left origin) coordinates — the same space
    /// `CGWindowList` frames use — so window frames can be tested for being on a
    /// real display.
    private static func activeDisplayBoundsCG() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { CGDisplayBounds($0) }
    }

    // MARK: - Hover tracking

    private func trackMouse() {
        // Until Mission Control has finished entering (or re-tiling), keep the overlay
        // hidden — otherwise the lights chase the still-moving thumbnails (the visible
        // "lights appear before MC settles" bug). The settle detector in
        // `refreshWindows` flips `layoutSettled` and calls back here to anchor on the
        // now-stable layout.
        guard layoutSettled else { return }
        guard let location = CGEvent(source: nil)?.location else { return }
        let cursorMoved = lastMouseLocation != location
        lastMouseLocation = location
        // Steady-state early-out: the cursor is parked,
        // a window is already resolved, and we are past the post-settle window in which
        // the show could still have failed to paint — so there is nothing to do. We must
        // NOT take this early-out while `sinkWatchTicks > 0` (a stationary cursor over an
        // overlay that didn't paint has to be able to recover, #3) nor while nothing is
        // resolved yet (`hovered == nil`, so a first transient miss keeps retrying).
        if !cursorMoved, hovered != nil, sinkWatchTicks == 0 { return }
        if sinkWatchTicks > 0 { sinkWatchTicks -= 1 }

        // The traffic-light cluster STRADDLES the thumbnail's top edge, so its outer
        // half sits ABOVE the hovered window's frame (`clusterFrameCG.minY` is
        // `windowFrame.minY - buttonSize/2 - clusterPadding`). A cursor moving onto
        // that outer half is no longer "inside" the window per `frontmost(containing:)`,
        // which would resolve to nil (or whatever sits above) and tear the lights down
        // the instant the pointer reaches for the part hanging off the thumbnail — the
        // "lights vanish on the outside half" bug. While the cursor is over the CURRENT
        // overlay's cluster, keep the current window resolved: the cluster belongs to it,
        // so hovering its buttons must never switch or hide it. (`geometry` is non-nil
        // only while that window's lights are shown, and always describes `hovered`.)
        // This matches how a native title bar feels — its controls stay active while
        // the pointer is on the half hanging off the thumbnail's top edge.
        let overCurrentCluster = geometry?.clusterFrameCG.contains(location) ?? false
        // First-acquisition also covers the cluster's straddle band (it hangs
        // `OverlayGeometry.topOverhang` above the thumbnail's top edge), so a
        // window lights up when the cursor first reaches for the off-thumbnail half
        // of its controls — not only once it is already hovered (the
        // `overCurrentCluster` keep-case). Matches the zone the cluster occupies.
        let newHover = (overCurrentCluster && hovered != nil)
            ? hovered
            : windows.frontmost(containing: location, topOverhang: OverlayGeometry.topOverhang)
        if newHover?.windowID != hovered?.windowID {
            Log.missionControl.debug("hover \(self.hovered?.windowID ?? 0, privacy: .public)→\(newHover?.windowID ?? 0, privacy: .public) cgMouse=(\(Int(location.x), privacy: .public),\(Int(location.y), privacy: .public)) windows=\(self.windows.count, privacy: .public)")
            awaitFreshHoverAfterClick = false // a fresh hover — passive re-shows are live again
            hovered = newHover
            repositionOverlay()
        } else if hovered != nil, !suppressOverlayReshow, sinkWatchTicks > 0 {
            // Same window, still inside the post-settle watch. The fast single-window
            // enter (#3) is the case the settle-time show did not actually paint: on a
            // real trackpad swipe `repositionOverlay` runs once but the overlay does not
            // end up on screen (left hidden, or ordered front before the Dock finished
            // compositing its layer-18 surface so it is stacked underneath). The show
            // happens once and, with the cursor parked over the same window (an MC swipe
            // never moves it), nothing re-resolved (windowID unchanged) — so it stayed
            // missing until the hovered window changed (the user's "move out and back"
            // recovery). Re-anchor a FRESH window (make-before-break, blink-free) at a
            // few forced ticks that span when the Dock may finish its composite; a fresh
            // window ordered-in after the surface lands above it. A just-ordered-front
            // window can read as front-most in CGWindowList and as `isVisible` while
            // still visually underneath, so re-anchoring is unconditional rather than
            // gated on a (then-unreliable) on-top check. The forced ticks stop firing
            // once the watch elapses (~1.8 s), by which point the layout is at rest.
            let watchTick = Self.sinkWatchTickBudget - 1 - sinkWatchTicks
            if Self.forcedReanchorTicks.contains(watchTick) {
                Log.missionControl.debug("overlay re-anchor (forced tick=\(watchTick, privacy: .public))")
                reanchorOverlayAboveSurface()
            }
        }
        // The overlay window ignores mouse events, so drive per-button hover
        // from here. Only assign on change to avoid 60 Hz re-render churn.
        let index = geometry?.hitTest(location)
        if hoverState.hoveredIndex != index { hoverState.hoveredIndex = index }
    }

    /// Re-anchor the overlay ABOVE the Dock's exposé surface without a visible blink:
    /// build a FRESH window and order it in now (a window ordered-in after the surface
    /// has settled lands on top — the same reason `recreateOverlayWindow` fixes the
    /// re-tile sink), then order out and close the sunk old window only AFTER the new
    /// one is showing (make-before-break), so the lights never flicker.
    private func reanchorOverlayAboveSurface() {
        guard !suppressOverlayReshow, hovered != nil else { return }
        let old = overlayWindow
        overlayWindow = nil
        ensureOverlayWindow()
        repositionOverlay() // fills content + frame and orders the fresh window front
        old?.orderOut(nil)
        old?.close()
    }

    private func repositionOverlay() {
        // A pass-through click is dismissing Mission Control; keep the overlay hidden
        // through the exit animation's frame churn so it doesn't flash back on (often
        // at a garbage top-left position) before the session ends.
        guard !suppressOverlayReshow else {
            overlayWindow?.orderOut(nil)
            return
        }
        guard let hovered, let window = overlayWindow else {
            clearOverlayContent()
            return
        }
        // Settings-enabled actions narrowed to the controls this window actually
        // has (resolved via AX). A popover / sheet / chrome-less panel exposes no
        // title-bar buttons → empty → no overlay (fixes lights on popups). When
        // Accessibility is unavailable the policy display is nil and we fall back
        // to showing every enabled action (the legacy no-AX behaviour).
        // CACHE-FIRST: a window resolved once this session pays zero AX IPC here
        // — the session prewarm usually fills the cache before the first hover,
        // so a hover change shows in the same tick with no app round-trip. On a
        // miss, resolve synchronously (bounded by the 1 s global AX messaging
        // cap); a blank outcome is healed by the bounded background retries,
        // whose merge re-shows this window the moment real buttons resolve.
        let requested = actionsProvider()
        let effective: WindowCapabilities?
        if let cached = capabilityCache[hovered.windowID] {
            effective = cached
        } else {
            let outcome = OverlayCapabilityPolicy.outcome(for: capabilityResolver.resolution(for: hovered))
            if let cache = outcome.cache { capabilityCache[hovered.windowID] = cache }
            if outcome.retry { requestBackgroundResolve([hovered]) }
            effective = outcome.display
        }
        let actions = effective?.supported(from: requested) ?? requested
        guard !actions.isEmpty else {
            clearOverlayContent()
            return
        }
        currentActions = actions
        let geo = OverlayGeometry(windowFrame: hovered.frame, actionCount: actions.count, pivotHeight: pivotHeight)
        geometry = geo
        // Size the window to the cluster BEFORE mounting the SwiftUI content, so the
        // freshly-built `NSHostingView` is born at its FINAL bounds. The old order
        // (mount content, then grow the window) let the hosting view first lay the
        // buttons out inside a `.zero` content rect — all collapsed at the top-left
        // origin — and SwiftUI then animated them out to the row as the window grew:
        // the "lights fly in from the top-left" bug (probabilistic, since it only shows
        // when the collapsed first layout gets composited before the resize lands).
        // `display: false` defers the redraw so no stale frame paints at the new size;
        // `orderFront` then shows the already-laid-out content in one shot.
        window.setFrame(geo.nsWindowFrame, display: false)
        setOverlayContent(actions)
        window.orderFront(nil)
        let f = geo.nsWindowFrame
        Log.missionControl.debug("overlay show win=\(window.windowNumber, privacy: .public) actions=\(actions.count, privacy: .public) ns=(\(Int(f.minX), privacy: .public),\(Int(f.minY), privacy: .public) \(Int(f.width), privacy: .public)x\(Int(f.height), privacy: .public)) visible=\(window.isVisible ? "y" : "n", privacy: .public) onActiveSpace=\(window.isOnActiveSpace ? "y" : "n", privacy: .public) screen=\(window.screen != nil ? "y" : "n", privacy: .public)")
    }

    // MARK: - Background capability resolution (prewarm + heal)

    /// Queue an off-main-actor capability resolve for any of `candidates` not
    /// already cached, in flight, or out of retry budget. Two jobs share this:
    /// the session PREWARM (all windows, from `refreshWindows`) that moves the
    /// per-app AX warm-up cost off the hover path, and the bounded RETRY loop
    /// that heals a window whose resolve came back blank — transiently-failing
    /// windows used to stay dark until the cursor left and came back, because
    /// nothing on the tick path re-resolves a parked hover.
    private func requestBackgroundResolve(_ candidates: [WindowInfo]) {
        let fresh = candidates.filter { window in
            capabilityCache[window.windowID] == nil
                && !backgroundResolveInFlight.contains(window.windowID)
                && backgroundResolveRounds[window.windowID, default: 0] < Self.maxBackgroundResolveRounds
        }
        guard !fresh.isEmpty else { return }
        for window in fresh { backgroundResolveInFlight.insert(window.windowID) }
        let generation = sessionGeneration
        // Detached: the batch resolve blocks its thread on AX IPC (bounded by
        // the 1 s global cap per read) — exactly what must never run on the
        // MainActor. Results and inputs are Sendable value types.
        Task.detached(priority: .userInitiated) { [weak self] in
            let resolutions = AccessibilityCapabilityResolver.resolutions(for: fresh)
            await MainActor.run { self?.mergeBackgroundResolutions(resolutions, generation: generation) }
        }
    }

    /// Fold one background batch into the session cache, and re-show the hovered
    /// window if it just resolved real buttons while displaying nothing — a
    /// parked cursor never re-resolves on the tick path (the steady-state
    /// early-out), so this merge is what heals the stuck-dark hover.
    private func mergeBackgroundResolutions(_ resolutions: [CGWindowID: CapabilityResolution], generation: Int) {
        for id in resolutions.keys { backgroundResolveInFlight.remove(id) }
        guard sessionActive, generation == sessionGeneration else { return }
        var hoveredResolved = false
        for (id, resolution) in resolutions {
            if case .unavailable = resolution {
                // AX untrusted: no background resolve can ever succeed, so burn
                // the whole retry budget — otherwise the fetch tick re-queues
                // every window every ~100 ms for the entire untrusted session.
                backgroundResolveRounds[id] = Self.maxBackgroundResolveRounds
                continue
            }
            let outcome = OverlayCapabilityPolicy.outcome(for: resolution)
            if let cache = outcome.cache {
                if capabilityCache[id] == nil {
                    capabilityCache[id] = cache
                    // Heal only a hover that was never shown: a window that was
                    // shown (and possibly just clicked) was necessarily cached
                    // by the sync hover path already, so its merge write is
                    // skipped and it can never re-trigger a show from here —
                    // defense in depth alongside `awaitFreshHoverAfterClick`.
                    if id == hovered?.windowID { hoveredResolved = true }
                }
                backgroundResolveRounds[id] = nil
            } else if outcome.retry {
                backgroundResolveRounds[id, default: 0] += 1 // blank — spend one retry round
            }
        }
        // NB `awaitFreshHoverAfterClick`: never re-light the window the user
        // just clicked a button on — that re-show belongs to the next fresh
        // hover only (the "post-click flash" rule).
        if hoveredResolved, layoutSettled, geometry == nil, !suppressOverlayReshow, !awaitFreshHoverAfterClick {
            repositionOverlay()
        }
    }

    /// Hide the overlay window and drop the resolved geometry + action mapping. The
    /// shared "clear the overlay" sequence for the no-window / no-actions paths.
    private func clearOverlayContent() {
        overlayWindow?.orderOut(nil)
        geometry = nil
        currentActions = []
    }

    // MARK: - Click & key handling

    /// If `point` lands on a traffic-light button (and Mission Control is genuinely
    /// open), perform that action, hide the overlay, and return `true` (consumed).
    /// Returns `false` with no side effects when it was not a button hit. MC stays
    /// open, so we do NOT latch — the lights re-appear on the next *fresh* hover,
    /// letting the user keep managing windows (close one, hover the next).
    private func performButtonHit(at point: CGPoint) -> Bool {
        guard mcSurfacePresent, let geometry, let hovered,
              let index = geometry.hitTest(point), index < currentActions.count
        else { return false }
        perform(currentActions[index], on: hovered)
        hideOverlay()
        return true
    }

    private func handleClick(at point: CGPoint) -> Bool {
        // A traffic-light button hit consumes the click (swallow so MC never sees it).
        if performButtonHit(at: point) { return false }
        // Any other left click is the user dismissing Mission Control (clicking a
        // thumbnail to switch windows, or empty space). Hide the lights instantly
        // AND suppress re-show through MC's exit animation so they don't flash back
        // on at a garbage position before `endSession`. Then pass through so Mission
        // Control still handles it (switch / exit).
        suppressOverlayReshow = true
        scheduleSuppressReshowClear()
        hideOverlay()
        return true // pass through — Mission Control handles the click
    }

    /// A middle / other-button click, routed through the SAME button hit-test as a
    /// left click (so a middle-click on a control acts on it): it acts only as a
    /// button hit. A miss passes through WITHOUT the left-click's dismiss side
    /// effects — a middle-click on empty space must not tear Mission Control's
    /// overlay down.
    private func handleSecondaryClick(at point: CGPoint) -> Bool {
        performButtonHit(at: point) ? false : true
    }

    /// Fallback clear for `suppressOverlayReshow`. A real MC close clears it sooner
    /// via `endSession` (which also cancels this task), so in the common click-to-exit
    /// case this timer never fires. It only matters when a pass-through click leaves
    /// Mission Control *open* (e.g. clicking empty space), letting the lights recover
    /// on the next hover instead of staying off for the whole session. Sized (2 s) to
    /// comfortably outlast the exit animation + the ~600 ms close-poll so it can never
    /// fire mid-exit and re-flash the overlay.
    private func scheduleSuppressReshowClear() {
        suppressReshowTask?.cancel()
        suppressReshowTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(2000))
            guard let self, !Task.isCancelled else { return }
            self.suppressOverlayReshow = false
            // A hover that landed DURING the suppression window updated `hovered`
            // but never resolved/showed (repositionOverlay early-returns while
            // suppressed), and a parked cursor never re-triggers it — the second
            // stuck-dark variant. Re-resolve now so the lights recover in place
            // instead of requiring the cursor to leave the window and come back.
            // `awaitFreshHoverAfterClick` keeps the window the click actually
            // landed on dark until a fresh hover (the "post-click flash" rule) —
            // this re-show is only for a hover that CHANGED during suppression.
            if self.sessionActive, self.layoutSettled, self.hovered != nil, self.geometry == nil,
               !self.awaitFreshHoverAfterClick {
                self.repositionOverlay()
            }
        }
    }

    /// Clear the post-click re-show suppression and cancel its safety timer. Called
    /// at every session boundary so the flag can never leak across sessions.
    private func clearReshowSuppression() {
        suppressOverlayReshow = false
        suppressReshowTask?.cancel()
        suppressReshowTask = nil
    }

    /// Order the overlay out immediately on a click and drop the geometry/action
    /// mapping so a follow-up click in the same spot can't re-trigger a now-hidden
    /// button. Keeps `hovered` so a same-window tick doesn't re-show the lights.
    private func hideOverlay() {
        clearOverlayContent()
        hoverState.hoveredIndex = nil
        // Passive re-shows (background-resolve merge, suppression-clear timer)
        // must not re-light the just-clicked window; only the next fresh hover
        // may (`trackMouse` clears this on a windowID change).
        awaitFreshHoverAfterClick = true
        // End the post-settle re-anchor watch: a click means the overlay was up and the
        // user acted, so the fast-enter no-show (#3) is already resolved for this
        // session. Without this, a forced re-anchor tick would rebuild and re-show the
        // lights on the just-acted window for a tick (a button hit keeps `hovered` and
        // deliberately does not suppress) — the "post-click flash" this rule prevents.
        sinkWatchTicks = 0
        Log.missionControl.debug("overlay hidden on click")
    }

    private func handleKey(_ keyCode: CGKeyCode, _ flags: CGEventFlags) -> Bool {
        // Intercept in-MC shortcuts ONLY while Mission Control is actually on screen.
        // The tap lingers through the ~600 ms close-miss debounce after MC exits, so
        // without this a ⌘W/⌥⌘W in that tail would be swallowed and acted on the stale
        // hovered thumbnail. Pass the key through once the surface is gone.
        guard mcSurfacePresent else { return true }
        for shortcut in MissionControlShortcut.allCases {
            guard let chord = chordProvider(shortcut), chord.matches(keyCode: keyCode, flags: flags) else { continue }
            apply(shortcut)
            return false // swallow — the shortcut consumed the key
        }
        return true
    }

    private func apply(_ shortcut: MissionControlShortcut) {
        let action = shortcut.windowAction
        if shortcut.isBatch {
            // Every batch action is relative to the hovered window; with nothing
            // under the cursor there is no target, so beep (the key is swallowed)
            // rather than silently acting on every window — the standard macOS
            // signal for a hot key that had no effect.
            guard let hovered else { NSSound.beep(); return }
            switch shortcut {
            case .hideAllExceptHovered:
                // Hide every OTHER regular app system-wide — not just the apps that
                // happen to have a captured Mission Control thumbnail — excluding the
                // hovered app and CloseUp itself. Like the system Hide-Others (⌥⌘H),
                // iterate `NSWorkspace.runningApplications`, not the window capture.
                for app in NSWorkspace.shared.runningApplications
                where app.activationPolicy == .regular
                    && app.processIdentifier != hovered.ownerPID
                    && app.processIdentifier != ownPID {
                    app.hide()
                }
            case .closeAll, .minimizeAll:
                // Close / minimize the HOVERED app's full window list (its AXWindows,
                // reaching minimized / other-Space windows too), and ONLY the hovered
                // app — never every app's windows (that cross-app close-everything was a
                // data-loss footgun, fixed). ⌥⌘W close-all and ⌥⌘M minimize-all are a
                // symmetric pair, mirroring "Hide All but This".
                performer.performOnAllWindows(action, ofApp: hovered.ownerPID)
            default:
                break
            }
        } else if let hovered {
            perform(action, on: hovered)
        } else {
            // A gated single-window shortcut fired with no window under the cursor;
            // the key was swallowed, so signal the no-op with the standard beep.
            NSSound.beep()
        }
    }

    private func perform(_ action: WindowAction, on window: WindowInfo) {
        if action == .zoom {
            // Zoom brings the window forward, so settle Mission Control first.
            performer.wakeMissionControl()
            overlayWindow?.orderOut(nil)
        }
        performer.perform(action, on: window)
    }

    // MARK: - Overlay window

    private func ensureOverlayWindow() {
        guard overlayWindow == nil else { return }
        let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .screenSaver // above the Dock-drawn Mission Control surface
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true // fully passive — the event tap is the only click handler
        window.isReleasedWhenClosed = false
        // NB: do NOT add `.transient` — the system hides transient windows during
        // Mission Control gestures, so a 3-finger swipe (even one that doesn't
        // change Space, e.g. swiping past the last desktop) would hide the overlay
        // for the rest of the MC session and the lights would vanish on every
        // window until MC was reopened. `.canJoinAllSpaces` makes it follow across
        // desktops; `.ignoresCycle` keeps it out of window cycling. (OpenMissionControl
        // sets no collection behavior at all and is immune to this.)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        overlayWindow = window
    }

    private func setOverlayContent(_ actions: [WindowAction]) {
        overlayWindow?.contentView = NSHostingView(rootView: OverlayClusterView(actions: actions, locale: localeProvider(), hoverState: hoverState))
    }

    /// Tear the overlay window down and let `ensureOverlayWindow` build a fresh
    /// one. Called when a Mission Control re-tile settles (`refreshWindows`): the
    /// old window has sunk behind the Dock's rebuilt exposé surface, so only a
    /// window ordered-in *after* the re-tile composites above it. `repositionOverlay`
    /// re-fills the content and orders the new window front on the next hover tick.
    private func recreateOverlayWindow() {
        overlayWindow?.orderOut(nil)
        overlayWindow?.close()
        overlayWindow = nil
        ensureOverlayWindow()
    }

    // MARK: - Screen geometry

    /// Whether the window's owning app should get overlay controls: a normal
    /// foreground app (`.regular`) or a menu-bar/agent app (`.accessory`,
    /// LSUIElement) — both of which can show real, closable windows as Mission
    /// Control thumbnails. Excludes `.prohibited` system processes (WindowServer,
    /// wallpaper) and pids with no running app, which draw chrome-less surfaces
    /// with nothing to act on.
    private static func isOverlayableApp(_ pid: pid_t) -> Bool {
        switch NSRunningApplication(processIdentifier: pid)?.activationPolicy {
        case .regular, .accessory: return true
        default: return false
        }
    }

    /// Height of the screen at the AppKit coordinate origin (the menu-bar
    /// screen) — the pivot for the CoreGraphics↔AppKit Y flip.
    private static func menuBarScreenHeight() -> CGFloat {
        if let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) {
            return primary.frame.height
        }
        return NSScreen.main?.frame.height ?? 0
    }
}
