# ADR 003: Polling, transition detection, and notifications

Status: Accepted for MVP
Date: 2026-08-09

## Context

The product should surface PR changes within roughly one minute but will not run a backend in the MVP. GitHub recommends webhooks over aggressive polling, yet a local macOS client cannot receive reliable public webhooks while sleeping, offline, behind NAT, or not running.

Notifications must describe actual transitions rather than repeatedly announcing the current state. The app must also avoid a burst of historical events on first sync or after changing repositories/filters.

## Decision

Use adaptive local polling with a desired one-minute interval while the app is running.

The refresh coordinator:

- Is a single actor and permits one cycle at a time.
- Coalesces timer, manual, popover-open, dashboard-open, wake, and network-restored triggers.
- Batches GraphQL queries and asks only for required fields.
- Reads rate-limit information on responses.
- Uses exponential backoff with jitter after failures.
- Honors Retry-After and rate-limit reset information over the one-minute target.
- Refreshes immediately after wake/network recovery following a short debounce.
- Stops when the user quits.

A one-minute interval is a target, not a real-time guarantee.

## Transition pipeline

1. Fetch and normalize current PR data.
2. For a previously tracked PR missing from the open-search result, perform a targeted lookup before deciding whether it closed, merged, stopped matching, or is temporarily absent.
3. Compare the verified current state with the last successfully persisted normalized snapshot.
4. Emit semantic changes only.
5. Persist the new snapshot transactionally.
6. Route changes to enabled delivery channels.

No events are emitted for:

- The initial successful sync.
- A PR newly included because a repository/filter was enabled.
- Raw check changes that leave the normalized CI result unchanged.
- A repeated snapshot.
- Data that could not be refreshed.

Tracked event kinds:

- CI state changed.
- Merge state changed.
- PR became merged or closed.

Event identity includes PR global ID, event kind, new value, and an observation bucket. The router deduplicates identical events and coalesces multiple changes to the same PR into one human-readable notification when observed in the same cycle.

## Delivery routing

The notification router has independent channels:

- Notch/fallback custom panel
- macOS Notification Center
- Sound

Settings provide a global switch, per-event switches, and channel switches. All tracked event kinds are enabled in MVP test builds. The user can send test notifications without generating fake persisted PR transitions.

The macOS system permission prompt appears only when the user turns on the Notification Center or sound behavior that requires authorization. Denial does not disable the custom notch channel.

## Failure behavior

- Offline: show cached data and stale age; wait for network restoration.
- 401/invalid token: coordinate one refresh; if it fails, require reauthorization.
- 403/rate limited: honor server timing and expose the paused state.
- 5xx/timeout: back off with jitter while preserving cache.
- Partial GraphQL response: accept valid PRs, record field-level unknowns/errors, and avoid overwriting a known value with a transient missing value unless policy explicitly marks the record stale.
- Repeated failure: never notify a state transition inferred only from absence.

Suggested retry sequence is implementation-controlled, bounded, and reset after a successful cycle. It must not exceed GitHub’s instructions in response headers.

## Alternatives considered

### Fixed timer with unconditional requests

Rejected. It causes overlapping work, ignores sleep/network state, and can worsen rate limiting.

### GitHub webhooks

Deferred. Webhooks are the preferred eventual near-real-time design but need a reachable service, durable event delivery, tenant identity, and additional privacy/security operations.

### APNs-only

Rejected for the local MVP because APNs would still need a server to receive GitHub events and send pushes.

### Diff raw GraphQL payloads

Rejected. Ordering and incidental field changes would produce noise. Only normalized product state should generate events.

## Consequences

Positive:

- No hosted infrastructure or ongoing backend cost.
- Simple privacy model.
- Predictable one-minute desired freshness.
- Deterministic transition tests.

Negative:

- Not real time.
- Polling pauses if the app is quit, suspended, sleeping, or offline.
- The product must expose stale/backoff state.
- Query design must be measured against GraphQL cost and node limits.

## Validation

- Use an injected clock and mock GitHub client.
- Prove no notification on initial sync and repository/filter baseline changes.
- Prove exactly one event for repeated identical results.
- Prove coalescing when CI and mergeability change in one cycle.
- Prove no false “closed” event on a failed/partial search.
- Prove backoff, Retry-After, token refresh serialization, wake/network debounce, and cancellation on quit.
- Measure query cost with representative selected repositories and filters.

## Sources

- GitHub GraphQL rate and query limits: https://docs.github.com/en/graphql/overview/rate-limits-and-query-limits-for-the-graphql-api
- GitHub recommends webhooks instead of polling when practical: https://docs.github.com/en/graphql/overview/rate-limits-and-query-limits-for-the-graphql-api
- Apple notification authorization guidance: https://developer.apple.com/documentation/UserNotifications/asking-permission-to-use-notifications
