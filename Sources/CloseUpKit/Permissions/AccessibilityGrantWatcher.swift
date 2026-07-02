import ApplicationServices

/// Watches for the Accessibility grant after the user has been sent to System
/// Settings. macOS sends no notification when access is allowed, so the only way
/// to react promptly is to poll `AXIsProcessTrusted()` ourselves.
///
/// The trust check is injectable so the polling behaviour can be tested without
/// touching the real (SIP-protected, GUI-only) Accessibility permission.
@MainActor
public final class AccessibilityGrantWatcher {
    private var task: Task<Void, Never>?
    private let pollInterval: Duration
    private let isTrusted: () -> Bool

    public init(
        pollInterval: Duration = .milliseconds(500),
        isTrusted: @escaping () -> Bool = { AXIsProcessTrusted() }
    ) {
        self.pollInterval = pollInterval
        self.isTrusted = isTrusted
    }

    /// True while a poll loop is active.
    public var isRunning: Bool { task != nil }

    /// Begin polling. `onGranted` is invoked exactly once, on the main actor, the
    /// first time the trust check passes, after which the watcher stops. Calling
    /// `start` while already running is a no-op.
    public func start(onGranted: @escaping () -> Void) {
        guard task == nil else { return }
        let pollInterval = pollInterval
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: pollInterval)
                guard let self, !Task.isCancelled else { return }
                guard self.isTrusted() else { continue }
                self.task = nil
                onGranted()
                return
            }
        }
    }

    /// Stop polling without firing `onGranted` (e.g. the user navigated away).
    public func stop() {
        task?.cancel()
        task = nil
    }

    deinit {
        // `Task` is Sendable, so cancelling from deinit is safe.
        task?.cancel()
    }
}
