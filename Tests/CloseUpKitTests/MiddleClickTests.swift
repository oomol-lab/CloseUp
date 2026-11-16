import CoreGraphics
import Testing

@testable import CloseUpKit

@Suite("MiddleClickPolicy")
struct MiddleClickPolicyTests {
    private let window = WindowInfo(
        windowID: 7, ownerPID: 100, ownerName: "Finder",
        frame: CGRect(x: 100, y: 200, width: 400, height: 300)
    )

    /// A context in which a middle-click on `window`'s thumbnail closes it; each
    /// test flips exactly one input away from this baseline.
    private func context(
        surfacePresent: Bool = true,
        layoutSettled: Bool = true,
        dismissing: Bool = false,
        closesWindows: Bool = true,
        buttonHit: MiddleClickTarget? = nil,
        windowAtPoint: WindowInfo? = nil,
        windowCanClose: Bool = true
    ) -> MiddleClickContext {
        MiddleClickContext(
            surfacePresent: surfacePresent,
            layoutSettled: layoutSettled,
            dismissing: dismissing,
            closesWindows: closesWindows,
            buttonHit: buttonHit,
            windowAtPoint: windowAtPoint ?? window,
            windowCanClose: windowCanClose
        )
    }

    @Test("only button 2 is the middle button — side buttons (3/4) are not")
    func middleButtonOnly() {
        #expect(MiddleClickPolicy.isMiddleButton(2))
        #expect(!MiddleClickPolicy.isMiddleButton(0))
        #expect(!MiddleClickPolicy.isMiddleButton(1))
        #expect(!MiddleClickPolicy.isMiddleButton(3))
        #expect(!MiddleClickPolicy.isMiddleButton(4))
    }

    @Test("a middle-click on a closable thumbnail targets that window")
    func thumbnailCloses() {
        #expect(MiddleClickPolicy.target(for: context()) == .window(window))
    }

    @Test("nothing is targeted once Mission Control's surface is gone")
    func surfaceGone() {
        #expect(MiddleClickPolicy.target(for: context(surfacePresent: false)) == nil)
        let hit = MiddleClickTarget.button(index: 0, windowID: 7)
        #expect(MiddleClickPolicy.target(for: context(surfacePresent: false, buttonHit: hit)) == nil)
    }

    @Test("a traffic-light hit wins over the thumbnail underneath it")
    func buttonHitWins() {
        let hit = MiddleClickTarget.button(index: 1, windowID: 7)
        #expect(MiddleClickPolicy.target(for: context(buttonHit: hit)) == hit)
    }

    @Test("a traffic-light hit still acts with the close-on-middle-click setting off")
    func buttonHitIgnoresSetting() {
        let hit = MiddleClickTarget.button(index: 0, windowID: 7)
        #expect(MiddleClickPolicy.target(for: context(closesWindows: false, buttonHit: hit)) == hit)
    }

    @Test("the setting off leaves a thumbnail middle-click alone")
    func settingOff() {
        #expect(MiddleClickPolicy.target(for: context(closesWindows: false)) == nil)
    }

    // Mission Control treats a middle-click it receives on a thumbnail as
    // SELECTING that window (it exits and switches). So a click the policy
    // declines for safety must be consumed (`.blocked`), never passed through.

    @Test("moving thumbnails are never closed — the click is consumed, not passed on")
    func unsettledLayout() {
        #expect(MiddleClickPolicy.target(for: context(layoutSettled: false)) == .blocked)
    }

    @Test("an unsettled layout blocks even where no thumbnail is known — the frames are stale")
    func unsettledEmptySpace() {
        #expect(MiddleClickPolicy.target(for: emptySpace(layoutSettled: false)) == .blocked)
    }

    @Test("a click while Mission Control is being dismissed is consumed")
    func dismissing() {
        #expect(MiddleClickPolicy.target(for: context(dismissing: true)) == .blocked)
    }

    @Test("a window without a known close button is not closed — and not selected either")
    func cannotClose() {
        #expect(MiddleClickPolicy.target(for: context(windowCanClose: false)) == .blocked)
    }

    @Test("settled empty space is left to Mission Control")
    func settledEmptySpace() {
        #expect(MiddleClickPolicy.target(for: emptySpace(layoutSettled: true)) == nil)
    }

