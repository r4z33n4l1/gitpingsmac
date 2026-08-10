# GitPings multi-agent execution plan

Status: Ready for execution after the dedicated repository baseline and Gate 0 decisions
Date: 2026-08-09
Goal: Deliver a tested, signed, notarized GitPings MVP that satisfies every acceptance criterion in REQUIREMENTS.md.

## 1. Completion standard

GitPings is finished only when:

1. The exact release commit passes the full automated suite.
2. Requirements acceptance criteria 1–15 pass.
3. Authentication, private repository access, polling, caching, pinning, menu-bar lifecycle, and notifications work together.
4. The notch experience passes the real-device display matrix.
5. Security review finds no unresolved critical or high-severity issue.
6. The Developer ID release is notarized, stapled, and accepted by Gatekeeper.
7. A teammate installs the same immutable artifact directly and through Homebrew without a security bypass.
8. The release commit, archive, artifact, checksum, GitHub Release, and Homebrew Cask are traceable to one another.

A successful Debug build is progress, not completion.

## 2. Scope lock

The delivery contract is:

- Requirements sections 3, 4, and 11.
- ADRs 001–005.
- AGENTS.md.

The following remain deferred:

- Backend infrastructure, Vercel, Convex, callback service, webhooks, and APNs server.
- GitHub write operations or broader permissions.
- Multiple accounts, GitHub Enterprise, older macOS support.
- Review/deployment details, advanced raw search, and automatic updates.

Every work item must map to requirement IDs or an acceptance criterion. New ideas go into the handoff’s Deferred suggestions section. Adding a feature mid-wave requires explicit user approval, an impact statement, and either a scope swap or schedule change.

## 3. Proposed baseline decisions

These defaults prevent agents from making inconsistent local choices. They can be changed only by the integrator before Gate 0 closes.

| Decision | Proposed value |
| --- | --- |
| Product name | GitPings |
| Bundle identifier | com.razeenali.gitpings |
| Platform | macOS Tahoe 26+ |
| Account model | One GitHub.com account per local app installation |
| Runtime boundary | Mac app directly to GitHub; local Keychain/SwiftData only |
| Polling target | 60 seconds while running, subject to backoff |
| Pin limit | Five, with explicit replacement |
| Closed/merged pin behavior | Notify once, then automatically remove from pins |
| Test notification defaults | All tracked event types enabled |
| Teammate-release defaults | Notch enabled; Notification Center and sound opt-in |
| Transition retention | Latest 100 events or seven days, whichever removes data first |
| Representative scale target | 25 selected repositories, 200 matching open PRs, five pins |

The display-following policy must be selected from real-device evidence during the notch spike rather than guessed.

## 4. Team topology

Use four concurrent slots:

| Role | Responsibility |
| --- | --- |
| Orchestrator / Integrator | Owns plan, project files, contracts, dependency wiring, integration, gates, traceability, and release |
| GitHub Platform Agent | Owns device auth, Keychain, repository discovery, GraphQL/search, pagination, normalization inputs, and rate metadata |
| Monitoring Core Agent | Owns SwiftData, pins, cache, polling, transition detection, deduplication, and notification routing |
| macOS Experience Agent | Owns onboarding/dashboard/menu/settings views, AppKit notch bridge, system notification UI, launch-at-login UI, and UI tests |

During verification, rotate ownership so a high-risk workstream is rerun by an agent that did not implement it. The author may fix failures; an independent verifier closes the gate.

## 5. Repository and branch safety

GitPings uses /Users/razeenali/Documents/Solo/gitpingsmac as its dedicated repository root. The parent Solo directory contains unrelated work and must never be used for GitPings Git operations.

Before parallel implementation, the integration owner:

1. Confirms the Git root is exactly the gitpingsmac directory.
2. Reviews and pushes the documentation baseline.
3. Creates integration and workstream branches/worktrees using the codex/ prefix.

Recommended branches:

- codex/gitpings-mvp-integration
- codex/gitpings-auth-data
- codex/gitpings-runtime
- codex/gitpings-ui

The main/shared worktree remains integration-only. If separate worktrees are unavailable, agents may share the filesystem only under the strict single-writer path rules below.

## 6. Source layout and ownership

The foundation phase should create this shape:

