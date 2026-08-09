# Gate 0 status

Branch: `codex/wave-0-foundation`  
HEAD: see `git rev-parse HEAD`  
PR: https://github.com/r4z33n4l1/gitpingsmac/pull/1

## Checklist

| Condition | Status |
| --- | --- |
| Real app builds and launches | BLOCKED — Linux host, no Xcode |
| Device flow + token refresh with GitHub | BLOCKED — needs client ID + Mac; S1 fixture spike landed |
| Private org PR yields required fields (read-only) | BLOCKED — needs App install + private test repo |
| 60s polling ≤ 40% hourly GraphQL quota projection | PARTIAL — see `GitPings/Infrastructure/GitHub/COST_PROJECTION.md` |
| Notch + notchless panel without focus theft | BLOCKED — S2 public-API spike landed; needs hardware |
| Sandbox does not block required capabilities | PARTIAL design / BLOCKED runtime |
| Domain contracts frozen | DRAFT scaffold + spike review pending C0 freeze |

## Wave 1 spikes integrated (fixture-backed)

- S1 GitHub: device-flow client, filter compiler, GraphQL queries, Keychain stub, redacted fixtures, tests
- S2 macOS: notch panel coordinator, screen geometry, menu/settings affordances, UI journey placeholders
- S3/S4 monitoring: SwiftData schema sketches, pin/cache stores, refresh coordinator, transition detector, notification router, fixtures/tests

## Evidence

Local (gitignored):

```text
artifacts/verification/<commit>/gate-0/blocked-non-macos.txt
```

Commands:

```bash
./script/build_and_run.sh --verify   # exit 1 on Linux; required exit 0 on macOS 26 + Xcode 26
./script/check_fixtures_linux.sh     # Linux-safe redaction/fixture presence check
```

## Next dependency-unblocking task

1. On macOS Tahoe 26 + Xcode 26: `git checkout codex/wave-0-foundation && ./script/build_and_run.sh --verify`
2. Provide public GitHub App client ID only (`GITPINGS_GITHUB_APP_CLIENT_ID`); install App on private org test repo
3. Integrator freezes Domain contracts (C0) after Mac compile + spike review, then opens Wave 2 packets
