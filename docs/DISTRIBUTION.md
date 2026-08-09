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

### Homebrew installation

Once the tap is published:

```bash
brew install --cask r4z33n4l1/gitnorary/gitpings
gitnotary setup
```

`gitnotary setup` uses `gh auth status` and `gh api user` to identify the active
GitHub CLI account. It does not read, print, copy, store, or import the GitHub CLI
token. GitPings performs a separate, read-only GitHub App Device Flow and stores
its resulting token in macOS Keychain.

Useful diagnostics:

```bash
gitnotary doctor
gitnotary open
gitnotary version
```

### Manual installation

1. Download `GitPings-<version>.zip` and its `.sha256` file from the matching
   GitHub Release.
2. Verify the checksum with `shasum -a 256 -c GitPings-<version>.zip.sha256`.
3. Unzip it and move `GitPings.app` to Applications.
4. Open GitPings. Its status icon appears in the menu bar.
5. Run the bundled helper directly once, or add it to your PATH:

   ```bash
   /Applications/GitPings.app/Contents/Resources/gitnotary setup
   ```

GitPings currently targets macOS Tahoe 26 or newer.

### Authorize GitHub

GitPings uses the public [GitNotary GitHub App](https://github.com/apps/gitnotary).
No callback server, client secret, private key, Vercel project, or Convex database
is involved.

1. Install GitNotary for your account or organization and choose only the
   repositories you want GitPings to see.
2. Run `gitnotary setup` (or choose **Sign in with GitHub** in Settings).
3. Approve the one-time code on GitHub's device-login page.
4. Open the dashboard, choose **Add Repository**, and select repositories to
   monitor.
5. Configure filters and notifications, then pin up to five pull requests.

GitHub may require an organization owner to approve the installation.

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
