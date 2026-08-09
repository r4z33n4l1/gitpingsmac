# ADR 001: Native macOS application architecture

Status: Accepted for MVP
Date: 2026-08-09

## Context

GitPings must remain active as a menu-bar utility, open a richer dashboard only when requested, expose a dedicated Settings window, poll GitHub, persist state, and display a custom top-of-screen notification. It targets only the current stable macOS generation, Tahoe 26, so compatibility shims for older macOS versions are not a goal.

## Decision

Build a native Swift 6 application in Xcode targeting macOS 26.

Use:

- SwiftUI for the app lifecycle, dashboard, Settings, menu-bar popover, and notch notification content.
- A MenuBarExtra with window style for the pinned quick view.
- A singleton on-demand dashboard Window scene. It is not presented at quiet launch/login.
- A dedicated Settings scene.
- A narrow AppKit panel coordinator for the notch/fallback notification because SwiftUI scenes do not provide the required nonactivating, precisely positioned floating panel lifecycle.
- Swift Observation for UI-facing state.
- Structured concurrency and actors for authentication, GitHub networking, refresh coordination, persistence, and transition detection.
- SwiftData for non-secret durable state and cached PR snapshots.
- Keychain Services for GitHub tokens.
- URLSession for GitHub HTTPS requests.
- UserNotifications for the optional system notification channel.
- ServiceManagement SMAppService for launch at login.

The application is menu-bar-first. Closing the dashboard leaves the process and MenuBarExtra running. Quit terminates all monitoring.

## Scene model

| Scene | Role | Lifecycle |
| --- | --- | --- |
| MenuBarExtra | Persistent status and pinned quick view | Exists while app runs |
| Dashboard Window | Repository/filter/PR management | Singleton, opened on demand |
| Settings | Native preferences | Opened on demand |
| AppKit NSPanel | Transient notch/fallback event | Created and owned by a focused coordinator |

The app intentionally behaves as an accessory/menu-bar utility rather than presenting a normal dashboard at login. The implementation must still make dashboard activation and focus reliable.

## Module boundaries

Suggested source layout:

- App: app entry point, app delegate, scene wiring
- Views: dashboard shell, sidebar, PR list/detail, menu-bar popover, settings, notch event view
- Models: account, repository, PR summary, normalized CI/merge states, transition event, filter configuration
- Stores: app state, repository selection, pins, settings, PR snapshot/history persistence
- Services: GitHub auth, GitHub GraphQL client, refresh coordinator, transition detector, notification router, launch-at-login
- Platform: Keychain wrapper and the narrow AppKit notch-panel bridge
- Support: logging/redaction, clock abstraction, URL routing, formatters

SwiftUI owns display state. AppKit owns only panel/window objects and publishes small callbacks such as event clicked, hover changed, and dismissal completed. It must not become a second state architecture.

## State ownership

- App-wide session and cache: one root observable app model.
- Durable secrets: Keychain service.
- Durable non-secret entities: SwiftData.
- User preferences: SwiftData or AppStorage where the value is truly a preference.
- Dashboard selection: scene-owned state, using scene storage where useful.
- Refresh/network work: actors, never views.
- Notch event queue: notification router actor; the AppKit coordinator only presents the current event.

## Alternatives considered

### Electron or a web wrapper

Rejected. The app depends heavily on menu-bar scenes, Keychain, launch-at-login, native notifications, display safe-area geometry, and nonactivating panels. A web runtime would add resource cost and platform bridging without improving the MVP.

### Pure AppKit

Rejected. AppKit is appropriate for the panel boundary, but SwiftUI provides a cleaner current implementation for the dashboard, settings, and menu-bar surfaces.

### Pure SwiftUI with no AppKit

Rejected for the notch panel. SwiftUI can render the content but does not expose all positioning, focus, collection behavior, and nonactivating panel control needed for a reliable top-of-screen transient overlay.

### Swift Package executable instead of an Xcode app project

Rejected for the shipped app. An Xcode application target provides straightforward capabilities, entitlements, archiving, Developer ID signing, notarization, and asset management.

### Codable files instead of SwiftData

Not selected. The cache contains stable identities, selected repositories, pins, last snapshots, and bounded transition history. SwiftData gives typed querying and migrations with little additional infrastructure on a macOS-26-only target.

## Consequences

Positive:

- Native behavior and low idle overhead.
- Clear boundary around the only specialized AppKit code.
- Modern APIs without old-version branches.
- Testable services independent from SwiftUI.
- Straight path to signing and notarization.

Negative:

- macOS 26 excludes users on older systems.
- SwiftData migrations must be planned once the schema ships.
- Accessory-app activation and panel behavior require real-device UI testing.
- The notch panel cannot be validated completely in previews or unit tests.

## Validation

- Build and launch a real app bundle, not only SwiftUI previews.
- Exercise menu bar, dashboard open/close/reopen, Settings, login launch, termination, and multi-display behavior.
- Unit-test normalization, filter compilation, diffing, deduplication, backoff, and pin limits.
- UI-test dashboard keyboard navigation and pin replacement.
- Run the notch matrix defined in ADR 004.
