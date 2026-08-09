# GitPings Product Requirements

Status: Draft for review
Date: 2026-08-09
Owner: Razeen Ali
Platform: macOS Tahoe 26 and newer
Working name: GitPings

## 1. Product summary

GitPings is a native macOS menu-bar utility that signs into one GitHub.com account, lets the user select repositories, and monitors configurable sets of open pull requests. It presents current CI and mergeability status in a dashboard and a compact menu-bar popover. Up to five PRs can be pinned for immediate access.

When a tracked PR changes state, GitPings shows a short notification that expands visually from the MacBook notch. On a display without a notch, the same notification appears as a top-center floating pill. The first release is local-only and read-only: it can open a PR on GitHub but cannot approve, merge, close, rerun, or modify anything.

## 2. Problem

AI coding agents can create enough concurrent pull requests that checking each repository manually becomes expensive. Existing GitHub pages are comprehensive, but they are not ambient: the user must remember what to check, switch context, and repeatedly scan for changes.

GitPings should answer three questions at a glance:

1. Which tracked PRs need attention?
2. Did CI change?
3. Can the PR be merged now?

## 3. Goals

- Authenticate one GitHub.com user securely.
- Support public and private repositories the installed GitHub App is permitted to read.
- Let the user select and deselect repositories.
- Let the user configure which open PRs are included using GitHub-compatible filter concepts.
- Show CI and mergeability status for each tracked PR.
- Let the user pin at most five PRs.
- Keep pinned status available from a persistent menu-bar icon.
- Poll once per minute while the app is running.
- Detect genuine state transitions without notifying on the initial sync.
- Show configurable notch and macOS notifications for tracked transitions.
- Keep the dashboard closable while the menu-bar process continues running.
- Support launch at login.
- Package the app so it can be shared safely with teammates and later installed through Homebrew Cask.
- Keep the MVP client-only: the Mac app communicates directly with GitHub and stores state locally.

## 4. Non-goals for MVP

- GitHub Enterprise Server or multiple GitHub accounts.
- Editing a PR or repository.
- Approving, merging, closing, commenting, rerunning CI, or updating a branch.
- Hosting a backend or receiving GitHub webhooks.
- Vercel, Convex, a custom OAuth callback service, or any other GitPings-operated server.
- Exact real-time updates.
- Tracking deployment environments, review details, comments, or individual CI log output.
- Mobile, web, Windows, or Linux clients.
- Mac App Store distribution.
- Automatic in-app updates.
- Team-wide shared pin lists or cloud synchronization.

## 5. Primary user

A developer who works across several repositories and has multiple human- or agent-authored PRs open at once. The user wants ambient awareness without keeping GitHub tabs open.

One local app installation maps to one authorized GitHub account. Teammates install and authorize their own copies.

## 6. Core concepts

### Selected repository

A GitHub repository explicitly enabled for monitoring. Repository selection is independent of PR filters.

### Tracked PR

An open PR in a selected repository that matches at least one enabled PR filter.

### Pinned PR

A tracked PR promoted to the menu-bar quick view. Pins persist across launches. The maximum is five.

### CI state

The normalized rollup of GitHub checks and commit statuses:

| GitPings state | Meaning |
| --- | --- |
| Passing | GitHub reports the rollup as successful. |
| Pending | At least one relevant check is queued, expected, or running and no failure is final. |
| Failing | GitHub reports a failed, errored, cancelled, timed-out, or action-required result. |
| No checks | GitHub provides no status-check rollup for the PR head. |
| Unknown | Status could not be calculated or fetched. |

### Merge state

The normalized combination of GitHub mergeable and merge-state fields:

| GitPings state | Meaning |
| --- | --- |
| Mergeable | GitHub reports the head and base can be merged and no known blocking merge state is present. |
| Blocked | The branches can merge technically, but GitHub reports a policy or required condition is blocking merge. The MVP does not explain every policy. |
| Conflicting | GitHub reports merge conflicts or a dirty merge state. |
| Checking | GitHub is still calculating mergeability. |
| Unknown | The value is absent, stale, or could not be fetched. |

