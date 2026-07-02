import Testing
@testable import CloseUpKit

@Suite("WindowCapabilities")
struct WindowCapabilitiesTests {
    @Test("supported keeps only close/minimize/zoom whose AX button exists, in order")
    func filtersByButtonExistence() {
        let caps = WindowCapabilities(canClose: true, canMinimize: false, canZoom: true)
        #expect(caps.supported(from: [.close, .minimize, .zoom]) == [.close, .zoom])
    }

    @Test("supported preserves the requested left-to-right order")
    func preservesOrder() {
        let caps = WindowCapabilities(canClose: true, canMinimize: true, canZoom: true)
        #expect(caps.supported(from: [.zoom, .close, .minimize]) == [.zoom, .close, .minimize])
    }

    @Test("a window with no title-bar buttons yields an empty overlay")
    func noneYieldsEmpty() {
        #expect(WindowCapabilities.none.supported(from: [.close, .minimize, .zoom]).isEmpty)
    }

    @Test("hide/quit are app-level and always pass through regardless of buttons")
    func appLevelActionsAlwaysPass() {
        let caps = WindowCapabilities.none
        #expect(caps.supported(from: [.hide, .quit]) == [.hide, .quit])
        #expect(caps.supported(from: [.close, .hide, .zoom, .quit]) == [.hide, .quit])
    }
}
