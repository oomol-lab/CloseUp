import Testing

@testable import CloseUpKit

@Suite("AccessibilityGrantWatcher")
@MainActor
struct AccessibilityGrantWatcherTests {
    @Test("fires onGranted exactly once when trust flips, then stops")
    func firesOnceOnGrant() async {
        var trusted = false
        var grantCount = 0
        let watcher = AccessibilityGrantWatcher(pollInterval: .milliseconds(5)) { trusted }

        watcher.start { grantCount += 1 }
        #expect(watcher.isRunning)

        // Flip to trusted; the next poll should fire and stop.
        trusted = true
        try? await Task.sleep(for: .milliseconds(60))

        #expect(grantCount == 1)
        #expect(!watcher.isRunning)
    }

    @Test("stop cancels without firing")
    func stopWithoutFiring() async {
        var grantCount = 0
        let watcher = AccessibilityGrantWatcher(pollInterval: .milliseconds(5)) { false }
        watcher.start { grantCount += 1 }
        watcher.stop()
        try? await Task.sleep(for: .milliseconds(30))
        #expect(grantCount == 0)
        #expect(!watcher.isRunning)
    }

    @Test("start while running is a no-op")
    func doubleStart() async {
        let watcher = AccessibilityGrantWatcher(pollInterval: .milliseconds(5)) { false }
        watcher.start {}
        watcher.start {} // must not crash or spawn a second loop
        #expect(watcher.isRunning)
        watcher.stop()
    }
}
