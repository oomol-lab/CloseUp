/// The update channel a user follows. Stable items carry no `sparkle:channel`
/// tag (the always-included default channel); beta items are tagged `beta`.
public enum UpdateChannel: String, Sendable {
    case stable
    case beta

    /// The `UserDefaults` key backing the beta-channel preference — written by
    /// the Updates pane (`@AppStorage`) and read by the Sparkle delegate; named
    /// once so the two surfaces can never drift. Never rename the stored key:
    /// it is existing users' data.
    public static let usesBetaDefaultsKey = "usesBetaChannel"

    /// The set to return from `SPUUpdaterDelegate.allowedChannels(for:)`.
    /// The default (channel-less) channel is always included by Sparkle, so the
    /// stable channel maps to the empty set.
    public static func allowedChannels(for channel: UpdateChannel) -> Set<String> {
        switch channel {
        case .stable: []
        case .beta: ["beta"]
        }
    }

    public static func from(usesBeta: Bool) -> UpdateChannel {
        usesBeta ? .beta : .stable
    }
}