~~~text
gitpingsmac/
  GitPings.xcodeproj/
  GitPings/
    App/                         Integrator
    Domain/                      Integrator; frozen contracts
    Features/
      Authentication/           GitHub Platform
      Repositories/             GitHub Platform + UI-owned Views subfolder
      PullRequests/              Split by Services/Stores/Views ownership
      MenuBar/                   macOS Experience
      Notch/                     macOS Experience
      Settings/                  macOS Experience
    Infrastructure/
      GitHub/                    GitHub Platform
      Persistence/               Monitoring Core
      Keychain/                  GitHub Platform
    Services/
      Refresh/                   Monitoring Core
      Transitions/               Monitoring Core
      Notifications/             Monitoring Core
    Platform/
      NotchPanel/                macOS Experience
      SystemNotifications/       macOS Experience
      LaunchAtLogin/             macOS Experience
    Support/                      Integrator
  GitPingsTests/
  GitPingsUITests/
  Fixtures/
  artifacts/verification/
  script/build_and_run.sh
  .codex/environments/environment.toml
  docs/
~~~

Single-writer boundaries:

| Boundary | Sole owner |
| --- | --- |
| project.pbxproj, schemes, capabilities, entitlements, Info.plist | Integrator |
| App entry point, composition root, dependency container | Integrator |
| Domain enums, IDs, service protocols after contract freeze | Integrator |
| GitHub DTOs, auth, transport, query builder, filter compiler | GitHub Platform |
| SwiftData schema/migrations, stores, refresh/diff engine | Monitoring Core |
| Dashboard/menu/settings/notch views and panel bridge | macOS Experience |
| Requirements, ADRs, plan, scope log, traceability | Integrator |
| Release scripts, signing configuration, Cask | Integrator / named release owner |

Use filesystem-synchronized Xcode groups where practical so feature agents can add files without touching project.pbxproj.

## 7. Dependency graph

~~~mermaid
flowchart TD
    P0["P0: Scope lock and scoped Git baseline"] --> F0["F0: Xcode app, tests, run script, fixtures, protocols"]
    F0 --> S1["S1: GitHub auth/API spike"]
    F0 --> S2["S2: Menu bar/notch/lifecycle spike"]
    F0 --> S3["S3: Sandbox/signing feasibility"]
    F0 --> S4["S4: SwiftData and monitoring contracts"]
    S1 --> C0["C0: Freeze shared domain contracts"]
    S2 --> C0
    S3 --> C0
    S4 --> C0
    C0 --> G1["G1: Production GitHub stack"]
    C0 --> M1["M1: Persistence and monitoring core"]
    C0 --> U1["U1: UI against deterministic fixtures"]
    G1 --> I1["I1: Core vertical slice"]
    M1 --> I1
    U1 --> I1
    I1 --> G2["G2: GitHub recovery and live edge cases"]
    I1 --> M2["M2: Polling, transitions, notification router"]
    I1 --> U2["U2: Pins, menu bar, settings, notch production UI"]
    G2 --> I2["I2: Ambient monitoring integration"]
    M2 --> I2
    U2 --> I2
    I2 --> V["V: Gates 1–5 verification and hardening"]
    V --> R["R: Signing, notarization, clean-Mac and Homebrew release"]
~~~

## 8. Execution waves

### Wave 0 — Scope, baseline, and foundation

Owner: Integrator
Parallel agents: read-only until the dedicated repository baseline is established.

Tasks:

- P0.1: Verify the dedicated GitPings repository and documentation baseline.
- P0.2: Confirm product name, bundle ID, proposed defaults, and representative scale.
- F0.1: Create the macOS 26 Xcode app and unit/UI test targets.
- F0.2: Create shared scheme and deterministic build configuration.
- F0.3: Create script/build_and_run.sh with run, debug, logs, telemetry, and verify modes.
- F0.4: Wire .codex/environments/environment.toml Run action to the script.
- F0.5: Create folder ownership boundaries, domain protocols, mock services, fixtures, and verification artifact path.
- F0.6: Enable a minimal Debug sandbox/capability baseline for the spikes.

Required evidence:

- xcodebuild -list output.
- Successful clean Debug build.
- script/build_and_run.sh --verify output proving a real app bundle launches.
- Initial unit target runs.
- No unrelated parent-repository files staged or changed.

