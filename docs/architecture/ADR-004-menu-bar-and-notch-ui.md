# ADR 004: Menu-bar and notch presentation

Status: Accepted for MVP, with a real-device spike required
Date: 2026-08-09

## Context

GitPings needs two ambient surfaces:

1. A persistent menu-bar control for inspecting up to five pinned PRs.
2. A transient top-center notification for state changes.

Apple provides a native MenuBarExtra for the first surface. Apple does not provide a “Dynamic Island for Mac” notification component. A notch-attached experience therefore requires a custom window using public display geometry and AppKit panel behavior.

Existing notch utilities commonly use a collapsed black top-center region that expands briefly for activity and provide a simulated pill on notchless/external displays. GitPings should adopt the useful interaction grammar, not become a general-purpose notch replacement.

## Decision

### Menu-bar quick view

Use SwiftUI MenuBarExtra with window style.

The popover:

- Opens from a persistent template icon.
- Shows no more than five pinned PRs.
- Uses compact one- or two-line rows.
- Shows CI and merge status with icon, text, and color.
- Opens the PR on GitHub when a row is clicked.
- Provides Refresh, Open Dashboard, Settings, and Quit.

The menu-bar icon reflects the highest-severity pinned state without relying on color alone.

### Notch notification

Use a small AppKit NSPanel coordinator hosting a SwiftUI event view.

The exact SwiftUI capability gap is top-center screen placement plus reliable nonactivating floating-panel lifecycle. AppKit owns the panel; SwiftUI remains the source of rendered content and app state.

Use public NSScreen geometry:

- A nonzero top safe-area inset indicates an obscured top region.
- Auxiliary top-left and top-right regions describe usable areas around that obstruction.
- The panel frame is derived from the active target screen; no model-name table or private camera/notch API is used.

Presentation:

- Start visually merged with the top-center black/notch region.
- Expand downward into a compact rounded capsule/card.
- Show repository and PR number, a short title, state icon, and transition text.
- Remain for about four seconds.
- Pause while hovered.
- Open the PR on click.
- Collapse without activating the app or stealing keyboard focus.

If multiple events arrive, show up to three sequentially and summarize overflow. Changes observed for the same PR in one refresh cycle are coalesced.

### Fallback

On a screen with no top obstruction, show the same content as a top-center floating pill below the menu bar. The fallback can be disabled in Settings.

### Display policy

For MVP:

- Prefer the display where the menu-bar interaction or active app context exists, subject to real-device findings.
- Suppress custom panels while the screen is locked.
- Suppress over full-screen apps by default, with an opt-in setting.
- Recompute geometry after display reconfiguration, resolution/scaling changes, wake, and menu-bar position changes.
- Never assume the primary display is the built-in notched display.

The technical spike must choose the final display-following rule after testing a notched laptop with an external monitor above, below, and beside it.

### Motion and accessibility

- Respect Reduce Motion with a short fade/scale-free transition.
- Provide VoiceOver text for every icon and state.
- Do not use color as the only signal.
- Keep notification content short enough to parse peripherally.
- A custom notch panel is supplementary; the same state remains available in the menu-bar popover and optional Notification Center.

## UX state sequence

1. Hidden/collapsed.
2. Event arrives.
3. Expand downward without focus.
4. Hold for approximately four seconds.
5. Hover pauses; click opens GitHub.
6. Collapse or advance to the next queued event.

Recommended compact copy examples:

- owner/repo #142 — CI passed
- owner/repo #142 — CI failed
- owner/repo #142 — Mergeable
- owner/repo #142 — Merge conflict
- owner/repo #142 — Merged

## Alternatives considered

### Use only macOS Notification Center

Rejected as the sole experience. It is reliable and remains an optional channel, but it does not meet the product’s notch-centered ambient identity.

### Put the entire app in the notch

Rejected. Repository selection, filters, settings, and detailed scanning need a real window. Overloading the notch would create cramped interaction and compete with menu-bar content.

### Pure SwiftUI overlay

Rejected. SwiftUI renders the content well, but a focused AppKit boundary is better for nonactivating panel level, placement, focus, hover lifetime, collection behavior, and display changes.

### Private notch/camera APIs or hardware model mapping

Rejected. Public safe-area geometry is sufficient for a resilient approximation and is compatible with signing/notarization.

### Permanent expanded notch

Deferred. The MVP is event-driven and transient to minimize distraction and collision with the system menu bar.

## Risks

- There is no first-party notch-notification control, so polish depends on custom geometry and animation.
- Custom panels can conflict with full-screen apps, Spaces, screen recording, and multi-display arrangements.
- Menu-bar auto-hide changes available geometry.
- A simulated fallback may feel intrusive on external displays.
- Public safe-area geometry identifies obstruction, not product intent; real-device testing is mandatory.

## Validation matrix

- Notched MacBook: menu bar visible and auto-hidden.
- Notched MacBook with external display: mirrored and extended.
- External display placed above, below, left, and right.
- Notchless display fallback enabled and disabled.
- Different display scaling modes.
- Full-screen app and multiple Spaces.
- Screen lock/unlock and sleep/wake.
- Reduce Motion and Increase Contrast.
- VoiceOver.
- Rapid single-PR changes and more than three queued events.
- Click, hover pause, timeout, and no focus theft.

## Sources and inspiration

- Apple MenuBarExtra and its window style: https://developer.apple.com/documentation/swiftui/menubarextra
- Apple NSScreen auxiliary top region: https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea-uglc
- DynamicLake demonstrates notch-attached transient notifications and an external-display mode: https://www.dynamiclake.com/notifications
- Notchy describes a native expandable notch utility and low-idle-overhead goal: https://notchy.dev/

These third-party products are interaction references only; GitPings must use its own design and public APIs.
