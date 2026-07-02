import Foundation
import Testing

@testable import CloseUpKit

@Suite("OverlaySettings")
struct OverlaySettingsTests {
    @Test("defaults turn close/minimize/maximize on")
    func defaults() {
        let s = OverlaySettings()
        #expect(s.showClose && s.showMinimize && s.showZoom)
        #expect(s.enabledActions == [.close, .minimize, .zoom])
    }

    @Test("enabledActions preserves the fixed left-to-right order")
    func order() {
        let s = OverlaySettings(showClose: true, showMinimize: false, showZoom: true)
        #expect(s.enabledActions == [.close, .zoom])
    }

    @Test("a blob written before later toggles existed still loads with defaults")
    func lenientDecode() throws {
        // Simulates an older build's blob that predates the minimize/zoom toggles:
        // only `showClose` is present, so the omitted keys must fall back to their
        // `decodeIfPresent(...) ?? default` values in init(from:). A blob with all
        // keys present would never exercise that fallback.
        let json = #"{"showClose":false}"#
        let s = try JSONDecoder().decode(OverlaySettings.self, from: Data(json.utf8))
        #expect(!s.showClose)        // present key keeps its written value
        #expect(s.showMinimize)      // omitted → default true
        #expect(s.showZoom)          // omitted → default true
    }

    @Test("round-trips through Codable")
    func roundTrip() throws {
        let original = OverlaySettings(showClose: false, showMinimize: true, showZoom: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OverlaySettings.self, from: data)
        #expect(decoded == original)
    }

    @Test("isEnabled agrees with the stored flags; hide/quit are never overlay buttons")
    func isEnabled() {
        let s = OverlaySettings(showClose: true, showMinimize: false, showZoom: false)
        #expect(s.isEnabled(.close))
        #expect(!s.isEnabled(.minimize))
        #expect(!s.isEnabled(.zoom))
        #expect(!s.isEnabled(.hide))
        #expect(!s.isEnabled(.quit))
    }
}
