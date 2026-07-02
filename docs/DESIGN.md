# CloseUp Design Spec

Contributor-only doc (English). The durable rationale behind CloseUp's
architecture, visual language, and the platform quirks it must respect.

## Product

CloseUp is an open-source macOS app that overlays window controls (close /
minimize / zoom / hide / quit) onto the **native** macOS
Mission Control, adds in-Mission-Control keyboard shortcuts (with ⌥ batch
variants), and is fully localized into 9 languages. Menu-bar (accessory) app,
Developer-ID distribution, Sparkle self-update, GPL-3.0.

## Architecture decision table

| Decision | Choice | Why |
|---|---|---|
| App shape | Accessory (`LSUIElement`), menu-bar only | No main window; the status item is the only entry point |
| Distribution | Developer ID + notarized, **non-sandboxed** | The AX / CGEvent-tap / private-API path can't run in the App Sandbox |
| Binary | **Universal** (arm64 + x86_64) | One artifact runs on Intel + Apple Silicon; CloseUp trades download size for single-artifact simplicity (vs per-arch feeds) |
| Deployment floor | macOS 14.0 | PermissionFlow needs 13; `@Observable` needs 14; newer APIs gated behind `#available` |
| Targets | `CloseUpKit` (logic) + `CloseUp` (shell) + tests | All decision logic is hostless-testable; the shell is thin platform glue |
| Persistence | `Codable` JSON blobs in `UserDefaults` | Small config; atomic, round-trippable, no ORM |
| Update UI | Sparkle standard driver + own settings/menu UI | Working updates now; custom driver for full-i18n dialogs is a follow-up |
| Overlay clicks | Passive overlay window + global `CGEvent` tap | Never steals Mission Control's own Esc/arrow handling |

## Core feature — platform risk list

- **Private/undocumented APIs** (all widely shipped in notarized Developer-ID
  apps; they bar the Mac App Store, which is out of scope): `_AXUIElementGetWindow`,
  `CoreDockSendNotification`, the `AXExpose*` AX notification names. Reference:
  `nohackjustnoobb/OpenMissionControl` (GPL-3.0).
- Mission Control is drawn by the **Dock** (`com.apple.dock`) — observe it, not
  the frontmost app.
- **Coordinate flip** is the #1 bug class: `CGWindowList`/`CGEvent` are top-left
  origin, `NSWindow` is bottom-left. Isolated and unit-tested in
  `OverlayGeometry` (`nsWindowFrame` is the only place it happens).
- The CG↔AppKit flip pivots about the **menu-bar screen** height, not the screen
  the window is on; the *hovered* window is picked by frame containment.
- Mission Control re-tiles thumbnails away from real window positions — the
  overlay refreshes the window list on a short timer and tracks the pointer.
- The `CGEvent` tap can be disabled by timeout/user-input — it self-re-enables.
- In-MC action shortcuts (⌘W etc.) are matched **inside the tap only while MC is
  open**; they are deliberately kept unregistered as global hotkeys (a global ⌘W
  would swallow every window-close). See `ShortcutController`.
- TCC (Accessibility) posts **no** grant notification — `AccessibilityGrantWatcher`
  polls `AXIsProcessTrusted()`; `AppState.refreshAccessibilityStatus` reconciles
  grant **and** revocation and recreates the observer/tap on either transition.

## Design tokens

All spacing, radii, sizes, color, typography, and motion live in `DS`
(`Sources/CloseUp/UI/DesignSystem.swift`) — never inline literals. Values follow
a 4-pt rhythm and the macOS 13-pt control scale. The accent color is the
`AccentColor` asset (light + dark variants) wired as the global accent so AppKit
controls pick it up too. Semantic system colors only; dark/light is free.

Glass (Liquid Glass, macOS 26) button styles are reached only through
`dsGlassButtonStyle()` / `dsGlassProminentButtonStyle()`, which fall back to
`.bordered` pre-26 — the only sanctioned use of those styles.

## Icon system

- App icon: a designed asset (`scripts/icon-tools/appicon-art.png`) re-cut to the
  macOS grid — centered on a transparent 1024 canvas with a fresh soft shadow — by
  `scripts/icon-tools/make-master-from-art.sh` → `scripts/appicon-master.png`, then
  laddered to every size by `scripts/make-appicon.sh`. A graphite Mission Control
  tile: muted window thumbnails with one foreground window carrying the macOS
  traffic-light controls (red / amber / green). No blue. Reproducible from the
  committed artwork via `make-appicon.sh` (which rebuilds the master if absent).
- Status-bar icon: the native `macwindow.on.rectangle` SF Symbol — a window
  carrying the control dots over a second window, the menu-bar form of the app
  icon — rendered by the system as a template (it supplies the light/dark/active
  tint). Native beats a custom glyph; nothing to maintain.

## Internationalization

In-app language override across en (source), zh-Hans, zh-Hant, ja, fr, de, es,
pt (Brazilian house style), ru. Live switching (no restart) by injecting
`\.locale` at every scene root with an `.id(localeIdentifier)` rebuild. Native
surfaces (status menu, window titles, `.help`) resolve through `appState.loc` /
`AppKitStrings`. `KeyboardShortcuts`' resource bundle is redirected to the app
language. Seven guard tests (`LocalizationGuardTests`) enforce the invariants.
