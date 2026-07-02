import Testing

@testable import CloseUpKit

@Suite("OverlayCapabilityPolicy")
struct OverlayCapabilityPolicyTests {
    @Test("unavailable (AX untrusted) falls back to show-all: no filter, no cache, no retry")
    func unavailable() {
        let outcome = OverlayCapabilityPolicy.outcome(for: .unavailable)
        #expect(outcome.display == nil)
        #expect(outcome.cache == nil)
        #expect(outcome.retry == false)
    }

    @Test("an authoritative non-empty resolve displays and caches, no retry")
    func resolvedReal() {
        let caps = WindowCapabilities(canClose: true, canMinimize: true, canZoom: false)
        let outcome = OverlayCapabilityPolicy.outcome(for: .resolved(caps))
        #expect(outcome.display == caps)
        #expect(outcome.cache == caps)
        #expect(outcome.retry == false)
    }

    @Test("an authoritative empty resolve stays dark but is retried, never cached (warm-up ambiguity)")
    func resolvedNone() {
        let outcome = OverlayCapabilityPolicy.outcome(for: .resolved(WindowCapabilities.none))
        #expect(outcome.display == WindowCapabilities.none)
        #expect(outcome.cache == nil)
        #expect(outcome.retry == true)
    }

    @Test("an indeterminate resolve (busy app / timeout) stays dark, is retried, never cached")
    func indeterminate() {
        let outcome = OverlayCapabilityPolicy.outcome(for: .indeterminate)
        #expect(outcome.display == WindowCapabilities.none)
        #expect(outcome.cache == nil)
        #expect(outcome.retry == true)
    }

    @Test("a display of .none yields no actions — the dark overlay")
    func darkMeansNoActions() {
        let outcome = OverlayCapabilityPolicy.outcome(for: .indeterminate)
        #expect(outcome.display?.supported(from: [.close, .minimize, .zoom]) == [])
    }
}