CI and merge state must remain separate. “CI passing” does not imply “mergeable,” and “mergeable” does not imply all required checks passed.

## 7. Functional requirements

### AUTH — GitHub authentication

- AUTH-1: The first launch presents “Sign in with GitHub.”
- AUTH-2: Authentication uses a registered public GitHub App and GitHub’s OAuth device flow.
- AUTH-2A: The device flow communicates directly between the Mac app and GitHub and requires no GitPings callback URL or callback server.
- AUTH-3: The onboarding explains that the GitHub App must be installed for the repositories or organizations the user wants to monitor.
- AUTH-4: The app requests read-only GitHub App permissions needed for repository metadata, pull requests, checks, and commit statuses.
- AUTH-5: Access and refresh tokens are stored only in macOS Keychain.
- AUTH-6: The app never embeds a GitHub client secret or GitHub App private key.
- AUTH-7: Revoked, expired, or insufficient authorization produces a recoverable sign-in state rather than silently showing an empty list.
- AUTH-8: Signing out removes tokens and locally cached private repository/PR data after confirmation. User preferences that contain no GitHub data may remain.

### REPO — Repository selection

- REPO-1: After sign-in, the user can browse repositories available through their GitHub App installations.
- REPO-2: The repository picker supports search by owner and repository name.
- REPO-3: The list visually distinguishes public/private and personal/organization repositories.
- REPO-4: Repository selection persists locally.
- REPO-5: Repositories removed from an installation become unavailable and their tracked PRs are removed from active views.
- REPO-6: The empty state explains how to install or update GitHub App repository access.

### FILTER — Configurable PR inclusion

- FILTER-1: Only open PRs from selected repositories are eligible.
- FILTER-2: The user can independently enable:
  - All open PRs
  - Authored by me
  - Assigned to me
  - Review requested from me
- FILTER-3: Multiple enabled filters use OR semantics and duplicate PRs are merged into one result.
- FILTER-4: The authenticated GitHub login is resolved first and used in generated GitHub search qualifiers.
- FILTER-5: The filter compiler uses GitHub search syntax and GraphQL search rather than implementing semantic filtering from a complete local download.
- FILTER-6: Advanced raw GitHub search syntax is deferred until after MVP.
- FILTER-7: Filter changes trigger an immediate refresh and establish a new notification baseline for newly included PRs.

### PR — Dashboard and status

- PR-1: The dashboard is an on-demand, single-instance window.
- PR-2: Closing the dashboard does not quit monitoring or remove the menu-bar item.
- PR-3: The dashboard has a native sidebar for selected repositories and a main PR list.
- PR-4: Each PR row shows repository, PR number, title, author, CI state, merge state, and last successful refresh time.
- PR-5: The list can be narrowed to one selected repository or all selected repositories.
- PR-6: The list supports title/number search over locally loaded results.
- PR-7: Selecting a PR shows a lightweight detail pane with the same status, source/base branch names, updated time, and “Open on GitHub.”
- PR-8: The app clearly marks stale data when a refresh has not succeeded for more than three expected polling intervals.
- PR-9: Unknown values are shown honestly and never rendered as passing or mergeable.

### PIN — Pinning

- PIN-1: A tracked PR can be pinned or unpinned from its row, detail pane, or contextual menu.
- PIN-2: Pins persist across launches using the GitHub global node ID as identity.
- PIN-3: At most five PRs may be pinned.
- PIN-4: When the limit is reached, pinning another PR opens a small replacement chooser; the app must not silently evict a pin.
- PIN-5: A pinned PR that closes or no longer matches filters remains visible long enough to communicate its final known state and can then be removed by the user.
- PIN-6: Pins are ordered manually, with newly pinned items added last.

### MENUBAR — Quick status

- MENUBAR-1: A persistent template icon appears in the system menu bar while the app runs.
- MENUBAR-2: Clicking the icon opens a window-style menu-bar popover.
- MENUBAR-3: The popover shows up to five pinned PRs with compact CI and merge status.
- MENUBAR-4: Each visible title is truncated to keep the popover scannable; full titles remain available in the dashboard.
- MENUBAR-5: Clicking a pinned PR opens it on GitHub.
- MENUBAR-6: The popover exposes Refresh, Open Dashboard, Settings, and Quit.
- MENUBAR-7: The menu-bar icon summarizes the most severe pinned state:
  - Failure/conflict: attention state
  - Pending/checking/unknown: in-progress state
  - All passing and mergeable: healthy state
  - No pins: neutral state
