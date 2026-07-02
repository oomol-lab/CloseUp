import CoreGraphics
import Testing

@testable import CloseUpKit

@Suite("Shortcut matching")
struct ShortcutMatchingTests {
    @Test("modifier set keeps only the four chord modifiers")
    func modifierNormalization() {
        let flags: CGEventFlags = [.maskCommand, .maskAlphaShift /* caps lock — ignored */]
        #expect(ModifierSet(cgEventFlags: flags) == .command)
    }

    @Test("a chord matches its exact key + modifiers")
    func exactMatch() {
        let close = MissionControlShortcut.close.defaultChord // ⌘W
        #expect(close.matches(keyCode: 13, flags: .maskCommand))
    }

    @Test("⌥⌘W (close all) never collides with ⌘W (close one)")
    func batchVersusSingle() {
        let close = MissionControlShortcut.close.defaultChord
        let closeAll = MissionControlShortcut.closeAll.defaultChord
        // The single-close chord must reject the batch event…
        #expect(!close.matches(keyCode: 13, flags: [.maskCommand, .maskAlternate]))
        // …and the batch chord must reject the single event.
        #expect(!closeAll.matches(keyCode: 13, flags: .maskCommand))
        // Each matches its own.
        #expect(closeAll.matches(keyCode: 13, flags: [.maskCommand, .maskAlternate]))
    }

    @Test("default chords are the native window verbs")
    func defaults() {
        #expect(MissionControlShortcut.minimize.defaultChord == KeyChord(keyCode: 46, modifiers: .command))
        #expect(MissionControlShortcut.hide.defaultChord == KeyChord(keyCode: 4, modifiers: .command))
        #expect(MissionControlShortcut.quit.defaultChord == KeyChord(keyCode: 12, modifiers: .command))
        #expect(MissionControlShortcut.minimizeAll.defaultChord.modifiers == [.command, .option])
    }

    @Test("each shortcut maps to the right window action and batch flag")
    func actionMapping() {
        #expect(MissionControlShortcut.closeAll.windowAction == .close)
        #expect(MissionControlShortcut.closeAll.isBatch)
        #expect(!MissionControlShortcut.close.isBatch)
        #expect(MissionControlShortcut.zoom.windowAction == .zoom)
    }
}
