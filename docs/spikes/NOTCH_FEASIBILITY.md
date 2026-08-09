# Menu bar and notch/fallback feasibility (public APIs only)

Task: S2 — macOS lifecycle and notch feasibility  
Branch: `codex/wave-0-foundation`  
Host evidence: **blocked** — Cloud Agent is Linux; no NSScreen, no notched MacBook, no external-display matrix.

Requirement IDs: MENUBAR-1..8, LIFECYCLE-1..5, NOTCH-1..12, NOTIFY-6..9  
ADRs: ADR-001, ADR-004

## Verdict (design spike)

A MenuBarExtra (window style) + narrow AppKit `NSPanel` coordinator hosting SwiftUI content is feasible using **public** AppKit/SwiftUI/UserNotifications/ServiceManagement APIs only. No private notch/camera API or hardware model table is required for MVP placement.

**Gate 0 notch validation matrix remains blocked without macOS Tahoe hardware.** Display-following policy stays deferred pending that evidence (matches Wave 0 baseline).

## Public geometry approach (NOTCH-1, NOTCH-2, NOTCH-10)

Derive top obstruction from the target `NSScreen` only:

| Public API | Role |
| --- | --- |
| `NSScreen.frame` / `NSScreen.visibleFrame` | Full display bounds vs menu-bar-excluded work area |
| `NSScreen.safeAreaInsets` | Nonzero **top** inset ⇒ obscured/notch region exists |
| `NSScreen.auxiliaryTopLeftArea` | Usable top-left band beside the obstruction |
| `NSScreen.auxiliaryTopRightArea` | Usable top-right band beside the obstruction |

Placement rules encoded in `ScreenGeometry`:

1. If `safeAreaInsets.top > 0` **or** both auxiliary top areas are non-nil with a gap between them → treat as **notched** and anchor a top-center panel in the gap / over the black housing, expanding **downward** into the visible area (never drawing under the camera housing — NOTCH-10).
2. Otherwise → **fallback pill**: compact top-center floating capsule just below the menu bar using `visibleFrame.maxY` as the ceiling (NOTCH-3).
3. Never key off product model names, IOKit camera nodes, or private SPI.

`ScreenTopMetrics` is injectable so unit tests can cover notched / notchless / scaled frames without hardware.

## Nonactivating `NSPanel` requirements (NOTCH-4, NOTCH-12)

Prototype: `NotchPanelCoordinator`.

Required panel configuration (public AppKit):

- `NSPanel` with `.borderless` + `.nonactivatingPanel`
- `isFloatingPanel = true`
- `hidesOnDeactivate = false`
- `level` ≈ `.statusBar` (or `.floating` if status-bar conflicts on device)
- `collectionBehavior` candidates: `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary` — finalize after hardware matrix
- Present with `orderFrontRegardless()`; **never** `makeKey()`, **never** `NSApp.activate(ignoringOtherApps:)`
- `becomesKeyOnlyIfNeeded`-style behavior: do not become key on show; clicks open GitHub via URL open without focusing the panel as a typing surface
- Host SwiftUI via `NSHostingView` / `NSHostingController` (`NotchEventContentView`)

Focus-theft risks to validate on device:

- Accidental `makeKeyAndOrderFront`
- First-responder grab from hosting view / buttons
- Full-screen Space promotion when collection behavior is wrong
- MenuBarExtra activation interacting with panel order

Telemetry hooks (sketch): log panel frame, target screen ID, mode (notch vs fallback), `NSApp.isActive` before/after present, and whether any window became key — without PII.

## Fallback pill (NOTCH-3)

Same SwiftUI content, different frame:

- Width ≈ compact capsule (~320–380 pt), height ≈ 44–56 pt collapsed / ~64–80 pt expanded
- Top edge ≈ `visibleFrame.maxY - padding` (below menu bar)
- Horizontally centered on `frame.midX`
- Settings Appearance may disable fallback on notchless displays (SETTINGS-5)

## Display-following policy options (pending hardware)

Wave 0 baseline: deferred until notched laptop + external monitor evidence.

Candidate policies for Gate 0 matrix:

| Option | Rule | Pros | Cons |
| --- | --- | --- | --- |
| A | Screen containing the menu-bar extra / last user interaction with GitPings | Predictable for “I just looked at pins” | Weak when dashboard is on another display |
| B | Screen of the frontmost app’s key window | Follows user attention | May leave notched built-in unused while coding on external |
| C | Prefer built-in notched screen when present; else key-window screen | Strong ambient identity | Wrong if user works exclusively on external above laptop |
| D | Screen under mouse pointer at event time | Simple | Surprising if pointer is idle on another display |

**Recommendation until evidence:** implement **Option A with Option B fallback** (interaction screen → key-window screen → first notched screen → main). Recompute on `NSApplication.didChangeScreenParametersNotification`, wake, and menu-bar auto-hide changes. Do **not** assume `NSScreen.screens[0]` / main is the notched built-in.

## Reduce Motion (NOTCH-9)

- Read `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` (and/or SwiftUI `accessibilityReduceMotion`)
- Default path: short expand-down + spring
- Reduce Motion: opacity fade only (no spring / large frame interpolation)
- Appearance Settings surface should show Reduce Motion status (read-only system mirror)

## Lock / full-screen suppression (NOTCH-11)

- **Screen lock:** suppress custom panel. Observe distributed lock/unlock notifications available publicly (e.g. `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` via `DistributedNotificationCenter`) and drop/queue presentations while locked.
- **Full-screen:** default suppress when the target Space is occupied by a full-screen app; Settings Appearance toggle to allow overlay (`fullScreenAuxiliary` collection behavior). Suppression remains MVP default.
- Queued events: router owns persistence; coordinator only presents when not suppressed.

## System notifications & launch-at-login (related stubs)

- `SystemNotificationPresenter`: `UNUserNotificationCenter` — request authorization **in context** when the user enables the system channel (NOTIFY-6), never at cold launch.
- `LaunchAtLoginManager`: conceptual `SMAppService.mainApp` register/unregister (SETTINGS-3, LIFECYCLE-2/3). Quiet login launch is App composition responsibility (integrator).

## Menu-bar notes (MENUBAR / LIFECYCLE)

Already scaffolded: `MenuBarExtra` + window-style popover, severity SF Symbol + accessibility label (not color-alone). S2 extends severity accessibility (`accessibilityValue` / hints) and keeps popover actions compile-friendly. Dashboard remains on-demand; Quit terminates process.

## Blockers (explicit)

| Blocker | Impact |
| --- | --- |
| Linux Cloud host — no AppKit runtime | Cannot compile/run/verify NSPanel or NSScreen |
| No notched MacBook | Cannot prove NOTCH-2/10 camera clearance |
| No external display matrix | Cannot close display-following policy |
| No menu-bar auto-hide / Spaces / lock recordings | Gate 0 ADR-004 matrix incomplete |
| App composition root integrator-owned | Stubs not wired into `AppDependencyContainer` yet |

## Out of scope / rejected

- Private notch/camera APIs or model lookup tables
- Permanent Dynamic Island interaction surface
- Production `NotificationRouting` actor (Monitoring Core)
- Editing `GitPings.xcodeproj`, `GitPings/App/**`, Domain contracts

## Stop condition

Public-API approach documented; focus-theft risks listed; private API not required. Hardware matrix → escalate to integrator / Gate 0.
