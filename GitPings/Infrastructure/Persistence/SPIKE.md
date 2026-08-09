# S3/S4 Persistence + monitoring feasibility spike

**Task:** S3/S4 — Persistence, sandbox, monitoring contracts  
**Branch:** `codex/wave-0-foundation`  
**Host note:** This Cloud Agent runs on Linux. SwiftData runtime, App Sandbox, Keychain, and SMAppService were **not** executed here. Claims below are design/feasibility notes for integrator review on a macOS Tahoe host — **not** sandbox/runtime verification.

Requirement IDs: PIN-1..6, REFRESH-1..9, CHANGE-1..7, SETTINGS-1..6, local data §9  
ADRs: ADR-001, ADR-003, ADR-005

---

## Schema version 1 (SwiftData)

`SchemaVersion.v1 = 1`. All durable non-secret entities live in one ModelContainer. Tokens remain Keychain-only (ADR-001 / AUTH-5).

| Entity | Purpose | Identity / keys | Notes |
| --- | --- | --- | --- |
| `AccountMetadataRecord` | Signed-in GitHub account login + node ID, installation count cache | `accountNodeID` (unique) | One account per installation (MVP) |
| `SelectedRepositoryRecord` | User-selected repos | `repositoryNodeID` (unique) | Display metadata cached for offline UI |
| `FilterConfigurationRecord` | PR filter toggles | singleton `id = "filters"` | Changing filters → refresh + baseline (CHANGE-2) |
| `PinRecord` | Up to five pinned PR node IDs + order | `pullRequestNodeID` (unique), `sortIndex` | Hard cap via `PinPolicy.maximumPinCount`; no silent eviction |
| `CachedPullRequestRecord` | Current PR status cache | `pullRequestNodeID` (unique) | Dashboard/menu-bar read path |
| `NormalizedSnapshotRecord` | Last successful normalized snapshot for diffs | `pullRequestNodeID` (unique) | Transition baseline (CHANGE-1) |
| `AppSettingsRecord` | Notification/refresh/appearance prefs | singleton `id = "settings"` | Master + per-event + per-channel toggles |
| `TransitionHistoryRecord` | Bounded debug history | `eventID` (UUID, unique), `observedAt` | Retain newest 100 **or** drop older than 7 days |

### Field mapping (conceptual)

- **Account:** `accountNodeID`, `login`, `installationCount`, `updatedAt`
- **Selected repo:** `repositoryNodeID`, `nameWithOwner`, `visibility`, `isOrganizationOwned`, `selectedAt`
- **Filters:** `includeAllOpen`, `includeAuthoredByMe`, `includeAssignedToMe`, `includeReviewRequestedFromMe`
- **Pin:** `pullRequestNodeID`, `sortIndex` (0…n-1), `pinnedAt`
- **PR cache / snapshot:** serialized normalized fields matching `PullRequestSummary` (CI/merge/lifecycle enums as raw strings); never store tokens
- **Settings:** `notificationsMasterEnabled`, `notifyCI`, `notifyMerge`, `notifyClosedOrMerged`, `channelNotch`, `channelSystem`, `channelSound`, `suppressInFullScreen`, `desiredRefreshIntervalSeconds` (fixed 60 for MVP), `updatedAt`
- **History:** `eventID`, `pullRequestNodeID`, `repositoryNameWithOwner`, `number`, `title`, `kind`, `oldValue`, `newValue`, `observedAt`

Migration plan: v1 is the first shipped schema. Additive migrations only after Gate 0 freeze; destructive sign-out purge is explicit, not a migration.

---

## Identities

- **Canonical PR / repo / account identity:** GitHub GraphQL global node ID (`GitHubNodeID`), persisted as `String`.
- Pins, cache rows, and snapshots key exclusively on node IDs (PIN-2).
- Repository `nameWithOwner` and PR `number` are display aids only; renames must not break pin identity.
- Transition event dedupe key (CHANGE-6): `(pullRequestNodeID, kind, newValue, observationBucket)` where bucket is derived from the injected clock (same refresh cycle → same bucket).

---

## Sign-out purge

On sign-out, Monitoring Core clears all private GitHub-derived local data:

1. `PRCacheStore.purgePrivateGitHubData()`
2. Clear pins, snapshots, transition history, selected repositories, account metadata
3. Reset filters/settings to MVP defaults (or wipe settings row — integrator chooses UX; spike defaults to MVP notification defaults)
4. Coordinate with GitHub Platform: `KeychainTokenStore.deleteAllTokens()` (not owned here)

Purge is transactional where SwiftData allows (`ModelContext` save after deletes). Incomplete purge must surface as an error, not a partial silent state.

---

## Store protocol conformance (Domain — read-only)

| Domain protocol | Spike implementation |
| --- | --- |
| `PinStore` | `InMemoryPinStore` (+ SwiftData sketch `SwiftDataPinStore`) |
| `PreferencesStore` | `InMemoryPreferencesStore` |
| `PRCacheStore` | `InMemoryPRCacheStore` |
| `SnapshotStore` | `InMemorySnapshotStore` |
| `TransitionHistoryStore` | `InMemoryTransitionHistoryStore` |

In-memory stores are the deterministic test surface on any host that can compile the target. SwiftData `@Model` drafts document the durable shape for Gate 0 freeze.

---

## Monitoring pipeline sketch

1. `RefreshCoordinator` (single-flight + trigger coalescing, injected `ClockProviding`, no wall sleeps)
2. Fetch/normalize PRs via `PullRequestQueryService` (GitHub Platform)
3. For PRs missing from open search: **targeted lookup** before classification (CHANGE-3A)
4. `TransitionDetector` pure diff (`baselineMode` → zero events)
5. Persist cache + snapshots transactionally
6. `NotificationRouter` applies toggles; test notifications **never** append history

---

## Sandbox / packaging notes (integrator review — unverified on this host)

Entitlements file (read-only here) currently enables:

- `com.apple.security.app-sandbox` = true
- `com.apple.security.network.client` = true

| Capability | Expected entitlement / API | Spike assessment |
| --- | --- | --- |
| GitHub HTTPS | `network.client` | Present; required |
| SwiftData app-group / default store | Sandboxed container Application Support | Compatible with sandbox; no extra entitlement expected |
| Keychain tokens | Default keychain access group for app ID | GitHub Platform owns; sandbox-compatible with standard Keychain Services |
| Notch / Notification Center | UserNotifications + AppKit panel | No sandbox conflict anticipated; system channel needs user authorization (NOTIFY-6) |
| Launch at login | `SMAppService` | May require additional entitlement/`Info.plist` keys — **confirm on Mac**; out of Monitoring write scope |
| Hardened Runtime + notarization | ADR-005 | Release gate only; unsigned spike is **not** release-ready |

**Do not treat this spike as sandbox runtime proof.** Integrator must validate container paths, Keychain, network, and SMAppService on macOS Tahoe before claiming Gate 0 packaging readiness.

---

## Feasibility verdict (design)

- Schema v1 covers local data §9 without secrets in SwiftData.
- Pin limit/replacement and transition rules are expressible as pure/in-memory logic with deterministic fixtures.
- Refresh single-flight + coalescing + injected clock are testable without wall sleeps.
- Sandbox appears compatible for Monitoring Core storage/network needs; SMAppService and live sandbox behavior remain Mac blockers.

## Blockers

- No Xcode/SwiftData runtime on Linux Cloud Agent
- No App Sandbox execution proof
- No Developer ID / notarization (later gates)
