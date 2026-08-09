# Wave 0 baseline decisions

Status: Confirmed by integrator for Gate 0 scaffolding
Date: 2026-08-09
Branch: codex/wave-0-foundation

These values match docs/EXECUTION_PLAN.md §3 unless a later Gate 0 evidence spike forces a revision.

| Decision | Confirmed value |
| --- | --- |
| Product name | GitPings |
| Bundle identifier | com.razeenali.gitpings |
| Platform | macOS Tahoe 26+ |
| Account model | One GitHub.com account per local app installation |
| Runtime boundary | Mac app directly to GitHub; local Keychain/SwiftData only |
| Polling target | 60 seconds while running, subject to backoff |
| Pin limit | Five, with explicit replacement |
| Closed/merged pin behavior | Remains pinned with terminal state until user unpins |
| Test notification defaults | All tracked event types enabled |
| Teammate-release defaults | Notch enabled; Notification Center and sound opt-in |
| Transition retention | Latest 100 events or seven days, whichever removes data first |
| Representative scale target | 25 selected repositories, 200 matching open PRs, five pins |
| Display-following policy | Deferred until real-device notch spike evidence |

## Repository root note

On this Cloud Agent host, `git rev-parse --show-toplevel` resolves to `/workspace`, which is the dedicated `gitpingsmac` repository (`github.com/r4z33n4l1/gitpingsmac`). No parent Solo repository or `hardware-outreach` path is present or touched. The local Mac path documented in AGENTS.md (`/Users/razeenali/Documents/Solo/gitpingsmac`) is the equivalent dedicated root on the owner’s machine.

## External blockers recorded at Wave 0 start

- Host is Linux; Xcode/`xcodebuild` unavailable, so Gate 0 build/launch evidence cannot be produced here.
- GitHub App client ID / organization installation not available in this environment.
- Apple Developer ID / notarization credentials not available.
- Notched / notchless hardware matrix not available.