- MENUBAR-8: State is not communicated by color alone.

### REFRESH — Polling

- REFRESH-1: The desired polling interval is 60 seconds while the app process is running and the network is available.
- REFRESH-2: Opening the popover/dashboard and choosing Refresh may trigger an immediate coalesced refresh.
- REFRESH-3: Only one refresh cycle may run at a time.
- REFRESH-4: The client batches GraphQL work and requests only fields used by the product.
- REFRESH-5: The client records GitHub rate-limit information and backs off on rate limiting, authentication errors, network failures, or server errors.
- REFRESH-6: Backoff takes precedence over the one-minute target and is visible in Settings/status UI.
- REFRESH-7: Wake from sleep or network restoration triggers one refresh after a short debounce.
- REFRESH-8: Quitting the app stops polling. No daemon or remote service remains.
- REFRESH-9: The app does not promise polling execution while macOS has suspended or terminated it.

### CHANGE — Transition detection

- CHANGE-1: Each successful refresh is compared with a persisted last-known snapshot.
- CHANGE-2: The first successful sync, newly selected repository, and newly enabled filter establish baselines without generating historical notifications.
- CHANGE-3: A transition includes:
  - CI state changed
  - Merge state changed
  - A tracked PR became closed or merged
- CHANGE-3A: Disappearance from an open-PR search is not itself a closed/merged transition. The client performs a targeted lookup of the previously tracked PR before classifying its final state.
- CHANGE-4: Multiple raw GitHub check changes that normalize to the same CI state do not notify.
- CHANGE-5: Repeated identical snapshots do not notify.
- CHANGE-6: Events are deduplicated by PR, state kind, new value, and observation window.
- CHANGE-7: The event record includes repository, PR number/title, old state, new state, and observation time.

### NOTIFY — Notch and system notifications

- NOTIFY-1: Every tracked transition type is enabled by default during MVP testing.
- NOTIFY-2: Settings provide a master notification toggle.
- NOTIFY-3: Settings provide per-event toggles for CI, mergeability, and closed/merged transitions.
- NOTIFY-4: Settings provide independent delivery-channel toggles for notch UI, sound, and macOS Notification Center.
- NOTIFY-5: The notch notification is enabled by default; system notifications and sound may be changed by the user.
- NOTIFY-6: The app requests macOS notification permission in context, when the user enables the system channel, not automatically at launch.
- NOTIFY-7: A notification click opens the PR on GitHub.
- NOTIFY-8: Notification text contains no source code, comments, or other repository content beyond repository name, PR number/title, and state transition.
- NOTIFY-9: The app provides a “Send test notification” action for each delivery channel.

### NOTCH — Notch presentation

- NOTCH-1: The app uses only public macOS APIs.
- NOTCH-2: On a display with a nonzero top safe-area inset, the panel anchors at the top center around the obscured/notch region.
- NOTCH-3: On a display without a notch, the panel uses a compact top-center floating-pill fallback.
- NOTCH-4: The panel does not activate the app or steal keyboard focus when appearing.
- NOTCH-5: The compact event view shows repository/PR identity, a state icon, a short transition such as “CI passed,” and age if queued.
- NOTCH-6: A single event remains visible for approximately four seconds, then collapses.
- NOTCH-7: Hover pauses dismissal; clicking opens the PR on GitHub.
- NOTCH-8: Events arriving close together are queued and coalesced. The compact UI shows at most three queued events before summarizing the remainder.
- NOTCH-9: The notification respects Reduce Motion by replacing expansion/spring animations with a short fade.
- NOTCH-10: The panel never renders underneath the camera housing.
- NOTCH-11: Screen lock suppresses the custom panel. Full-screen behavior is configurable, with suppression as the default.
- NOTCH-12: The first implementation is a transient notification, not a permanent interactive “Dynamic Island.”