    @Test("with the setting off nothing is blocked — middle-click stays fully native")
    func settingOffNeverBlocks() {
        #expect(MiddleClickPolicy.target(for: context(layoutSettled: false, closesWindows: false)) == nil)
        #expect(MiddleClickPolicy.target(for: context(closesWindows: false, windowCanClose: false)) == nil)
    }

    private func emptySpace(layoutSettled: Bool) -> MiddleClickContext {
        MiddleClickContext(
            surfacePresent: true, layoutSettled: layoutSettled, dismissing: false,
            closesWindows: true, buttonHit: nil, windowAtPoint: nil, windowCanClose: false
        )
    }
}

@Suite("MiddleClickPairing")
struct MiddleClickPairingTests {
    private let a = MiddleClickTarget.window(WindowInfo(
        windowID: 1, ownerPID: 10, ownerName: "A",
        frame: CGRect(x: 0, y: 0, width: 100, height: 100)
    ))
    private let b = MiddleClickTarget.window(WindowInfo(
        windowID: 2, ownerPID: 20, ownerName: "B",
        frame: CGRect(x: 200, y: 0, width: 100, height: 100)
    ))

    @Test("press and release on the same target fires it and swallows both")
    func sameTargetFires() {
        var pairing = MiddleClickPairing()
        let pressed = pairing.press(a)
        #expect(pressed)
        let released = pairing.release(a)
        #expect(released == .init(swallow: true, fire: a))
    }

    @Test("a press on nothing passes through, and so does its release")
    func missPassesThrough() {
        var pairing = MiddleClickPairing()
        let pressed = pairing.press(nil)
        #expect(!pressed)
        let released = pairing.release(a)
        #expect(released == .init(swallow: false, fire: nil))
    }

    @Test("releasing on a different target cancels, but still swallows the release")
    func differentTargetCancels() {
        var pairing = MiddleClickPairing()
        let pressed = pairing.press(a)
        #expect(pressed)
        let released = pairing.release(b)
        #expect(released == .init(swallow: true, fire: nil))
    }

    @Test("releasing off every target cancels, but still swallows the release")
    func releaseOnNothingCancels() {
        var pairing = MiddleClickPairing()
        let pressed = pairing.press(a)
        #expect(pressed)
        let released = pairing.release(nil)
        #expect(released == .init(swallow: true, fire: nil))
    }

    @Test("a thumbnail that moved between press and release is not closed")
    func movedThumbnailCancels() {
        var pairing = MiddleClickPairing()
        let moved = MiddleClickTarget.window(WindowInfo(
            windowID: 1, ownerPID: 10, ownerName: "A",
            frame: CGRect(x: 40, y: 0, width: 100, height: 100)
        ))
        let pressed = pairing.press(a)
        #expect(pressed)
        let released = pairing.release(moved)
        #expect(released == .init(swallow: true, fire: nil))
    }

    @Test("a blocked press is swallowed whole and never turns into a close on release")
    func blockedNeverCloses() {
        var pairing = MiddleClickPairing()
        let pressed = pairing.press(.blocked)
        #expect(pressed)
        // The layout settled between press and release: still no close.
        let released = pairing.release(a)
        #expect(released == .init(swallow: true, fire: nil))
    }

    @Test("a release fires at most once")
    func firesOnce() {
        var pairing = MiddleClickPairing()
        let pressed = pairing.press(a)
        #expect(pressed)
        _ = pairing.release(a)
        let released = pairing.release(a)
        #expect(released == .init(swallow: false, fire: nil))
    }

    @Test("a miss press disarms an earlier press whose release never arrived")
    func missDisarms() {
        var pairing = MiddleClickPairing()
        let pressed = pairing.press(a)
        #expect(pressed)
        let repressed = pairing.press(nil)
        #expect(!repressed)
        let released = pairing.release(a)
        #expect(released == .init(swallow: false, fire: nil))
    }

    @Test("reset drops an armed press")
    func reset() {
        var pairing = MiddleClickPairing()
        let pressed = pairing.press(a)
        #expect(pressed)
        pairing.reset()
        let released = pairing.release(a)
        #expect(released == .init(swallow: false, fire: nil))
    }
}
