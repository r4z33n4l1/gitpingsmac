# Gate 0 status

Branch: `codex/wave-0-foundation`  
Foundation commit: `5079c4804c613a46d296825d43293613bfd1f537`  
PR: https://github.com/r4z33n4l1/gitpingsmac/pull/1

## Checklist

| Condition | Status |
| --- | --- |
| Real app builds and launches | BLOCKED — Linux host, no Xcode |
| Device flow + token refresh with GitHub | BLOCKED — needs client ID + Mac |
| Private org PR yields required fields (read-only) | BLOCKED — needs App install + private test repo |
| 60s polling ≤ 40% hourly GraphQL quota projection | PENDING — S1 cost worksheet |
| Notch + notchless panel without focus theft | BLOCKED — needs notched/notchless hardware |
| Sandbox does not block required capabilities | PENDING design / BLOCKED runtime |
| Domain contracts frozen | DRAFT scaffold present; freeze after spike review |

## Evidence

Local (gitignored):

```text
artifacts/verification/5079c4804c613a46d296825d43293613bfd1f537/gate-0/blocked-non-macos.txt
```

Command:

```bash
./script/build_and_run.sh --verify
# exit 1 on Linux; must exit 0 on macOS Tahoe 26 + Xcode 26
```

## Next dependency-unblocking task

1. Run `./script/build_and_run.sh --verify` on a Mac and attach Gate 0 evidence.
2. Provide `GITPINGS_GITHUB_APP_CLIENT_ID` (public client ID only) and install the App on a private org test repo.
3. Integrator reviews S1/S2/S3–S4 spike handoffs, freezes Domain contracts (C0), then opens Wave 2 vertical-slice packets.
