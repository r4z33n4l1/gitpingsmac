# GitPings distribution and teammate setup

GitPings is a client-only macOS app. It talks directly to GitHub, stores tokens
in Keychain, and does not require a hosted callback, Vercel project, Convex
database, client secret, or GitHub App private key.

## What can be shared

The teammate release is:

- a universal `arm64` + `x86_64` Release build;
- signed with **Developer ID Application**;
- protected by Hardened Runtime and App Sandbox;
- notarized by Apple with a stapled ticket;
- packaged as `GitPings-<version>.zip` with a SHA-256 checksum; and
- installable directly or through the generated Homebrew Cask.

Do not publish `*-local-unnotarized.zip`. That artifact exists only to validate
the packaging pipeline before Developer ID credentials are available.

## Recipient setup

### 1. Install GitPings

1. Download `GitPings-<version>.zip` and its `.sha256` file from the matching
   GitHub Release.
2. Verify the checksum with `shasum -a 256 -c GitPings-<version>.zip.sha256`.
3. Unzip it and move `GitPings.app` to Applications.
4. Open GitPings. Its status icon appears in the menu bar.

GitPings currently targets macOS Tahoe 26 or newer.

### 2. Create a personal GitHub App

Until the project publishes one shared public GitHub App, each recipient creates
their own registration:

1. In GitHub, open **Settings → Developer settings → GitHub Apps → New GitHub App**.
2. Give it a unique name and use the GitPings repository URL as the homepage.
3. Disable webhooks; GitPings polls GitHub directly.
4. Enable **Device Flow** under “Identifying and authorizing users.” No callback
   URL is required by GitPings.
5. Keep expiring user access tokens enabled.
6. Set these repository permissions to **Read-only**:
   - Metadata
   - Pull requests
   - Checks
   - Commit statuses
   - Contents
7. Do not grant account or organization permissions, write permissions, or
   subscribe to webhook events.
8. Create the app, copy its **Client ID** (not App ID), then install the app on
   your personal account or organization. Prefer “Only select repositories.”

GitHub may require an organization owner to approve the installation.

### 3. Connect GitPings

1. Open GitPings → Settings → Account.
2. Paste the GitHub App Client ID. A client ID is public configuration; never
   paste a client secret or private key into GitPings.
3. Choose **Sign in with GitHub**, open the displayed device-login link, and
   enter the one-time code.
4. Open the dashboard, choose **Add Repository**, and select the repositories to
   monitor.
5. Configure filters and notifications in Settings, then pin up to five PRs.

## Maintainer release setup

### One-time Apple setup

1. Join the Apple Developer Program and create a **Developer ID Application**
   certificate in the developer account/Xcode.
2. Confirm it appears in `security find-identity -p codesigning -v`.
3. Store notarization credentials in Keychain with `notarytool`, for example:

   ```bash
   xcrun notarytool store-credentials GitPingsNotary
   ```

   Follow the prompts. Never place the Apple password, app-specific password,
   private key, or `.p12` file in this repository.

### Build, sign, notarize, and package

```bash
GITPINGS_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
GITPINGS_NOTARY_PROFILE="GitPingsNotary" \
./script/package_release.sh --notarize
```

The script runs the unit suite, builds a universal Release app, applies the
minimum release entitlements, verifies Hardened Runtime, rejects
`get-task-allow`, notarizes, staples, runs Gatekeeper assessment, and writes:

```text
dist/GitPings-<version>.zip
dist/GitPings-<version>.zip.sha256
dist/GitPings-<version>-signing.txt
dist/GitPings-<version>-entitlements.plist
dist/GitPings-<version>-notarization.json
dist/gitpings.rb
```

Create an immutable GitHub Release tagged `v<version>` and attach the ZIP and
checksum. The generated Cask references that exact versioned URL and checksum.

Before sharing broadly, install the artifact on a clean teammate Mac and verify
GitHub sign-in, private-repository discovery, polling, notifications, launch at
login, sign-out, and quit.

## Local packaging smoke test

```bash
./script/package_release.sh --local
```

This exercises tests, the universal Release build, icon compilation, Hardened
Runtime signing, entitlement checks, ZIP creation, and checksum generation. It
does **not** make the artifact safe for normal teammate distribution.

## References

- [Registering a GitHub App](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app)
- [Choosing GitHub App permissions](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/choosing-permissions-for-a-github-app)
- [Installing your own GitHub App](https://docs.github.com/en/apps/using-github-apps/installing-your-own-github-app)
- [Apple Developer ID](https://developer.apple.com/support/developer-id/)
- [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
