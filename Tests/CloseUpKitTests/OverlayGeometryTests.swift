import CoreGraphics
import Testing

@testable import CloseUpKit

@Suite("OverlayGeometry")
struct OverlayGeometryTests {
    // A window near the top-left of a 1440-tall main screen.
    private let window = CGRect(x: 100, y: 60, width: 800, height: 500)
    private let pivot: CGFloat = 1440

    @Test("cluster width grows with the number of buttons")
    func clusterSize() {
        let one = OverlayGeometry(windowFrame: window, actionCount: 1, pivotHeight: pivot)
        let three = OverlayGeometry(windowFrame: window, actionCount: 3, pivotHeight: pivot)
        // padding*2 + n*button + (n-1)*spacing
        let oneWidth: CGFloat = 6 * 2 + 22          // 34
        let threeWidth: CGFloat = 6 * 2 + 3 * 22 + 2 * 4 // 86
        let height: CGFloat = 6 * 2 + 22            // 34
        #expect(one.clusterSize.width == oneWidth)
        #expect(three.clusterSize.width == threeWidth)
        #expect(three.clusterSize.height == height)
    }

    @Test("zero actions yields an empty cluster")
    func emptyCluster() {
        let g = OverlayGeometry(windowFrame: window, actionCount: 0, pivotHeight: pivot)
        #expect(g.clusterSize == .zero)
    }

    @Test("CG→AppKit flip inverts Y about the pivot, leaves X")
    func coordinateFlip() {
        let g = OverlayGeometry(windowFrame: window, actionCount: 3, pivotHeight: pivot)
        let cg = g.clusterFrameCG
        let ns = g.nsWindowFrame
        #expect(ns.minX == cg.minX)
        #expect(ns.width == cg.width)
        #expect(ns.height == cg.height)
        // The cluster straddles the window's top edge, so its CG rect starts above
        // window.minY; the flip is purely NS origin Y = pivot - cgMaxY.
        #expect(ns.minY == pivot - cg.maxY)
    }

    @Test("hit-test resolves each button center and partitions the whole cluster (no dead gaps)")
    func hitTesting() {
        let g = OverlayGeometry(windowFrame: window, actionCount: 3, pivotHeight: pivot)
        // Center of each button still hits its index.
        for index in 0..<3 {
            let r = g.buttonRectCG(index)
            #expect(g.hitTest(CGPoint(x: r.midX, y: r.midY)) == index)
        }
        // A point outside the cluster misses.
        #expect(g.hitTest(CGPoint(x: window.maxX, y: window.maxY)) == nil)
        // The former dead gap between button 0 and 1 now resolves to a real button
        // (the wider-target behavior) rather than nil — clicks no longer fall through
        // the 4 pt seam.
        let b0 = g.buttonRectCG(0)
        let gapX = b0.maxX + OverlayGeometry.buttonSpacing / 2
        #expect(g.hitTest(CGPoint(x: gapX, y: b0.midY)) != nil)
        // The cluster's left padding band (inside the cluster, left of button 0)
        // resolves to button 0 instead of missing.
        #expect(g.hitTest(CGPoint(x: g.clusterFrameCG.minX + 1, y: b0.midY)) == 0)
        // The right padding band resolves to the last button.
        #expect(g.hitTest(CGPoint(x: g.clusterFrameCG.maxX - 1, y: b0.midY)) == 2)
    }

    @Test("the cluster's outer half lies above the window — the sticky-hover region")
    func outerHalfAboveWindow() {
        let g = OverlayGeometry(windowFrame: window, actionCount: 3, pivotHeight: pivot)
        let first = g.buttonRectCG(0)
        // A point on the OUTER (above-the-thumbnail) half of the first button: inside the
        // cluster, but above the window's top edge so it is NOT inside the window frame.
        // This is exactly the region where `frontmost(containing:)` misses the hovered
        // window, so the live engine keeps the current window resolved while the cursor is
        // within `clusterFrameCG` (the "lights vanish on the outside half" fix).
        let outerHalf = CGPoint(x: first.midX, y: window.minY - OverlayGeometry.buttonSize / 4)
        #expect(outerHalf.y < window.minY)              // above the thumbnail
        #expect(!window.contains(outerHalf))            // frontmost() would miss it
        #expect(g.clusterFrameCG.contains(outerHalf))   // but the cluster owns the point
        #expect(g.hitTest(outerHalf) == 0)              // and it still hits button 0
    }

    @Test("cluster straddles the top edge, inset from the left")
    func anchoring() {
        let g = OverlayGeometry(windowFrame: window, actionCount: 2, pivotHeight: pivot)
        let first = g.buttonRectCG(0)
        // First button's left edge sits `edgeInset` in from the window's left edge.
        #expect(first.minX == window.minX + OverlayGeometry.edgeInset)
        // Every button's vertical center lands exactly on the window's top edge —
        // half the button inside the window, half above it.
        for index in 0..<2 {
            #expect(g.buttonRectCG(index).midY == window.minY)
        }
        // The cluster rect therefore begins above the window's top edge, by
        // exactly `topOverhang` — the same value the live engine uses as its
        // hover-acquisition band, so the acquire zone always matches the zone
        // the cluster occupies.
        #expect(g.clusterFrameCG.minY == window.minY - OverlayGeometry.topOverhang)
    }
}