### SETTINGS — Preferences

- SETTINGS-1: Settings is a dedicated macOS Settings scene.
- SETTINGS-2: Settings sections include Account, Repositories, PR Filters, Notifications, Refresh, Appearance, and General.
- SETTINGS-3: General includes Launch at Login, managed with the current Service Management API.
- SETTINGS-4: Refresh shows interval, last attempt, last success, next eligible attempt, and rate-limit/backoff state. The MVP interval is fixed at one minute but represented as a future-configurable setting.
- SETTINGS-5: Appearance includes notch notifications, fallback pill, full-screen suppression, and Reduce Motion status.
- SETTINGS-6: Account exposes current GitHub login, accessible installation/repository count, Reauthorize, and Sign Out.

### LIFECYCLE — App behavior

- LIFECYCLE-1: The app is primarily a menu-bar utility and does not require the dashboard to remain open.
- LIFECYCLE-2: Launch at login is opt-in during onboarding and editable later.
- LIFECYCLE-3: If launched at login, the app starts quietly in the menu bar without opening the dashboard.
- LIFECYCLE-4: Selecting Open Dashboard brings the existing dashboard to the foreground.
- LIFECYCLE-5: Quit is explicit and terminates monitoring.

## 8. Main user journeys

### First run

1. Launch GitPings.
2. Read a concise privacy/read-only explanation.
3. Sign in with GitHub using the device flow.
4. Install or authorize the GitHub App for selected accounts/repositories.
5. Choose repositories.
6. Choose PR filters; default to Authored by me, Assigned to me, and Review requested from me.
7. Enable launch at login.
8. See the initial PR list without historical notifications.
9. Optionally send a test notch notification.

### Pin and monitor

1. Open the dashboard from the menu bar.
2. Find a PR.
3. Pin it.
4. Close the dashboard.
5. Inspect its current state from the menu-bar popover.
6. Receive a notch notification when CI or merge state changes.
7. Click the notification to open the PR on GitHub.

### Recover authorization

1. A refresh receives an authentication/permission failure.
2. GitPings keeps the last cache but marks it stale.
3. The menu and dashboard show “Reauthorize GitHub.”
4. The user signs in or updates the GitHub App installation.
5. Refresh resumes and establishes baselines for newly visible PRs.

## 9. Local data

GitPings stores locally:

- GitHub account ID/login and installation metadata.
- Selected repository IDs and display metadata.
- Enabled filter configuration.
- Up to five pinned PR global IDs and order.
- The current PR status cache.
- The previous normalized status snapshot needed for transition detection.
- User settings and notification preferences.
- Minimal recent transition history for debugging, with a bounded retention window.

Secrets:

- Access and refresh tokens live in Keychain only.
- No client secret or GitHub App private key is shipped.
- Logs must redact tokens, authorization headers, device codes, and private API payloads.

MVP data is local to each Mac and is not synced.

### System boundary

The MVP has exactly two runtime systems:

1. The GitPings macOS app.
2. GitHub.com and its documented OAuth/API endpoints.

GitPings does not send data through a developer-operated service. Vercel and Convex are intentionally excluded. They remain future options only if the product later needs webhook ingestion, near-real-time push, shared/team state, a web dashboard, or cross-device synchronization.

## 10. Quality requirements

### Performance

- Menu-bar popover should appear from local cache in under 200 ms on supported hardware.
- Dashboard should show cached content immediately and refresh asynchronously.
- Idle CPU should remain negligible between polling cycles.
- The one-minute timer must not busy-wait.

### Reliability

- One malformed PR response must not discard the rest of a successful page.
- Cached state survives ordinary relaunches.
- Failed refreshes preserve the last successful snapshot and show its age.
- Rate-limit and network errors use bounded exponential backoff with jitter.

### Privacy and security

- Read-only GitHub App repository permissions.
- Keychain-backed token storage.
- HTTPS only.
- No analytics, crash upload, or backend in MVP.
- No notification content beyond metadata required to identify the PR and transition.
- App Sandbox and Hardened Runtime enabled for release builds unless a documented implementation constraint requires reconsideration.