Stop condition: all three feature agents can compile against frozen protocols without editing shared project files.

### Wave 1 — Parallel feasibility spikes

Run three agents concurrently.

#### S1 — GitHub client-only feasibility

Owner: GitHub Platform Agent

Prove:

- Development GitHub App device flow with no callback server or shipped secret.
- Access/refresh token lifecycle and Keychain storage.
- Public and approved private organization repository discovery.
- Required read-only permissions.
- Configurable filter queries with GitHub search semantics.
- Status-check rollup, mergeable, and merge-state fields.
- Pagination, partial errors, and representative GraphQL cost.

Deliver redacted query/response fixtures and a permission manifest. Do not commit credentials or private payloads.

#### S2 — macOS lifecycle and notch feasibility

Owner: macOS Experience Agent

Prove:

- Quiet accessory launch and persistent MenuBarExtra.
- Singleton dashboard close/reopen behavior.
- Nonactivating NSPanel hosting SwiftUI.
- Public NSScreen safe-area/auxiliary geometry on a notched Mac.
- Notchless/external fallback and no focus theft.
- Full-screen, Spaces, lock/wake, scaling, and display reconfiguration feasibility.

Deliver recordings and frame/focus telemetry.

#### S3/S4 — Persistence, sandbox, and release feasibility

Owner: Monitoring Core Agent with Integrator review

Prove:

- SwiftData schema version 1 for selections, pins, PR cache, snapshots, settings, and bounded history.
- Deterministic normalization/diff fixtures and injected clock/network interfaces.
- Sandbox compatibility with GitHub HTTPS, Keychain, SMAppService, and the panel.
- Developer ID/Hardened Runtime configuration requirements without claiming an unsigned spike is release-ready.

#### Gate 0 — Feasibility and contract freeze

Gate 0 passes only when:

- A real app builds and launches.
- Device flow and token refresh work directly with GitHub.
- A private organization PR yields required fields under read-only permissions.
- Representative 60-second polling is projected to use at most 40% of the returned hourly GraphQL quota; otherwise query scope or interval must be revised.
- Notch and notchless panel paths are viable without focus theft.
- Sandbox does not block required capabilities.
- Domain contracts, persistence identities, severity rules, filter configuration, and service protocols are frozen.

### Wave 2 — Core vertical slice

Run three agents concurrently against frozen contracts.

#### G1 — Production GitHub stack

- Auth actor and device-flow state machine.
- Keychain access/refresh lifecycle.
- Installation and repository discovery.
- Search filter compiler and separate-query OR union.
- Paginated GraphQL client and targeted PR lookup.
- Rate-limit metadata and redacted logging.
- DTO-to-domain mapping with unknown/default cases.

#### M1 — Persistence and cache

- SwiftData schema/migration scaffolding.
- Repository selections and filter settings.
- PR cache and staleness policy.
- Pin add/remove/reorder/replacement with a hard limit of five.
- Baseline snapshots and sign-out purge.
- Bounded transition retention.

#### U1 — Dashboard against fixtures

- Onboarding states.
- Repository picker and configurable filters.
- Native sidebar, PR list, detail surface, and local search.
- CI/mergeable/blocked/conflicting/checking/unknown/stale presentation.
- Pin controls and replacement chooser.
- Open on GitHub.
- Keyboard and VoiceOver labels.

#### Gate 1 — Core vertical slice

Integrator composes:

~~~text
Sign in → authorize/install → select repositories → configure filters
→ load cached/live PRs → inspect CI/merge state → pin → open on GitHub
~~~

Gate requirements:

- Public/private fixtures and a live test repository work.
- Four filters use OR semantics and global-ID deduplication.
- Pagination and partial GraphQL errors preserve valid PRs.
- Unknown never maps to success.
- Cache renders immediately after relaunch/offline.
- Sign-out deletes Keychain tokens and private cached data.
- Every current CI/merge enum plus unknown/default is tested.

### Wave 3 — Ambient monitoring

Run three agents concurrently.

#### G2 — GitHub recovery

- Missing-open-PR targeted lookup.
- 401 refresh-and-single-retry.
- 403/429 Retry-After and reset behavior.
- SAML/installation permission recovery states.
- 5xx, timeout, malformed, and partial-response fixtures.
- Live cost trace for at least 15 minutes of one-minute polling.

