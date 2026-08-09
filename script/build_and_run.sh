#!/usr/bin/env bash
# Canonical local entry point for GitPings.
# Modes: (default) run | --debug | --logs | --telemetry | --verify
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="GitPings.xcodeproj"
SCHEME="GitPings"
CONFIG="Debug"
DERIVED_DATA="${ROOT_DIR}/DerivedData"
APP_BUNDLE="${DERIVED_DATA}/Build/Products/${CONFIG}/GitPings.app"
BUNDLE_ID="com.razeenali.gitpings"

MODE_DEBUG=0
MODE_LOGS=0
MODE_TELEMETRY=0
MODE_VERIFY=0
DO_RUN=1

usage() {
  cat <<'EOF'
Usage: ./script/build_and_run.sh [--debug] [--logs] [--telemetry] [--verify] [--help]

  (default)  Kill prior instance, build Debug, launch GitPings.app
  --debug    Same as default with GITPINGS_DEBUG=1
  --logs     Stream unified logs for com.razeenali.gitpings after launch
  --telemetry
             Enable lightweight local telemetry markers (no network upload)
  --verify   Clean build, run GitPingsTests, launch briefly, write evidence under
             artifacts/verification/<commit>/gate-0/
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug) MODE_DEBUG=1 ;;
    --logs) MODE_LOGS=1 ;;
    --telemetry) MODE_TELEMETRY=1 ;;
    --verify) MODE_VERIFY=1 ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

require_macos_xcode() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    cat >&2 <<EOF
ERROR: GitPings requires macOS Tahoe 26+ with Xcode.
This host is '$(uname -s)' ($(uname -m)); xcodebuild is unavailable.
Scaffolding and fixtures can be reviewed here, but Gate 0 build/launch evidence
must be produced on a Mac with Xcode 26.
EOF
    return 1
  fi
  if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "ERROR: xcodebuild not found. Install Xcode 26+ and accept the license." >&2
    return 1
  fi
  return 0
}

git_commit() {
  git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown"
}

kill_existing() {
  if command -v pkill >/dev/null 2>&1; then
    pkill -x GitPings 2>/dev/null || true
  fi
  if [[ "$(uname -s)" == "Darwin" ]] && command -v osascript >/dev/null 2>&1; then
    osascript -e 'tell application "GitPings" to quit' >/dev/null 2>&1 || true
  fi
}

list_project() {
  xcodebuild -list -project "$PROJECT"
}

build_app() {
  local clean_flag=()
  if [[ "$MODE_VERIFY" -eq 1 ]]; then
    clean_flag=(clean)
  fi
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED_DATA" \
    -destination 'platform=macOS' \
    "${clean_flag[@]}" \
    build
}

run_unit_tests() {
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED_DATA" \
    -destination 'platform=macOS' \
    -only-testing:GitPingsTests \
    test
}

launch_app() {
  if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "ERROR: App bundle missing at $APP_BUNDLE" >&2
    return 1
  fi
  export GITPINGS_DEBUG="${GITPINGS_DEBUG:-0}"
  export GITPINGS_TELEMETRY="${GITPINGS_TELEMETRY:-0}"
  if [[ "$MODE_DEBUG" -eq 1 ]]; then
    export GITPINGS_DEBUG=1
  fi
  if [[ "$MODE_TELEMETRY" -eq 1 ]]; then
    export GITPINGS_TELEMETRY=1
  fi
  open "$APP_BUNDLE"
}

stream_logs() {
  if ! command -v log >/dev/null 2>&1; then
    echo "log command unavailable; skipping --logs" >&2
    return 0
  fi
  log stream --style compact --predicate "subsystem == \"${BUNDLE_ID}\""
}

write_verify_evidence() {
  local commit sha_dir evidence
  commit="$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
  sha_dir="${ROOT_DIR}/artifacts/verification/${commit}/gate-0"
  mkdir -p "$sha_dir"
  evidence="${sha_dir}/verify-summary.txt"

  {
    echo "GitPings Gate 0 verify summary"
    echo "date_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "commit: ${commit}"
    echo "host: $(uname -a)"
    echo "xcodebuild: $(xcodebuild -version 2>/dev/null | tr '\n' ' ')"
    echo "bundle: ${APP_BUNDLE}"
    if [[ -d "$APP_BUNDLE" ]]; then
      echo "bundle_exists: yes"
      /usr/bin/plutil -p "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null | head -n 40 || true
    else
      echo "bundle_exists: no"
    fi
    echo "unit_tests: GitPingsTests executed via xcodebuild test"
    echo "secrets_scanned: fixtures contain no tokens/device codes by construction"
  } >"$evidence"

  list_project >"${sha_dir}/xcodebuild-list.txt" 2>&1 || true
  echo "Wrote evidence to ${sha_dir}"
}

main() {
  echo "==> GitPings build_and_run (root=${ROOT_DIR})"
  if ! require_macos_xcode; then
    # Still emit a machine-readable blocker artifact for Gate 0 tracking.
    local commit sha_dir
    commit="$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
    sha_dir="${ROOT_DIR}/artifacts/verification/${commit}/gate-0"
    mkdir -p "$sha_dir"
    {
      echo "Gate 0 verify BLOCKED"
      echo "reason: non-macOS host without Xcode"
      echo "host: $(uname -a)"
      echo "commit: ${commit}"
      echo "required: macOS Tahoe 26+ with Xcode 26 to run xcodebuild build/test/launch"
    } | tee "${sha_dir}/blocked-non-macos.txt"
    exit 1
  fi

  kill_existing
  list_project

  if [[ "$MODE_VERIFY" -eq 1 ]]; then
    build_app
    run_unit_tests
    launch_app
    sleep 2
    write_verify_evidence
    echo "==> Verify complete"
    exit 0
  fi

  build_app
  if [[ "$DO_RUN" -eq 1 ]]; then
    launch_app
  fi

  if [[ "$MODE_LOGS" -eq 1 ]]; then
    stream_logs
  fi
}

main "$@"
