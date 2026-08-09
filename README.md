# GitPings for macOS

GitPings is a native Swift 6 menu-bar utility for monitoring pull requests across selected GitHub repositories. It keeps a small set of pinned PRs close at hand and uses a notch-attached notification to surface meaningful CI and mergeability changes.

Working product name: **GitPings**  
Bundle identifier: **com.razeenali.gitpings**  
Target: **macOS Tahoe 26 and newer**

## Status

Wave 0 foundation scaffolding is in progress on `codex/wave-0-foundation`. Gate 0 is not closed until a real macOS/Xcode host builds, tests, and launches the app bundle.

## Canonical run entrypoint

```bash
./script/build_and_run.sh
./script/build_and_run.sh --debug
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --verify
```

Codex Run actions are wired in [`.codex/environments/environment.toml`](.codex/environments/environment.toml).

## Planning documents

- [Product requirements](docs/REQUIREMENTS.md)
- [Multi-agent execution plan](docs/EXECUTION_PLAN.md)
- [Agent operating rules](AGENTS.md)
- [Fresh-agent bootstrap prompt](docs/AGENT_BOOTSTRAP_PROMPT.md)
- [Wave 0 baseline decisions](docs/status/WAVE0_BASELINE_DECISIONS.md)
- [Path ownership](docs/status/PATH_OWNERSHIP.md)
- [ADR 001 — Native app architecture](docs/architecture/ADR-001-native-app-architecture.md)
- [ADR 002 — GitHub authentication and data access](docs/architecture/ADR-002-github-auth-and-data.md)
- [ADR 003 — Polling and state-change notifications](docs/architecture/ADR-003-polling-and-notifications.md)
- [ADR 004 — Menu-bar and notch presentation](docs/architecture/ADR-004-menu-bar-and-notch-ui.md)
- [ADR 005 — Packaging and teammate distribution](docs/architecture/ADR-005-packaging-and-distribution.md)

## Architecture boundaries

- Direct Mac-to-GitHub communication only (no Vercel, Convex, callback server, webhooks, or APNs backend).
- Keychain for tokens; SwiftData for non-secret local state.
- Read-only GitHub App permissions and OAuth device flow.
- Public macOS APIs only for menu-bar and notch/fallback notifications.
