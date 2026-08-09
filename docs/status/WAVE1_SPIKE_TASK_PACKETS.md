# Wave 1 spike task packets

Prepared by integrator after Wave 0 path scaffolding. Feature agents may proceed with **fixture-backed / design spikes** under owned paths only. Live Mac/GitHub evidence remains blocked until external prerequisites land.

Do not edit `GitPings.xcodeproj`, `GitPings/App`, `GitPings/Domain`, entitlements, `script/`, or `.codex/`.

---

## Task ID: S1 — GitHub client-only feasibility

Objective: Prove device-flow + read-only GraphQL query shape without callback server or shipped secret.

Requirement IDs: AUTH-1..AUTH-8, REPO-1..REPO-6, FILTER-1..FILTER-5, PR-4/PR-9, REFRESH-4/REFRESH-5  
ADR constraints: ADR-002

In scope:
- Device-flow state machine sketch and Keychain store interface usage
- Permission manifest (read-only)
- GraphQL query drafts for installations, filtered PR search, status rollup, merge fields
- Redacted fixtures under `Fixtures/github/`
- Representative cost projection worksheet

Explicitly out of scope:
- Production auth UI polish
- Embedding client secret / private key / PAT
- Backend/callback service
- Editing frozen Domain protocols without change request

Owned write paths:
- `GitPings/Infrastructure/GitHub/**`
- `GitPings/Infrastructure/Keychain/**`
- `GitPings/Features/Authentication/**`
- `Fixtures/github/**`
- `GitPingsTests/GitHub*.swift`

Read-only dependencies:
- `GitPings/Domain/**`
- `docs/REQUIREMENTS.md`, ADR-002

Expected outputs:
- Spike notes under owned paths or `GitPings/Infrastructure/GitHub/SPIKE.md`
- Redacted fixtures
- Permission manifest
- AGENTS.md handoff

Required automated tests:
- Fixture parsing / query builder unit tests if code lands
- Secret-pattern absence checks for fixtures

Required manual evidence:
- Live device-flow + private org PR field capture when client ID + Mac available; otherwise mark blocked

Stop condition:
- Query/permission feasibility documented; no secrets committed; unknowns escalate to integrator

Known external blockers:
- GitHub App client ID, org install approval, private test repo, macOS host

Integration order: before C0 contract freeze

---

## Task ID: S2 — macOS lifecycle and notch feasibility

Objective: Prove MenuBarExtra + nonactivating notch/fallback panel using public APIs.

Requirement IDs: MENUBAR-1..8, LIFECYCLE-1..5, NOTCH-1..12, NOTIFY-6..9  
ADR constraints: ADR-001, ADR-004

In scope:
- Accessory/menu-bar lifecycle notes and prototype panel coordinator
- NSScreen safe-area/auxiliary geometry helper
- Focus/frame telemetry hooks
- UI test scaffolding

Explicitly out of scope:
- Production notification router
- Private notch APIs / model tables
- Editing project.pbxproj

Owned write paths:
- `GitPings/Features/MenuBar/**`
- `GitPings/Features/Notch/**`
- `GitPings/Platform/NotchPanel/**`
- `GitPings/Platform/SystemNotifications/**`
- `GitPings/Platform/LaunchAtLogin/**`
- `GitPingsUITests/**`

Read-only dependencies:
- Domain contracts, App composition root (read-only)

Expected outputs:
- Spike notes + prototype code under owned paths
- Display-following policy recommendation from evidence (or blocked)

Required automated tests:
- Geometry helper unit tests with injected screen metrics when possible

Required manual evidence:
- Notched + notchless recordings on real hardware (blocked on Linux CI)

Stop condition:
- Public-API approach documented; focus-theft risks listed; escalate if private API appears necessary

Known external blockers:
- macOS Tahoe host, notched MacBook, external display

Integration order: before C0

---

## Task ID: S3/S4 — Persistence, sandbox, monitoring contracts

Objective: Prove SwiftData schema v1 + deterministic transition fixtures + sandbox entitlement compatibility notes.

Requirement IDs: PIN-1..6, REFRESH-1..9, CHANGE-1..7, SETTINGS-1..6, local data §9  
ADR constraints: ADR-001, ADR-003, ADR-005

In scope:
- SwiftData models/schema version 1 draft
- Pin limit/replacement store sketch
- Transition detector pure functions + fixtures
- Sandbox/Keychain/network/SMAppService feasibility notes

Explicitly out of scope:
- Claiming unsigned spike is release-ready
- Editing entitlements/project (integrator-owned)
- Live notarization

Owned write paths:
- `GitPings/Infrastructure/Persistence/**`
- `GitPings/Services/Refresh/**`
- `GitPings/Services/Transitions/**`
- `GitPings/Services/Notifications/**`
- `GitPings/Features/PullRequests/Stores/**`
- `Fixtures/transitions/**`
- `Fixtures/pins/**`
- `GitPingsTests/Monitoring*.swift` / `Persistence*.swift`

Read-only dependencies:
- Domain protocols, entitlements file (read-only), ADR-003/005

Expected outputs:
- Schema draft, detector fixtures, feasibility note, handoff

Required automated tests:
- Pin limit, baseline-no-events, unknown≠success fixtures

Required manual evidence:
- Sandbox runtime confirmation on Mac (blocked here)

Stop condition:
- Schema + detector contracts ready for Gate 0 freeze review

Known external blockers:
- macOS host for sandbox runtime proof; Developer ID for later gates only

Integration order: before C0
