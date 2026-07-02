import CoreGraphics
import Testing

@testable import CloseUpKit

@Suite("ThumbnailLayout")
struct ThumbnailLayoutTests {
    private let a = CGRect(x: 100, y: 200, width: 400, height: 300)
    private let b = CGRect(x: 600, y: 200, width: 400, height: 300)

    @Test("an empty baseline (a session's first refresh) is never a re-tile")
    func emptyBaseline() {
        #expect(!ThumbnailLayout.didRetile(from: [:], to: [1: a, 2: b]))
    }

    @Test("an identical frame set reads as settled")
    func identicalSettles() {
        let frames: [CGWindowID: CGRect] = [1: a, 2: b]
        #expect(!ThumbnailLayout.didRetile(from: frames, to: frames))
    }

    @Test("a thumbnail appearing or vanishing is churn")
    func membershipCountChange() {
        #expect(ThumbnailLayout.didRetile(from: [1: a], to: [1: a, 2: b]))
        #expect(ThumbnailLayout.didRetile(from: [1: a, 2: b], to: [1: a]))
    }

    @Test("a membership swap at equal count is churn")
    func membershipSwap() {
        #expect(ThumbnailLayout.didRetile(from: [1: a, 2: b], to: [1: a, 3: b]))
    }

    @Test("a >=1px move of any edge is churn")
    func onePixelMoveChurns() {
        let moved = CGRect(x: a.minX + 1, y: a.minY, width: a.width, height: a.height)
        #expect(ThumbnailLayout.didRetile(from: [1: a, 2: b], to: [1: moved, 2: b]))
        let grown = CGRect(x: a.minX, y: a.minY, width: a.width + 1, height: a.height)
        #expect(ThumbnailLayout.didRetile(from: [1: a, 2: b], to: [1: grown, 2: b]))
    }

    @Test("sub-pixel jitter is absorbed so fractional-scaled displays still settle")
    func subPixelJitterSettles() {
        // Fractional-scaled / HiDPI displays report frames with sub-pixel noise;
        // both edges round to the same pixel, so this must NOT read as churn (a
        // byte-exact compare here means "lights never appear" on those displays).
        let base = CGRect(x: 100.2, y: 200.1, width: 400.2, height: 300.1)
        let jittered = CGRect(x: 100.4, y: 199.8, width: 400.3, height: 299.9)
        #expect(!ThumbnailLayout.didRetile(from: [1: base], to: [1: jittered]))
    }
}
