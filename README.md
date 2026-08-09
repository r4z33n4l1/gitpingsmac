# GitPings for macOS

GitPings is a native Swift 6 menu-bar utility for monitoring pull requests across selected GitHub repositories. It keeps a small set of pinned PRs close at hand and uses a notch-attached notification to surface meaningful CI and mergeability changes.

Working product name: **GitPings**  
Bundle identifier: **com.razeenali.gitpings**  
Target: **macOS Tahoe 26 and newer**

## Status

The native MVP builds and runs on macOS Tahoe. Version 0.1.0 is Developer ID
signed and notarized; version 0.1.1 adds the shared GitNotary GitHub App and CLI
onboarding flow.

## Install and connect

After installing GitPings, run:

```bash
gitnotary setup
```

The command verifies the account currently selected in GitHub CLI, then opens
GitPings' own read-only GitHub Device Flow. It never prints, copies, or imports
your `gh` token. Approve the one-time code in the browser, install GitNotary for
the repositories you want to monitor, and select those repositories in the app.

Until the Homebrew tap is published, download the signed release directly from
[GitHub Releases](https://github.com/r4z33n4l1/gitpingsmac/releases).

## Canonical run entrypoint

```bash
./script/build_and_run.sh
./script/build_and_run.sh --debug
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --verify
```

Codex Run actions are wired in [`.codex/environments/environment.toml`](.codex/environments/environment.toml).

## Package and share

```bash
./script/package_release.sh --local

GITPINGS_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
GITPINGS_NOTARY_PROFILE="GitPingsNotary" \
./script/package_release.sh --notarize
```

See the [distribution and teammate setup guide](docs/DISTRIBUTION.md) for CLI
onboarding, manual installation, signing, notarization, release, and Homebrew
instructions.

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