#### M2 — Refresh and transition engine

- Single-flight refresh actor.
- Timer/manual/open/wake/network trigger coalescing.
- Injected clock; no wall-clock sleeps in tests.
- Backoff with jitter and server timing precedence.
- Initial/filter/repository baselines.
- Semantic diff, same-cycle coalescing, and deduplication.
- No false closed/merged event from search absence.
- Notification queue/router and channel/event toggles.
- Cancellation on Quit.

#### U2 — Ambient macOS experience

- Pinned menu-bar popover and severity icon.
- Refresh, dashboard, Settings, and Quit actions.
- Dedicated Settings scene.
- Launch at login and quiet login launch.
- Native system notification permission and test action.
- Production notch panel queue, hover pause, click, timeout, Reduce Motion, full-screen/lock suppression, and fallback.

#### Gate 2 — Ambient integration

Gate requirements:

- Initial and configuration baseline changes emit no history.
- Repeated snapshots emit nothing.
- Same-cycle CI and merge changes coalesce.
- Offline/auth/rate/server failures preserve cache and expose recovery.
- Five pins are enforced without silent eviction.
- Dashboard closure leaves monitoring alive; Quit stops it.
- Cached popover opens under 200 ms in three measured runs.
- Notification settings persist and test notifications do not enter transition history.

### Wave 4 — Verification and hardening

Implementation agents switch to fix-only mode. Independent verifiers close gates.

#### Gate 3 — Automated correctness and lifecycle

Evidence:

- Exact clean build and xcodebuild test commands with exit codes.
- xcresult bundles and machine-readable summaries.
- At least 90% line coverage for normalization, filter compiler, transition detector, refresh coordinator, and pin policy.
- Three consecutive clean runs for concurrency/time-sensitive tests.
- XCUITest screenshots for first run, pin-and-monitor, and authorization recovery.
- Unified logs showing dashboard close does not stop polling and Quit does.
- Zero actionable Swift concurrency diagnostics or compiler warnings.

#### Gate 4 — Real-device notch/display matrix

Test:

- Notched built-in display with visible/auto-hidden menu bar and every scaling mode.
- Mirrored and extended external display above, below, left, and right.
- Notchless fallback enabled/disabled.
- Full screen, Spaces, lock/unlock, sleep/wake, attach/detach.
- Reduce Motion, Increase Contrast, and VoiceOver.
- One event, rapid same-PR changes, three queued events, and overflow.
- Four-second dismissal, hover pause, click, and focus preservation.

Evidence includes recordings, panel-frame telemetry, focus telemetry, and an issue list.

#### Gate 5 — Security and privacy

Verify:

- Read-only GitHub App permission export.
- Keychain-only tokens and verified sign-out deletion.
- No token, header, device code, secret, private key, PAT, or private payload in source, fixtures, logs, defaults, SwiftData, built resources, or notifications.
- HTTPS/approved GitHub endpoint inventory and external URL validation.
- Minimal App Sandbox/release entitlements.
- No get-task-allow in Release.
- No analytics, backend, Vercel, or Convex dependency.
- Dependency inventory is reviewed and locked.

Run a secret-pattern scan and a canary-token log-redaction test.

### Wave 5 — Release

Owner: Integrator / Release owner
Feature agents: fix support only.

#### Gate 6 — Signed and notarized artifact

1. Clean Release build and full tests.
2. Archive with production identifier/version/build.
3. Export using Developer ID Application and Hardened Runtime.
4. Verify nested signatures and entitlements.
5. Package versioned ZIP or DMG.
6. Submit with notarytool and inspect the accepted log.
7. Staple and validate.
8. Run Gatekeeper assessment.
9. Compute SHA-256 and reverify the extracted artifact.

Required evidence:

- Archive/export logs and artifact paths.
- codesign strict verification and entitlement output.
- Accepted notarization submission/log.
- stapler validation.
- spctl accepted/notarized Developer ID result.
- Artifact checksum.

#### Gate 7 — Clean teammate Mac and Homebrew

On a clean macOS 26 machine:

