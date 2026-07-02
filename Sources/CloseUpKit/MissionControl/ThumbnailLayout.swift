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
        guard !old.isEmpty else { return false }
        guard old.count == new.count else { return true } // a thumbnail appeared/vanished
        for (id, frame) in new {
            guard let prev = old[id] else { return true } // membership changed
            // Integer-pixel (not byte-exact) equality — exact whole-set stability
            // at pixel resolution while absorbing sub-pixel jitter on
            // fractional-scaled displays so the layout always settles (no "lights
            // never appear" on HiDPI), yet a >=1px move still reads as churn.
            if Int(prev.minX.rounded()) != Int(frame.minX.rounded())
                || Int(prev.minY.rounded()) != Int(frame.minY.rounded())
                || Int(prev.width.rounded()) != Int(frame.width.rounded())
                || Int(prev.height.rounded()) != Int(frame.height.rounded()) {
                return true
            }
        }
        return false
    }
}
