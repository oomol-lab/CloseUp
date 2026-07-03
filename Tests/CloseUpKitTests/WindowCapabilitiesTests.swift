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

@Suite("CapabilityBatchSummary")
struct CapabilityBatchSummaryTests {
    private let buttons = CapabilityResolution.resolved(
        WindowCapabilities(canClose: true, canMinimize: true, canZoom: true)
    )

    @Test("counts each outcome class")
    func countsClasses() {
        let summary = CapabilityBatchSummary(of: [
            buttons, .resolved(.none), .resolved(.none), .indeterminate, .unavailable,
        ])
        #expect(summary.withButtons == 1)
        #expect(summary.none == 2)
        #expect(summary.indeterminate == 1)
        #expect(summary.unavailable == 1)
    }

    @Test("all-dark: trusted batch with zero buttons across none/indeterminate")
    func allDark() {
        #expect(CapabilityBatchSummary(of: [
            CapabilityResolution.resolved(.none), .indeterminate, .resolved(.none),
        ]).isAllDark)
    }

    @Test("not all-dark once a single window resolves a button")
    func oneButtonDefusesIt() {
        #expect(!CapabilityBatchSummary(of: [
            CapabilityResolution.resolved(.none), buttons, .indeterminate,
        ]).isAllDark)
    }

    @Test("untrusted (.unavailable) batches never read as all-dark — that mode has its own fallback and fingerprint")
    func untrustedExcluded() {
        #expect(!CapabilityBatchSummary(of: [
            CapabilityResolution.unavailable, .unavailable,
        ]).isAllDark)
        // Even mixed with blanks: unavailable means AX trust is the story, not matching.
        #expect(!CapabilityBatchSummary(of: [
            CapabilityResolution.unavailable, .resolved(.none), .indeterminate,
        ]).isAllDark)
    }

    @Test("an empty batch is not all-dark")
    func emptyBatch() {
        #expect(!CapabilityBatchSummary(of: [CapabilityResolution]()).isAllDark)
    }

    @Test("logDescription is the compact four-count form")
    func logForm() {
        let summary = CapabilityBatchSummary(of: [buttons, .resolved(.none), .indeterminate])
        #expect(summary.logDescription == "buttons=1 none=1 indeterminate=1 unavailable=0")
    }
}
