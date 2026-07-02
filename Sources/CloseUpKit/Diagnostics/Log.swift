import os

/// Unified-logging facade for the Mission Control runtime. The overlay pipeline
/// hangs off a private `AXObserver` on the Dock plus a session `CGEvent` tap;
/// when either silently dies in the field (classically after a Space switch into
/// a full-screen app), there is nothing on screen to diagnose from. These
/// loggers narrate the pipeline's lifecycle so a failure can be traced live:
///
///     /usr/bin/log stream --predicate 'subsystem == "com.oomol.CloseUp"' --debug --style compact
///
/// (or Console.app filtered on the subsystem). Two tiers: lifecycle events
/// (`.notice` — session begin/end, observer armed, layout settled) persist to
/// the store and come back from a post-hoc `log show`; hot-path events
/// (`.debug` — hover, overlay show, MC state) are NOT persisted and appear only
/// in a live `--debug` stream captured during the repro (`log show --debug`
/// returns nothing for them — the trap documented in AGENTS.md). Always invoke
/// `/usr/bin/log` by full path: bare `log` is a zsh builtin. Values are marked
/// `.public` because none of them are user data.
public enum Log {
    public static let subsystem = "com.oomol.CloseUp"

    /// Observer arm/disarm, expose-notification flow, session begin/end, and the
    /// recovery paths (Space change / Dock relaunch re-arm).
    public static let missionControl = Logger(subsystem: subsystem, category: "missioncontrol")

    /// Event-tap create/teardown and the system-disable re-enable path.
    public static let eventTap = Logger(subsystem: subsystem, category: "eventtap")

    /// App-shell lifecycle: reopen handling, Settings-window presentation.
    public static let app = Logger(subsystem: subsystem, category: "app")
}
