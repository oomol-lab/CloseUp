import CoreGraphics

/// Pure churn-vs-settled comparison over Mission Control's per-window thumbnail
/// frames — the heart of the settle gate that decides when the overlay may show
/// (and when a re-tile must rebuild the overlay window). Kept in `CloseUpKit`
/// so the two opposite failure modes it balances stay pinned by unit tests.
public enum ThumbnailLayout {
    /// Whether the thumbnail layout shifted between two refreshes (Mission Control
    /// is re-tiling). Tight INTEGER-PIXEL comparison — the window-set membership must
    /// be identical and every per-window-id frame equal once each edge is rounded to
    /// the nearest pixel — so the overlay shows only when the captured window set
    /// exactly equals the previous tick's. CGWindowList bounds are pixel-aligned so
    /// at steady state this settles cleanly; rounding only absorbs sub-pixel jitter
    /// on fractional-scaled / HiDPI displays so the layout still settles there (a
    /// byte-exact compare risks "lights never appear"), while any ≥1px move still
    /// reads as churn. This is what suppresses the still-entering / paused-mid-swipe
    /// case: during the interactive scrub the thumbnails move, so the set never reads
    /// as settled and the lights stay hidden (a looser tolerance would smooth that
    /// into a false "settled" and light up mid-gesture — the "paused swipe shows
    /// early" bug). An empty baseline (a session's first refresh) is never a re-tile.
    public static func didRetile(from old: [CGWindowID: CGRect], to new: [CGWindowID: CGRect]) -> Bool {
        didRetile(from: old, to: new, tolerance: 0)
    }

    /// The tolerant generalization backing the STARVATION FALLBACK (degraded
    /// settle): `tolerance` is the per-edge integer-pixel movement that still
    /// counts as "holding still". The strict gate (`tolerance` 0) stays the
    /// primary — a loose tolerance from the start would smooth a paused
    /// interactive scrub into a false "settled" and light up mid-gesture (the
    /// documented "paused swipe shows early" bug). The engine escalates to a
    /// small tolerance only after the strict gate has been starved for seconds
    /// on end (no real Mission Control enter or re-tile animates that long —
    /// macOS 27's re-animated MC keeps thumbnails micro-moving indefinitely,
    /// which starved the strict gate forever and the lights never showed).
    /// Membership changes (a thumbnail appearing/vanishing) are churn at ANY
    /// tolerance: they re-tile the whole grid.
    public static func didRetile(
        from old: [CGWindowID: CGRect], to new: [CGWindowID: CGRect], tolerance: Int
    ) -> Bool {
        guard !old.isEmpty else { return false }
        guard old.count == new.count else { return true } // a thumbnail appeared/vanished
        let px = { (value: CGFloat) in Int(value.rounded()) }
        for (id, frame) in new {
            guard let prev = old[id] else { return true } // membership changed
            // Integer-pixel (not byte-exact) comparison — exact whole-set stability
            // at pixel resolution while absorbing sub-pixel jitter on
            // fractional-scaled displays so the layout still settles there (a
            // byte-exact compare risks "lights never appear"), while any move
            // beyond `tolerance` whole pixels still reads as churn.
            if abs(px(prev.minX) - px(frame.minX)) > tolerance
                || abs(px(prev.minY) - px(frame.minY)) > tolerance
                || abs(px(prev.width) - px(frame.width)) > tolerance
                || abs(px(prev.height) - px(frame.height)) > tolerance {
                return true
            }
        }
        return false
    }

    /// Compact sample of WHAT is churning between two refreshes, for the field
    /// tripwire that fires when a live session's layout stays unsettled for
    /// seconds on end — the fingerprint of a macOS release re-animating Mission
    /// Control so thumbnails never hold still at integer-pixel resolution (then
    /// `didRetile` reads churn forever, the settle gate starves, and no lights
    /// ever show while everything else looks healthy). Reports up to
    /// `maxSamples` windows that moved ≥1 integer pixel as `id:Δx,Δy,Δw,Δh`
    /// (post-rounding deltas — exactly what `didRetile` compared), plus
    /// appeared/vanished membership counts, so one `.notice` line says whether
    /// the churn is a real re-tile, a micro-jitter, or window-set flapping.
    public static func churnSample(
        from old: [CGWindowID: CGRect], to new: [CGWindowID: CGRect], maxSamples: Int = 3
    ) -> String {
        let px = { (value: CGFloat) in Int(value.rounded()) }
        var moved: [(id: CGWindowID, delta: String)] = []
        for (id, frame) in new {
            guard let prev = old[id] else { continue }
            let dx = px(frame.minX) - px(prev.minX)
            let dy = px(frame.minY) - px(prev.minY)
            let dw = px(frame.width) - px(prev.width)
            let dh = px(frame.height) - px(prev.height)
            if dx != 0 || dy != 0 || dw != 0 || dh != 0 {
                moved.append((id, "\(id):\(dx),\(dy),\(dw),\(dh)"))
            }
        }
        moved.sort { $0.id < $1.id }
        let appeared = new.keys.filter { old[$0] == nil }.count
        let vanished = old.keys.filter { new[$0] == nil }.count
        let overflow = moved.count > maxSamples ? "…" : ""
        let samples = moved.prefix(maxSamples).map(\.delta).joined(separator: " ")
        return "moved=\(moved.count)[\(samples)\(overflow)] appeared=\(appeared) vanished=\(vanished) of=\(new.count)"
    }
}
