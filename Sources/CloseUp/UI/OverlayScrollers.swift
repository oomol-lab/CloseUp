import AppKit
import SwiftUI

/// Pins the scroll views in the host window to the **overlay** scroller style —
/// the thin scrollers that fade out while idle and reappear on scroll —
/// overriding the system "Show scroll bars: Always" preference (and the
/// always-visible, ~17pt *legacy* scrollers it forces, e.g. when a mouse is
/// attached).
///
/// SwiftUI exposes `.scrollIndicators(_:)` for indicator *visibility* but no
/// public API for scroller *style*, so we bridge to AppKit. A grouped `Form`
/// builds its `NSScrollView` **lazily** — it does not exist yet when this probe
/// first reaches the window — so we poll the window's view tree on the main run
/// loop for a short window until the scroll view appears, then force `.overlay`.
/// We also re-apply on SwiftUI layout passes (`updateNSView`) and when the
/// system scroller preference changes at runtime (a mouse plugged in, the
/// setting toggled).
private final class OverlayScrollerProbe: NSView {
    private var attempts = 0
    private var observing = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else {
            NSObject.cancelPreviousPerformRequests(withTarget: self)
            return
        }
        if !observing {
            observing = true
            NotificationCenter.default.addObserver(
                self, selector: #selector(apply),
                name: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil)
        }
        reapply()
    }

    /// Restart the poll-and-apply cycle from the top (on layout passes).
    func reapply() {
        guard window != nil else { return }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(apply), object: nil)
        attempts = 0
        apply()
    }

    @objc private func apply() {
        guard let root = window?.contentView else { return }
        var scrollViews: [NSScrollView] = []
        Self.collect(in: root, into: &scrollViews)
        guard !scrollViews.isEmpty else {
            // The scroll view is built lazily; retry briefly on the main run loop
            // (~2s ceiling) until it materializes.
            guard attempts < 40 else { return }
            attempts += 1
            perform(#selector(apply), with: nil, afterDelay: 0.05)
            return
        }
        for scrollView in scrollViews { scrollView.scrollerStyle = .overlay }
    }

    private static func collect(in view: NSView, into result: inout [NSScrollView]) {
        if let scrollView = view as? NSScrollView { result.append(scrollView) }
        for subview in view.subviews { collect(in: subview, into: &result) }
    }
}

private struct OverlayScrollerBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> OverlayScrollerProbe { OverlayScrollerProbe() }
    func updateNSView(_ nsView: OverlayScrollerProbe, context: Context) { nsView.reapply() }
}

extension View {
    /// Force thin, auto-hiding (overlay) scrollers on the scroll views in this
    /// view's window — works for both `ScrollView` and grouped `Form`, and
    /// overrides the system "always show scroll bars" setting. See
    /// `OverlayScrollerProbe`.
    func overlayScrollers() -> some View {
        background(OverlayScrollerBridge().frame(width: 0, height: 0).accessibilityHidden(true))
    }
}
