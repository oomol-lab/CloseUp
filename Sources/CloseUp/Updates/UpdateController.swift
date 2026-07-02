import CloseUpKit
import Sparkle
import SwiftUI

/// Wraps Sparkle's standard updater. Release builds start the updater against
/// the EdDSA-signed appcast in `Info.plist` (whose `SUPublicEDKey` must be a real
/// ed25519 key, or Sparkle refuses to start the updater). Debug builds never
/// start it (`startingUpdater: false`), so the update UI stays inert and no check
/// is ever scheduled regardless of the feed/key state.
@MainActor
final class UpdateController {
    private let controller: SPUStandardUpdaterController
    private let started: Bool
    private let updaterDelegate = UpdaterDelegate()

    init() {
        #if DEBUG
        started = false
        #else
        started = true
        #endif
        controller = SPUStandardUpdaterController(
            startingUpdater: started, updaterDelegate: updaterDelegate, userDriverDelegate: nil
        )
    }

    private var updater: SPUUpdater { controller.updater }

    /// Whether checks are possible (false in Debug / before the updater starts).
    var canCheckForUpdates: Bool {
        started && updater.canCheckForUpdates
    }

    /// User-initiated check (menu / settings button). Opens Sparkle's update
    /// flow only when an update exists.
    func checkForUpdates() {
        guard started else { return }
        controller.checkForUpdates(nil)
    }

    var automaticallyChecksForUpdates: Bool {
        get { started && updater.automaticallyChecksForUpdates }
        set { guard started else { return }; updater.automaticallyChecksForUpdates = newValue }
    }

    var lastUpdateCheckDate: Date? {
        started ? updater.lastUpdateCheckDate : nil
    }

    /// Re-resolve the feed after the channel preference changes (Updates pane).
    func channelDidChange() {
        guard started else { return }
        updater.resetUpdateCycle()
    }
}

/// Reads the beta-channel preference (written by the Updates pane via
/// @AppStorage `UpdateChannel.usesBetaDefaultsKey`) and tells Sparkle which
/// channels to accept, and pins the appcast feed to the binary's own
/// architecture.
final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        let usesBeta = UserDefaults.standard.bool(forKey: UpdateChannel.usesBetaDefaultsKey)
        return UpdateChannel.allowedChannels(for: .from(usesBeta: usesBeta))
    }

    /// Each architecture is its own product with its own feed — CloseUp ships
    /// single-arch apps and does NOT support cross-arch updates — so the feed is
    /// pinned at COMPILE time, where no build/CI misconfiguration can reach it:
    /// an x86_64 binary can only ever see x86_64 updates, arm64 only arm64. Both
    /// arches resolve explicitly (no Info.plist fallback); the feeds are
    /// symmetric and there is intentionally no compatibility with the universal
    /// 0.1.0 (its old `appcast.xml` is left orphaned — see docs/RUNBOOK.md §5).
    func feedURLString(for updater: SPUUpdater) -> String? {
        #if arch(x86_64)
        return "https://oomol-lab.github.io/CloseUp/appcast-x86_64.xml"
        #else
        return "https://oomol-lab.github.io/CloseUp/appcast-arm64.xml"
        #endif
    }
}
