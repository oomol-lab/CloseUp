import AppKit
import ApplicationServices

/// Observes Mission Control / Exposé open & close by registering an `AXObserver`
/// on the Dock process for the `AXExpose*` notifications. The Dock renders
/// Mission Control, so its AX element is where these fire. No polling.
///
/// The C callback runs on the main run loop (the observer's source is added
/// there), so it re-enters the main actor with `assumeIsolated`.
@MainActor
public final class MissionControlObserver {
    private var observer: AXObserver?
    private var dockElement: AXUIElement?
    private var onChange: ((MissionControlState) -> Void)?

    /// The Dock pid this observer is currently bound to (`nil` when not armed).
    /// The engine polls `Self.currentDockPID()` against this to detect a Dock
    /// relaunch — the Dock is an agent, so `NSWorkspace` posts no launch/terminate
    /// notification for it, making a pid diff the only reliable signal.
    public private(set) var armedDockPID: pid_t?

    public init() {}

    /// The live Dock pid right now, or `nil` if the Dock isn't running.
    public static func currentDockPID() -> pid_t? { dockPID() }

    /// Begin observing. `onChange` fires on the main actor for *every* expose
    /// notification the Dock posts — the caller is expected to reconcile
    /// idempotently, so no de-duplication happens here (a dropped/coalesced
    /// `AXExposeExit` must never be able to wedge a later open). A no-op if
    /// already observing or the Dock can't be found.
    public func start(onChange: @escaping (MissionControlState) -> Void) {
        guard observer == nil else { return }
        self.onChange = onChange

        guard let dockPID = Self.dockPID() else {
            Log.missionControl.error("observer arm failed: Dock process not found")
            return
        }

        let element = AXUIElementCreateApplication(dockPID)
        dockElement = element

        var created: AXObserver?
        guard AXObserverCreate(dockPID, missionControlObserverCallback, &created) == .success,
              let created
        else {
            Log.missionControl.error("observer arm failed: AXObserverCreate (dockPID=\(dockPID, privacy: .public))")
            return
        }
        observer = created

        // Observing another process's AX notifications requires this process to
        // be Accessibility-trusted; without it `AXObserverAddNotification` fails
        // (typically `.apiDisabled`) and the observer is silently deaf. Surface
        // both signals so a "no overlay" report is diagnosable from the log alone.
        let trusted = AXIsProcessTrusted()
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var addErrors: [String] = []
        for state in MissionControlState.allCases {
            let err = AXObserverAddNotification(created, element, state.rawValue as CFString, refcon)
            if err != .success { addErrors.append("\(state.rawValue)=\(err.rawValue)") }
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        armedDockPID = dockPID
        if addErrors.isEmpty {
            Log.missionControl.notice("observer armed (dockPID=\(dockPID, privacy: .public), trusted=\(trusted ? "y" : "n", privacy: .public))")
        } else {
            Log.missionControl.error("observer armed BUT AddNotification failed (dockPID=\(dockPID, privacy: .public), trusted=\(trusted ? "y" : "n", privacy: .public)): \(addErrors.joined(separator: ","), privacy: .public)")
        }
    }

    public func stop() {
        if let observer, let dockElement {
            for state in MissionControlState.allCases {
                AXObserverRemoveNotification(observer, dockElement, state.rawValue as CFString)
            }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            Log.missionControl.debug("observer stopped")
        }
        observer = nil
        dockElement = nil
        onChange = nil
        armedDockPID = nil
    }

    fileprivate func handle(_ rawNotification: String) {
        guard let state = MissionControlState(rawValue: rawNotification) else { return }
        Log.missionControl.debug("expose notification: \(rawNotification, privacy: .public)")
        onChange?(state)
    }

    private static func dockPID() -> pid_t? {
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == "com.apple.dock" }?
            .processIdentifier
    }
}

/// Top-level C callback required by `AXObserverCreate`. Fires on the main run
/// loop; recovers the observer from `refcon` and forwards on the main actor.
private func missionControlObserverCallback(
    _: AXObserver,
    _: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let observer = Unmanaged<MissionControlObserver>.fromOpaque(refcon).takeUnretainedValue()
    let name = notification as String
    MainActor.assumeIsolated {
        observer.handle(name)
    }
}
