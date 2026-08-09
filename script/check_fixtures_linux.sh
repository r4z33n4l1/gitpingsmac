#!/usr/bin/env bash
# Linux-safe static checks for redacted fixtures (no Xcode required).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail=0
echo "==> Scanning Fixtures for forbidden secret patterns"
if rg -n -i 'authorization|access_token|refresh_token|device_code|client_secret|BEGIN (RSA |OPENSSH )?PRIVATE KEY' Fixtures; then
  echo "FAIL: forbidden pattern found in Fixtures" >&2
  fail=1
else
  echo "OK: no forbidden patterns in Fixtures"
fi

echo "==> Checking required fixture files exist"
for f in \
  Fixtures/github/sample_tracked_prs.json \
  Fixtures/transitions/baseline_no_events.json \
  Fixtures/pins/pin_limit.json
do
  if [[ -f "$f" ]]; then
    echo "OK: $f"
  else
    echo "FAIL: missing $f" >&2
    fail=1
  fi
done

echo "==> Checking domain pin limit constant"
if rg -n 'maximumPinCount = 5' GitPings/Domain/ServiceProtocols.swift >/dev/null; then
  echo "OK: PinPolicy.maximumPinCount = 5"
else
  echo "FAIL: pin limit constant missing" >&2
  fail=1
fi

exit "$fail"
