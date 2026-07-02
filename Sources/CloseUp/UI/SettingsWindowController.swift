import AppKit
import CloseUpKit
import SwiftUI

/// Owns the single Settings window.
///
/// CloseUp presents Settings from a self-managed `NSWindow` hosting
/// `SettingsRootView` rather than SwiftUI's `Settings` scene. The scene's
/// `showSettingsWindow:` responder does NOT open the window from a plain
/// `NSApplicationDelegate` — the reopen path — in an accessory (`LSUIElement`)
/// app: verified on macOS 26 that `NSApp.sendAction(Selector("showSettingsWindow:"))`
/// reports handled (returns `true`) yet no window ever materializes, even after
/// switching to `.regular` activation. A self-managed window opens
/// deterministically from every entry point (menu, ⌘,, and reopening a
/// hidden-icon app) and reuses one instance.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private unowned let appState: AppState
    private var window: NSWindow?

    init(appState: AppState) {
        self.appState = appState
    }

    /// Show the Settings window, creating it on first use, and raise it above
    /// other apps — an accessory app is not auto-activated when a window opens,
    /// so `orderFrontRegardless()` is required to surface it over the frontmost
    /// app. Idempotent: a second call just re-fronts the existing window.
    func show() {
        Log.app.notice("present Settings window")
        let window = ensureWindow()
        // Mirror `GeneralSettingsPane.onAppear` on every open (a reused window's
        // SwiftUI `.onAppear` does not re-fire), so the AX badge is current.
        appState.refreshAccessibilityStatus()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        // An accessory app is not auto-activated, so `NSApp.activate()` (cooperative)
        // may be denied; `orderFrontRegardless()` still raises the window above the
        // frontmost app's windows — this is what makes reopen reliably surface it.
        window.orderFrontRegardless()
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: DS.Window.settingsWidth, height: DS.Window.settingsHeight),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        // `NSWindow.title` is a native-bridging surface that bypasses the injected
        // locale; the brand name is locale-independent so it needs no live update.
        window.title = "CloseUp"
        // Host a wrapper whose `body` applies `.localized`, so the locale reads
        // happen inside a re-evaluated body: `NSHostingView` then re-renders on a
        // language change and the Settings UI switches live. A fixed root view
        // would freeze the locale captured when the window was created.
        window.contentView = NSHostingView(rootView: SettingsWindowRoot(appState: appState))
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("CloseUp.Settings")
        window.delegate = self
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        // Mirror `SettingsRootView.onDisappear`: stop polling Accessibility when
        // the window closes. SwiftUI `.onDisappear` is unreliable for a reused
        // AppKit window, so drive it from the window lifecycle explicitly.
        appState.stopAccessibilityWatch()
    }
}

/// Wrapper so the `.localized(with:)` locale reads live inside a SwiftUI `body`
/// that `NSHostingView` re-evaluates on change — the mechanism that makes the
/// self-managed Settings window switch language live (see `SettingsWindowController`).
private struct SettingsWindowRoot: View {
    let appState: AppState

    var body: some View {
        SettingsRootView().localized(with: appState)
    }
}
