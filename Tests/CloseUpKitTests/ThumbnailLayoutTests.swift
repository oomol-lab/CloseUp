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

    @Test("tolerant didRetile absorbs micro-motion up to the tolerance, churns beyond it")
    func toleranceAbsorbsMicroMotion() {
        let jitter2px = CGRect(x: a.minX + 2, y: a.minY - 2, width: a.width + 1, height: a.height)
        // Strict gate (tolerance 0 / the default overload): 2px is churn.
        #expect(ThumbnailLayout.didRetile(from: [1: a], to: [1: jitter2px]))
        // Degraded settle (tolerance 2): the same motion reads as holding still…
        #expect(!ThumbnailLayout.didRetile(from: [1: a], to: [1: jitter2px], tolerance: 2))
        // …but a real re-tile-sized move still churns.
        let retiled = a.offsetBy(dx: 30, dy: 0)
        #expect(ThumbnailLayout.didRetile(from: [1: a], to: [1: retiled], tolerance: 2))
    }

    @Test("membership changes are churn at any tolerance — they re-tile the whole grid")
    func toleranceNeverAbsorbsMembership() {
        #expect(ThumbnailLayout.didRetile(from: [1: a], to: [1: a, 2: b], tolerance: 2))
        #expect(ThumbnailLayout.didRetile(from: [1: a, 2: b], to: [1: a, 3: b], tolerance: 2))
    }

    @Test("churnSample reports post-rounding per-window deltas and membership counts")
    func churnSampleDeltas() {
        let movedA = CGRect(x: a.minX + 2, y: a.minY - 1, width: a.width, height: a.height + 3)
        let sample = ThumbnailLayout.churnSample(
            from: [1: a, 2: b, 3: a],
            to: [1: movedA, 2: b, 4: b] // 1 moved, 2 still, 3 vanished, 4 appeared
        )
        #expect(sample == "moved=1[1:2,-1,0,3] appeared=1 vanished=1 of=3")
    }

    @Test("churnSample ignores sub-pixel jitter (mirrors didRetile's rounding) and caps its samples")
    func churnSampleRoundingAndCap() {
        // The same jitter didRetile absorbs must not be reported as movement.
        let jittered = CGRect(x: a.minX + 0.3, y: a.minY - 0.2, width: a.width + 0.1, height: a.height)
        #expect(ThumbnailLayout.churnSample(from: [1: a], to: [1: jittered])
            == "moved=0[] appeared=0 vanished=0 of=1")

        // Five movers, three sample slots: full count, truncated detail.
        let old = Dictionary(uniqueKeysWithValues: (1...5).map { (CGWindowID($0), a) })
        let new = old.mapValues { $0.offsetBy(dx: 5, dy: 0) }
        let sample = ThumbnailLayout.churnSample(from: old, to: new, maxSamples: 3)
        #expect(sample == "moved=5[1:5,0,0,0 2:5,0,0,0 3:5,0,0,0…] appeared=0 vanished=0 of=5")
    }
}