- Download the immutable candidate artifact.
- Verify checksum.
- Install and launch without xattr or Gatekeeper bypass.
- Sign in, access a private test repo, select/filter, pin, close dashboard, observe polling/notification, enable login launch, relogin, sign out, and quit.
- Install the same artifact through a private/project Homebrew Cask.
- Run brew audit, style, install, upgrade when possible, and uninstall tests.

The direct download and Cask must resolve to the same checksum-identical notarized artifact.

## 9. Automated test matrix

| Layer | Required proof |
| --- | --- |
| Domain | Every known/unknown CI and merge value; severity; identity |
| Filters | All four options, combinations, OR union, repo restrictions, pagination, dedup |
| Pins | Add/remove/reorder/persist/limit/replacement/terminal state |
| Transitions | Baselines, repetition, coalescing, targeted close lookup, partial failure |
| Refresh | Single flight, trigger coalescing, backoff, jitter, Retry-After, wake/network, Quit |
| Auth | Pending/slow-down/success/expiry/denial/cancel/refresh/revocation |
| Persistence | Relaunch, migration, staleness, transaction, bounded history, sign-out purge |
| Notifications | Master/event/channel toggles, queue/overflow, hover/test behavior |
| Lifecycle UI | Quiet launch, singleton dashboard, close/reopen, Settings, Quit, login launch |
| Accessibility | Keyboard, VoiceOver labels, non-color status, Reduce Motion, contrast |
| Release | Entitlements, signature, notarization, Gatekeeper, checksum, clean install |

No deterministic test may depend on live GitHub, wall-clock sleeps, test order, or network availability.

## 10. Evidence storage

Store gate evidence under:

~~~text
artifacts/verification/<commit-or-version>/<gate>/
~~~

Evidence may include:

- Build/test logs and xcresult bundles.
- Redacted API fixtures and polling traces.
- Screenshots/recordings.
- Accessibility and performance reports.
- Entitlement/signing/notarization output.
- Clean-machine and Homebrew checklists.

Large/private evidence should be ignored by Git and referenced by absolute/local path in the handoff. Release payloads must never include verification artifacts or secrets.

## 11. Delegation packet template

The orchestrator sends each task in this form:

~~~text
Task ID:
Objective:
Requirement IDs:
ADR constraints:
In scope:
Explicitly out of scope:
Owned write paths:
Read-only dependencies:
Expected outputs:
Required automated tests:
Required manual evidence:
Stop condition:
Known external blockers:
Integration order:
~~~

## 12. Handoff and integration

Agents use the handoff template in AGENTS.md.

Integration protocol:

1. Agent runs its smallest relevant test scope.
2. Agent commits only owned files.
3. Agent sends a complete handoff; it does not merge another branch.
4. Integrator reviews contracts, scope, secrets, and unrelated changes.
5. Integrator integrates in dependency order.
6. Integrator runs the full current gate.
7. A separate verifier reruns high-risk evidence.
8. Contracts freeze again before the next wave.

On semantic conflict, return it to the feature owner. The integrator must not silently guess.

## 13. Escalation conditions

Stop and request a decision if work requires:

- A backend, callback service, Vercel, Convex, webhook receiver, or APNs service.
- GitHub write access, classic broad repo scope, an embedded secret, or private key.
- Private macOS APIs or hardware-model notch tables.
- A new third-party runtime dependency.
- Bundle ID, Keychain namespace, persistent schema, or frozen contract changes.
- Multiple accounts, Enterprise, older macOS, updater, reviews, or deployments.
- Committing credentials, device codes, private GraphQL data, or unrelated files.

External prerequisites owned by the user:

- GitHub App registration/client ID and organization installation approval.
- A representative private organization test repository.
- Apple Developer Program membership and Developer ID certificate.
- Notched and notchless/external-display hardware.
- A clean teammate Mac.
- A GitHub Release repository and Homebrew tap before Gate 7.

Agents should continue with fixtures and adjacent in-scope work when an external prerequisite is absent.

## 14. Scope and status audit

At the end of each wave, the integrator records:

1. Requirements planned.
2. Requirements completed and evidence.
3. Scope additions, with approval and trade-off.
4. Deferred suggestions.
5. Open blockers.
6. Contract/schema changes.
7. The next single integration priority.

The orchestrator must not mark the app finished while any gate is incomplete, any critical test is flaky, any primary hardware path is unverified, or any release/security exception is implicit.
