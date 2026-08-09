#!/usr/bin/env bash
# Build a universal GitPings Release artifact.
#
# Local mode creates an explicitly unnotarized QA ZIP.
# Notarized mode requires a Developer ID Application identity and a notarytool
# Keychain profile, then produces the artifact intended for teammates/Homebrew.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="GitPings.xcodeproj"
SCHEME="GitPings"
CONFIGURATION="Release"
DERIVED_DATA="${GITPINGS_RELEASE_DERIVED_DATA:-${TMPDIR%/}/GitPingsReleaseDerivedData}"
BUILT_APP="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/GitPings.app"
DIST_DIR="${ROOT_DIR}/dist"
ENTITLEMENTS="${ROOT_DIR}/GitPings/GitPings.entitlements"
SIGNING_IDENTITY="${GITPINGS_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${GITPINGS_NOTARY_PROFILE:-}"
MODE=""

usage() {
  cat <<'EOF'
Usage:
  ./script/package_release.sh --local
  ./script/package_release.sh --notarize [--identity NAME] [--notary-profile NAME]

Modes:
  --local       Build/test a universal, ad-hoc-signed QA ZIP. This artifact is
                not suitable for normal teammate distribution through Gatekeeper.
  --notarize    Sign with Developer ID, notarize, staple, validate with Gatekeeper,
                and create the release ZIP, SHA-256 checksum, and Homebrew Cask.

Options:
  --identity NAME
                Developer ID Application identity. May also be supplied through
                GITPINGS_SIGNING_IDENTITY.
  --notary-profile NAME
                notarytool Keychain profile. May also be supplied through
                GITPINGS_NOTARY_PROFILE.
  --help        Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local)
      MODE="local"
      ;;
    --notarize)
      MODE="notarize"
      ;;
    --identity)
      shift
      [[ $# -gt 0 ]] || { echo "ERROR: --identity requires a value" >&2; exit 2; }
      SIGNING_IDENTITY="$1"
      ;;
    --notary-profile)
      shift
      [[ $# -gt 0 ]] || { echo "ERROR: --notary-profile requires a value" >&2; exit 2; }
      NOTARY_PROFILE="$1"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option '$1'" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ -z "$MODE" ]]; then
  echo "ERROR: choose --local or --notarize explicitly" >&2
  usage >&2
  exit 2
fi

if [[ "$(uname -s)" != "Darwin" ]] || ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: packaging requires macOS with Xcode installed" >&2
  exit 1
fi

if [[ "$MODE" == "notarize" ]]; then
  if [[ -z "$SIGNING_IDENTITY" || -z "$NOTARY_PROFILE" ]]; then
    echo "ERROR: --notarize requires a Developer ID identity and notary profile" >&2
    exit 1
  fi
  if ! security find-identity -p codesigning -v | grep -Fq "\"${SIGNING_IDENTITY}\""; then
    echo "ERROR: signing identity is not present in the login Keychain: ${SIGNING_IDENTITY}" >&2
    exit 1
  fi
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: tracked files must be clean before creating a notarized release" >&2
    exit 1
  fi
fi

BUILD_SETTINGS="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings 2>/dev/null)"
VERSION="$(awk '$1 == "MARKETING_VERSION" { print $3; exit }' <<<"$BUILD_SETTINGS")"
BUILD_NUMBER="$(awk '$1 == "CURRENT_PROJECT_VERSION" { print $3; exit }' <<<"$BUILD_SETTINGS")"
BUNDLE_ID="$(awk '$1 == "PRODUCT_BUNDLE_IDENTIFIER" { print $3; exit }' <<<"$BUILD_SETTINGS")"

if [[ -z "$VERSION" || -z "$BUILD_NUMBER" || -z "$BUNDLE_ID" ]]; then
  echo "ERROR: could not resolve version/build/bundle identifier from Xcode" >&2
  exit 1
fi

STAGING_ROOT="$(mktemp -d "${TMPDIR%/}/gitpings-release.XXXXXX")"
case "$STAGING_ROOT" in
  "${TMPDIR%/}"/gitpings-release.*) ;;
  *) echo "ERROR: unsafe temporary path: ${STAGING_ROOT}" >&2; exit 1 ;;
esac
cleanup() {
  /bin/rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

STAGED_APP="${STAGING_ROOT}/GitPings.app"
mkdir -p "$DIST_DIR"

echo "==> Testing GitPings ${VERSION} (${BUILD_NUMBER})"
xcodebuild \
  -quiet \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  -destination 'platform=macOS' \
  -only-testing:GitPingsTests \
  test

echo "==> Building universal Release app"
xcodebuild \
  -quiet \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -destination 'generic/platform=macOS' \
  clean build \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM=

if [[ ! -d "$BUILT_APP" ]]; then
  echo "ERROR: Release app was not produced at ${BUILT_APP}" >&2
  exit 1
fi
ditto "$BUILT_APP" "$STAGED_APP"

sign_mach_o_files() {
  local identity="$1"

  while IFS= read -r -d '' candidate; do
    if file "$candidate" | grep -Fq 'Mach-O'; then
      if [[ "$identity" == "-" ]]; then
        codesign --force --options runtime --sign - "$candidate"
      else
        codesign --force --options runtime --timestamp --sign "$identity" "$candidate"
      fi
    fi
  done < <(find "$STAGED_APP/Contents" -type f -print0)

  if [[ "$identity" == "-" ]]; then
    codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign - "$STAGED_APP"
  else
    codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$identity" "$STAGED_APP"
  fi
}

if [[ "$MODE" == "notarize" ]]; then
  echo "==> Signing with ${SIGNING_IDENTITY}"
  sign_mach_o_files "$SIGNING_IDENTITY"
else
  echo "==> Applying an ad-hoc Hardened Runtime signature for local QA"
  sign_mach_o_files -
fi

codesign --verify --deep --strict --verbose=2 "$STAGED_APP"

MAIN_EXECUTABLE="${STAGED_APP}/Contents/MacOS/GitPings"
EXECUTABLE_ARCHS="$(lipo -archs "$MAIN_EXECUTABLE")"
if [[ " ${EXECUTABLE_ARCHS} " != *" arm64 "* || " ${EXECUTABLE_ARCHS} " != *" x86_64 "* ]]; then
  echo "ERROR: expected arm64 and x86_64, found: ${EXECUTABLE_ARCHS}" >&2
  exit 1
fi

SIGNING_REPORT="${DIST_DIR}/GitPings-${VERSION}-signing.txt"
ENTITLEMENTS_REPORT="${DIST_DIR}/GitPings-${VERSION}-entitlements.plist"
codesign -dvvv "$STAGED_APP" >"$SIGNING_REPORT" 2>&1
codesign -d --entitlements :- "$STAGED_APP" >"$ENTITLEMENTS_REPORT" 2>/dev/null

if ! grep -Fq 'runtime' "$SIGNING_REPORT"; then
  echo "ERROR: Hardened Runtime flag is missing" >&2
  exit 1
fi
if /usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$ENTITLEMENTS_REPORT" 2>/dev/null | grep -Fq true; then
  echo "ERROR: release contains com.apple.security.get-task-allow" >&2
  exit 1
fi

if [[ "$MODE" == "notarize" ]]; then
  SUBMISSION_ZIP="${STAGING_ROOT}/GitPings-${VERSION}-submission.zip"
  ditto -c -k --sequesterRsrc --keepParent "$STAGED_APP" "$SUBMISSION_ZIP"

  echo "==> Submitting to Apple notarization"
  xcrun notarytool submit \
    "$SUBMISSION_ZIP" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait \
    --output-format json | tee "${DIST_DIR}/GitPings-${VERSION}-notarization.json"

  echo "==> Stapling and validating notarization ticket"
  xcrun stapler staple "$STAGED_APP"
  xcrun stapler validate "$STAGED_APP"
  spctl -a -vvv -t execute "$STAGED_APP"
  ARTIFACT_NAME="GitPings-${VERSION}.zip"
else
  ARTIFACT_NAME="GitPings-${VERSION}-local-unnotarized.zip"
fi

ARTIFACT_PATH="${DIST_DIR}/${ARTIFACT_NAME}"
ditto -c -k --sequesterRsrc --keepParent "$STAGED_APP" "$ARTIFACT_PATH"

(
  cd "$DIST_DIR"
  shasum -a 256 "$ARTIFACT_NAME" >"${ARTIFACT_NAME}.sha256"
)

if [[ "$MODE" == "notarize" ]]; then
  SHA256="$(shasum -a 256 "$ARTIFACT_PATH" | awk '{ print $1 }')"
  sed \
    -e "s/__VERSION__/${VERSION}/g" \
    -e "s/__SHA256__/${SHA256}/g" \
    packaging/Casks/gitpings.rb.template >"${DIST_DIR}/gitpings.rb"
fi

echo "==> Package complete"
echo "artifact: ${ARTIFACT_PATH}"
echo "checksum: ${ARTIFACT_PATH}.sha256"
echo "architectures: ${EXECUTABLE_ARCHS}"
if [[ "$MODE" == "local" ]]; then
  echo "WARNING: local artifact is not Developer ID signed or notarized; do not publish it as a teammate release."
fi
