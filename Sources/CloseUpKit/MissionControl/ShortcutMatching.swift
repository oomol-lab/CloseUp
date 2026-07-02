import CoreGraphics

/// A normalized modifier set, decoupled from AppKit/CoreGraphics flag types so
/// matching is pure and testable. Only the four meaningful chord modifiers are
/// represented (caps-lock, fn, and the numeric-pad bit are ignored).
public struct ModifierSet: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = ModifierSet(rawValue: 1 << 0)
    public static let option = ModifierSet(rawValue: 1 << 1)
    public static let control = ModifierSet(rawValue: 1 << 2)
    public static let shift = ModifierSet(rawValue: 1 << 3)

    /// Build from a live `CGEvent`'s flags (keeps only the four chord modifiers).
    public init(cgEventFlags flags: CGEventFlags) {
        var set = ModifierSet()
        if flags.contains(.maskCommand) { set.insert(.command) }
        if flags.contains(.maskAlternate) { set.insert(.option) }
        if flags.contains(.maskControl) { set.insert(.control) }
        if flags.contains(.maskShift) { set.insert(.shift) }
        self = set
    }
}

/// A key + modifier combination. `keyCode` is a virtual key code (the same
/// numbering as Carbon's `kVK_*` and `CGKeyCode`), so a `KeyboardShortcuts`
/// shortcut's `carbonKeyCode` maps across directly.
public struct KeyChord: Equatable, Sendable {
    public let keyCode: CGKeyCode
    public let modifiers: ModifierSet

    public init(keyCode: CGKeyCode, modifiers: ModifierSet) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Exact match against a live key event. Modifiers must match exactly so that
    /// `⌥⌘W` (close all) never also fires `⌘W` (close one).
    public func matches(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        self.keyCode == keyCode && modifiers == ModifierSet(cgEventFlags: flags)
    }
}

/// Virtual key codes for the keys CloseUp's default shortcuts use (US-ANSI
/// `kVK_ANSI_*` values; layout-independent — they identify the physical key).
private enum VK {
    static let w: CGKeyCode = 13
    static let m: CGKeyCode = 46
    static let f: CGKeyCode = 3
    static let h: CGKeyCode = 4
    static let q: CGKeyCode = 12
}

/// The actions CloseUp intercepts via the event tap **while Mission Control is
/// open**. These are not global hotkeys — `⌘W` globally would hijack every
/// window-close — so they are matched inside the tap only when the overlay is
/// shown. The defaults are the native window verbs plus the ⌥ batch variants.
public enum MissionControlShortcut: String, CaseIterable, Sendable {
    case close
    case minimize
    case zoom
    case hide
    case quit
    case closeAll
    case minimizeAll
    case hideAllExceptHovered

    public var defaultChord: KeyChord {
        switch self {
        case .close: KeyChord(keyCode: VK.w, modifiers: .command)
        case .minimize: KeyChord(keyCode: VK.m, modifiers: .command)
        case .zoom: KeyChord(keyCode: VK.f, modifiers: .command)
        case .hide: KeyChord(keyCode: VK.h, modifiers: .command)
        case .quit: KeyChord(keyCode: VK.q, modifiers: .command)
        case .closeAll: KeyChord(keyCode: VK.w, modifiers: [.command, .option])
        case .minimizeAll: KeyChord(keyCode: VK.m, modifiers: [.command, .option])
        case .hideAllExceptHovered: KeyChord(keyCode: VK.h, modifiers: [.command, .option])
        }
    }

    /// The mnemonic character of the default chord (the letter in ⌘W / ⌘M / …).
    /// Used to seed the default keycode from the *active keyboard layout* so a
    /// mnemonic lands on the key that TYPES the letter (Dvorak / AZERTY) rather
    /// than the physical ANSI position baked into `defaultChord`.
    public var defaultKeyEquivalent: Character {
        switch self {
        case .close, .closeAll: "w"
        case .minimize, .minimizeAll: "m"
        case .zoom: "f"
        case .hide, .hideAllExceptHovered: "h"
        case .quit: "q"
        }
    }

    /// Catalog key for the shortcut's display name (the Settings row label).
    /// The single-window actions share their key with the overlay button's
    /// `WindowAction.titleKey`, so the two surfaces can never drift apart.
    public var titleKey: String {
        switch self {
        case .close, .minimize, .zoom, .hide, .quit: windowAction.titleKey
        case .closeAll: "Close All Windows"
        case .minimizeAll: "Minimize All Windows"
        case .hideAllExceptHovered: "Hide All but This"
        }
    }

    /// Whether the shortcut acts on every window (batch) versus the hovered one.
    public var isBatch: Bool {
        switch self {
        case .closeAll, .minimizeAll, .hideAllExceptHovered: true
        default: false
        }
    }

    /// The window action this shortcut performs.
    public var windowAction: WindowAction {
        switch self {
        case .close, .closeAll: .close
        case .minimize, .minimizeAll: .minimize
        case .zoom: .zoom
        case .hide, .hideAllExceptHovered: .hide
        case .quit: .quit
        }
    }
}
