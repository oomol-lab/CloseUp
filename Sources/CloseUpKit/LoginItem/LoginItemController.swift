import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` for the "launch at login" toggle.
/// Keyed off the app's bundle id, so the Debug build (a distinct identity)
/// registers separately from the installed Release and never collides with it.
@MainActor
public final class LoginItemController {
    public init() {}

    /// Whether CloseUp is currently registered to launch at login.
    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register or unregister the login item. Throws the underlying
    /// `SMAppService` error (callers map it to a semantic, localized message —
    /// never display the raw `localizedDescription`).
    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}
