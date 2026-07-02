import AppKit
import CloseUpKit
import KeyboardShortcuts

extension MissionControlShortcut {
    /// The `KeyboardShortcuts.Name` this in-MC action is stored/edited under.
    var name: KeyboardShortcuts.Name {
        switch self {
        case .close: .closeWindow
        case .minimize: .minimizeWindow
        case .zoom: .zoomWindow
        case .hide: .hideApp
        case .quit: .quitApp
        case .closeAll: .closeAllWindows
        case .minimizeAll: .minimizeAllWindows
        case .hideAllExceptHovered: .hideAllExceptHovered
        }
    }
}

extension KeyChord {
    /// Build from a stored `KeyboardShortcuts.Shortcut`.
    init(_ shortcut: KeyboardShortcuts.Shortcut) {
        var modifiers = ModifierSet()
        let flags = shortcut.modifiers
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        self.init(keyCode: CGKeyCode(shortcut.carbonKeyCode), modifiers: modifiers)
    }

    /// Convert to a `KeyboardShortcuts.Shortcut` for seeding the recorder.
    /// Built from Carbon values directly (Carbon modifier bits from
    /// `Events.h`), avoiding the failable `Key` initializer.
    var keyboardShortcut: KeyboardShortcuts.Shortcut {
        var carbonModifiers = 0
        if modifiers.contains(.command) { carbonModifiers |= 0x0100 } // cmdKey
        if modifiers.contains(.shift) { carbonModifiers |= 0x0200 }   // shiftKey
        if modifiers.contains(.option) { carbonModifiers |= 0x0800 }  // optionKey
        if modifiers.contains(.control) { carbonModifiers |= 0x1000 } // controlKey
        return KeyboardShortcuts.Shortcut(carbonKeyCode: Int(keyCode), carbonModifiers: carbonModifiers)
    }
}

/// Bridges `KeyboardShortcuts` to the engine. Seeds the in-MC defaults once,
/// and — crucially — keeps the in-MC shortcuts permanently unregistered as
/// global hotkeys (so `⌘W` etc. never swallow keys system-wide), while still
/// exposing their stored values for the event tap.
@MainActor
final class ShortcutController {
    private var changeObserver: NSObjectProtocol?

    /// KeyboardShortcuts posts this (private) notification whenever a shortcut is
    /// set/cleared — the Recorder re-registers the Carbon hotkey on each edit, so
    /// we re-disable the in-MC names every time it fires.
    private static let shortcutChanged = Notification.Name("KeyboardShortcuts_shortcutByNameDidChange")
    private static let seededKey = "didSeedShortcuts_v1"

    func start() {
        seedDefaultsIfNeeded()
        disableInMCShortcuts()

        changeObserver = NotificationCenter.default.addObserver(
            forName: Self.shortcutChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.disableInMCShortcuts() }
        }
    }

    /// The key chord currently bound to an in-MC action, for matching in the tap.
    func chord(for shortcut: MissionControlShortcut) -> KeyChord? {
        KeyboardShortcuts.getShortcut(for: shortcut.name).map(KeyChord.init)
    }

    /// Seed the in-MC defaults once, with each key code resolved from the active
    /// keyboard layout (`defaultChord(for:)`). Known limitation: a user who already
    /// ran a prior build has `seededKey` set and keeps their stored seeds, so a
    /// non-ANSI user who first launched an earlier version keeps the old physical
    /// seeds until they reset a shortcut (restore/isAtDefault ARE layout-aware, so
    /// Settings shows such a seed as not-at-default and offers a one-click restore).
    /// Bumping `seededKey` would NOT help — the loop only writes entries that are
    /// `nil`, and a stale entry is non-nil — and would clobber shortcuts the user
    /// deliberately cleared; so it is intentionally not bumped.
    private func seedDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.seededKey) else { return }
        for shortcut in MissionControlShortcut.allCases
        where KeyboardShortcuts.getShortcut(for: shortcut.name) == nil {
            KeyboardShortcuts.setShortcut(Self.defaultChord(for: shortcut).keyboardShortcut, for: shortcut.name)
        }
        UserDefaults.standard.set(true, forKey: Self.seededKey)
    }

    /// The default chord for a shortcut, with its key code resolved from the
    /// ACTIVE keyboard layout (so ⌘W defaults to the key that types 'w' on
    /// Dvorak / AZERTY, not the physical ANSI-W position). Falls back to the
    /// hardcoded ANSI `defaultChord` when the layout can't be read or the mnemonic
    /// isn't reachable without modifiers.
    static func defaultChord(for shortcut: MissionControlShortcut) -> KeyChord {
        let base = shortcut.defaultChord
        guard let keyCode = KeyboardLayout.keyCode(for: shortcut.defaultKeyEquivalent) else { return base }
        return KeyChord(keyCode: keyCode, modifiers: base.modifiers)
    }

    private func disableInMCShortcuts() {
        KeyboardShortcuts.disable(MissionControlShortcut.allCases.map(\.name))
    }

    /// Force a single in-Mission-Control shortcut back to its default chord.
    /// Bypasses the Recorder's menu-conflict validation, so it recovers a chord
    /// (e.g. Cmd+Q) the user deleted and can no longer re-record by hand.
    func restoreDefault(_ shortcut: MissionControlShortcut) {
        KeyboardShortcuts.setShortcut(Self.defaultChord(for: shortcut).keyboardShortcut, for: shortcut.name)
        disableInMCShortcuts()
    }

    /// Whether a shortcut currently holds its (layout-aware) default chord (a
    /// cleared/unset binding counts as non-default — it can still be restored).
    func isAtDefault(_ shortcut: MissionControlShortcut) -> Bool {
        chord(for: shortcut) == Self.defaultChord(for: shortcut)
    }

    // No deinit: `ShortcutController` lives for the whole app session (owned by
    // `AppState`), and a @MainActor type's nonisolated deinit can't touch the
    // isolated observer anyway. The block observer is released at process exit.
}