### Accessibility

- Complete keyboard navigation for dashboard, pinning, Settings, and menu actions.
- VoiceOver labels for icon-only status.
- Shape/text accompany color.
- Reduce Motion is respected.
- System text sizing and high-contrast modes remain legible.

## 11. MVP acceptance criteria

The MVP is acceptable when all of the following are demonstrated on macOS 26:

1. A user signs into one GitHub.com account without entering a PAT.
2. The app lists repositories granted to the GitHub App, including a private repository in a test organization.
3. The user selects repositories and enables a configurable combination of the four defined PR filters.
4. Open matching PRs appear with normalized CI and merge states.
5. The user pins, reorders, and unpins PRs, and cannot exceed five without choosing a replacement.
6. The menu-bar popover renders cached pinned state even when the dashboard is closed.
7. A mocked or real CI transition creates exactly one notch event and no initial-sync event.
8. Mergeable, blocked, conflicting, checking, and unknown states are visually distinguishable.
9. A notched Mac anchors the test event around the notch without covering visible menu-bar content.
10. A notchless/external display uses the top-center fallback.
11. Notification, event-type, sound, full-screen, and launch-at-login settings persist.
12. Offline, token-expiry, and rate-limit scenarios preserve cached state and expose recovery.
13. Quit stops all polling.
14. A Developer ID–signed, Hardened Runtime–enabled, notarized build passes Gatekeeper assessment on a teammate’s Mac.
15. A test Homebrew Cask can install the notarized app from a versioned release artifact.

## 12. Delivery phases

### Phase 0 — Technical spikes

- Register a development GitHub App and verify the minimum read-only permissions.
- Prove device-flow sign-in and Keychain token refresh.
- Prove a GraphQL query that returns selected-filter PRs, status-check rollup, mergeable, and merge-state status.
- Prototype notch geometry on a notched Mac, notchless Mac/external monitor, full screen, multiple displays, and Reduce Motion.
- Measure one-minute query cost and node count on a representative account.

### Phase 1 — Core dashboard

- Authentication, repository selection, filters, status cache, dashboard, and open-on-GitHub.

### Phase 2 — Ambient monitoring

- Pinning, menu-bar popover, polling, diffing, settings, launch at login, and test notifications.

### Phase 3 — Notch UX and distribution

- Production notch panel, accessibility, signing, notarization, release artifact, and private Homebrew tap.

### Later candidates

- Configurable refresh intervals.
- Review and deployment status.
- Advanced raw GitHub search views.
- GitHub Enterprise and multiple accounts.
- Webhook-backed near-real-time updates.
- Read/write actions with a separate permission review.
- Automatic updates and a public Homebrew Cask.

## 13. Open product decisions

- Final product name, icon, and bundle identifier.
- Whether native macOS Notification Center and sound should default on or off for non-test releases.
- Whether a closed/merged pinned PR should auto-unpin after a grace period.
- Whether the notch fallback should follow the display containing the pointer, the active window, or only the built-in display.
- Retention duration for local transition history.

## 14. Source notes

- GitHub supports search qualifiers for pull requests and saved views: https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/filtering-and-searching-issues-and-pull-requests
- GitHub GraphQL queries support GitHub search syntax and paginated connections: https://docs.github.com/en/graphql/reference/queries and https://docs.github.com/en/graphql/guides/using-pagination-in-the-graphql-api
- GitHub GraphQL rate limits are point-based and authenticated user access normally receives 5,000 points per hour: https://docs.github.com/en/graphql/overview/rate-limits-and-query-limits-for-the-graphql-api
- Apple provides MenuBarExtra for persistent menu-bar controls and a window style for richer content: https://developer.apple.com/documentation/swiftui/menubarextra
- macOS exposes screen safe-area and auxiliary top-region geometry through NSScreen: https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea-uglc
- Notification permission should be requested in context: https://developer.apple.com/documentation/UserNotifications/asking-permission-to-use-notifications
- SMAppService manages launch at login on current macOS: https://developer.apple.com/documentation/servicemanagement/smappservice
