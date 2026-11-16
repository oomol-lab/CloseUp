import CoreGraphics

/// A session-level `CGEvent` tap over clicks and key-downs, used while
/// Mission Control is open to act on the overlay buttons and shortcuts. Handlers
/// return `true` to pass the event through to Mission Control, `false` to swallow
/// it (a button/shortcut was consumed) — so the overlay is otherwise passive and
/// never steals Mission Control's own Esc / arrow-key handling.
///
/// The tap callback runs on the main run loop, so it re-enters the main actor
/// synchronously with `assumeIsolated` to compute the pass/swallow decision.
@MainActor
public final class EventTap {
    public struct Handlers {
        /// Left-mouse-down at a CG-space point. Return `true` to pass through.
        public var onClick: (CGPoint) -> Bool
        /// Other-button (2 = middle, 3+ = side buttons) press at a CG-space
        /// point, with its `mouseEventButtonNumber`. Return `true` to pass through.
        public var onOtherMouseDown: (CGPoint, Int64) -> Bool
        /// The matching other-button release. Return `true` to pass through. A
        /// handler that swallowed the press must swallow its release too, so
        /// Mission Control never receives half a click.
        public var onOtherMouseUp: (CGPoint, Int64) -> Bool
        /// Key-down. Return `true` to pass through.
        public var onKey: (CGKeyCode, CGEventFlags) -> Bool

        public init(
            onClick: @escaping (CGPoint) -> Bool,
            onOtherMouseDown: @escaping (CGPoint, Int64) -> Bool = { _, _ in true },
            onOtherMouseUp: @escaping (CGPoint, Int64) -> Bool = { _, _ in true },
            onKey: @escaping (CGKeyCode, CGEventFlags) -> Bool
        ) {
            self.onClick = onClick
            self.onOtherMouseDown = onOtherMouseDown
            self.onOtherMouseUp = onOtherMouseUp
            self.onKey = onKey
        }
    }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    fileprivate var handlers: Handlers?

    public init() {}

    /// Create and enable the tap. Returns `false` if the tap couldn't be created
    /// (Accessibility not granted).
    @discardableResult
    public func start(handlers: Handlers) -> Bool {
        guard tap == nil else { return true }
        self.handlers = handlers

        let mask = (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.otherMouseUp.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            self.handlers = nil
            Log.eventTap.error("tap create failed (Accessibility not granted?)")
            return false
        }
        tap = created
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: created, enable: true)
        return true
    }

    public func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
        handlers = nil
    }

    fileprivate func reenable() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    /// Synchronous dispatch from the C callback (already on the main thread).
    /// The non-`Sendable` `CGEvent` is read into plain values *before* hopping
    /// onto the main actor, so only `Sendable` data crosses the boundary.
    nonisolated fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        switch type {
        case .leftMouseDown:
            let location = event.location
            return MainActor.assumeIsolated { handlers?.onClick(location) ?? true }
        case .otherMouseDown:
            let location = event.location
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            return MainActor.assumeIsolated { handlers?.onOtherMouseDown(location, button) ?? true }
        case .otherMouseUp:
            let location = event.location
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            return MainActor.assumeIsolated { handlers?.onOtherMouseUp(location, button) ?? true }
        case .keyDown:
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            return MainActor.assumeIsolated { handlers?.onKey(keyCode, flags) ?? true }
        default:
            return true
        }
    }

    nonisolated fileprivate func reenableFromCallback() {
        MainActor.assumeIsolated { reenable() }
    }
}

/// Top-level C callback for the event tap. Re-enables the tap if the system
/// disabled it (timeout / user input), otherwise asks the owner whether to pass
/// the event through.
private func eventTapCallback(
    proxy _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        Log.eventTap.notice("tap disabled by system (\(type == .tapDisabledByTimeout ? "timeout" : "userInput", privacy: .public)) → re-enabling")
        tap.reenableFromCallback()
        return Unmanaged.passUnretained(event)
    }

    return tap.handle(type: type, event: event) ? Unmanaged.passUnretained(event) : nil
}
