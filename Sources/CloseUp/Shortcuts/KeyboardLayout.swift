import Carbon.HIToolbox
import CoreGraphics

/// Reads the active keyboard layout to map a character to the physical key that
/// produces it. CloseUp's in-Mission-Control shortcuts are matched by virtual key
/// code (the same numbering the `KeyboardShortcuts` recorder stores), so a
/// hardcoded ANSI default like ⌘W would fire on the physical QWERTY-W position
/// even on Dvorak / AZERTY. Seeding the default keycode from the *layout* makes a
/// mnemonic land on the key that actually TYPES the letter.
enum KeyboardLayout {
    /// The virtual key code that produces `character` (lowercased, no modifiers)
    /// under the active keyboard layout, or `nil` if the layout can't be read or
    /// the character isn't reachable without modifiers. Pure reverse scan of all
    /// 128 key codes via `UCKeyTranslate`.
    static func keyCode(for character: Character) -> CGKeyCode? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let dataPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = Unmanaged<CFData>.fromOpaque(dataPointer).takeUnretainedValue() as Data
        let target = String(character).lowercased()
        let keyboardType = UInt32(LMGetKbdType())

        return layoutData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> CGKeyCode? in
            guard let base = buffer.baseAddress else { return nil }
            let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
            for code in 0..<UInt16(128) {
                var deadKeyState: UInt32 = 0
                var chars = [UniChar](repeating: 0, count: 4)
                var length = 0
                let status = UCKeyTranslate(
                    layout,
                    code,
                    UInt16(kUCKeyActionDown),
                    0, // no modifier keys
                    keyboardType,
                    OptionBits(kUCKeyTranslateNoDeadKeysMask), // the flag (1), not the bit index (0)
                    &deadKeyState,
                    chars.count,
                    &length,
                    &chars
                )
                guard status == noErr, length > 0 else { continue }
                if String(utf16CodeUnits: chars, count: length).lowercased() == target {
                    return CGKeyCode(code)
                }
            }
            return nil
        }
    }
}
