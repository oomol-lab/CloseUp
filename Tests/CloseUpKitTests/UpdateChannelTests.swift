import Testing

@testable import CloseUpKit

@Suite("UpdateChannel")
struct UpdateChannelTests {
    @Test("stable allows only the default channel (empty set)")
    func stable() {
        #expect(UpdateChannel.allowedChannels(for: .stable) == [])
    }

    @Test("beta adds the beta channel")
    func beta() {
        #expect(UpdateChannel.allowedChannels(for: .beta) == ["beta"])
    }

    @Test("maps from a beta preference flag")
    func fromFlag() {
        #expect(UpdateChannel.from(usesBeta: true) == .beta)
        #expect(UpdateChannel.from(usesBeta: false) == .stable)
    }
}
