#!/usr/bin/env bash
# Linux-safe static checks for redacted fixtures (no Xcode required).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail=0
echo "==> Scanning Fixtures for live secret-like values"
# Allow documented field names and [REDACTED] placeholders; reject live-looking material.
matches="$(rg -n -i \
  -e 'Bearer [A-Za-z0-9._\-]{8,}' \
  -e 'ghp_[A-Za-z0-9]{20,}' \
  -e 'gho_[A-Za-z0-9]{20,}' \
  -e 'ghu_[A-Za-z0-9]{20,}' \
  -e 'ghs_[A-Za-z0-9]{20,}' \
  -e 'BEGIN (RSA |OPENSSH )?PRIVATE KEY' \
  Fixtures || true)"
# Flag non-redacted token-like JSON values.
json_matches="$(rg -n -i \
  '(access_token|refresh_token|device_code|user_code|client_secret)"?\s*:\s*"[^"]+"' \
  Fixtures || true)"
json_matches="$(printf '%s\n' "$json_matches" | rg -v '\[REDACTED\]' || true)"

if [[ -n "${matches// }" || -n "${json_matches// }" ]]; then
  echo "$matches"
  echo "$json_matches"
  echo "FAIL: possible live secret material in Fixtures" >&2
  fail=1
else
  echo "OK: no live secret material detected in Fixtures"
fi

echo "==> Checking required fixture files exist"
for f in \
  Fixtures/github/sample_tracked_prs.json \
  Fixtures/transitions/baseline_no_events.json \
  Fixtures/pins/pin_limit.json \
  Fixtures/github/device_flow_responses.json
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
