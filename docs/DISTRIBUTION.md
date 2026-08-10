# GitPings distribution and teammate setup

GitPings is a client-only macOS app. It talks directly to GitHub through either
the locally installed GitHub CLI or a GitHub App device-flow session. It does
not require a hosted callback, Vercel project, Convex database, client secret,
or GitHub App private key.

## What can be shared

The teammate release is:

- a universal `arm64` + `x86_64` Release build;
- signed with **Developer ID Application**;
- protected by Hardened Runtime;
- notarized by Apple with a stapled ticket;
- packaged as checksum-protected ZIP and drag-and-drop DMG artifacts; and
- installable directly or through the generated Homebrew Cask.

Do not publish `*-local-unnotarized.zip`. That artifact exists only to validate
the packaging pipeline before Developer ID credentials are available.

## Recipient setup

### Homebrew installation

```bash
brew install --cask r4z33n4l1/gitnorary/gitpings
gitnotary setup
```

`gitnotary setup` uses the active GitHub CLI account and selects Local GitHub CLI
authentication. GitPings invokes read-only `gh api graphql` commands and never
asks `gh` to print or export its token. The token remains owned by GitHub CLI.

Useful diagnostics:

```bash
gitnotary doctor
gitnotary open
gitnotary version
```

### Manual installation

1. Download `GitPings-<version>.dmg` from the matching GitHub Release.
2. Optionally verify its checksum with
   `shasum -a 256 -c GitPings-<version>.dmg.sha256`.
3. Open the DMG and drag GitPings to Applications. The ZIP remains available
   for automated installation and checksum verification.
4. Open GitPings. Its status icon appears in the menu bar.
5. Run the bundled helper directly once, or add it to your PATH:

   ```bash
   /Applications/GitPings.app/Contents/Resources/gitnotary setup
   ```

GitPings currently targets macOS Tahoe 26 or newer.

### Connect GitHub

The recommended local setup is:

1. Run `gh auth login` if GitHub CLI is not already authenticated.
2. Run `gitnotary setup`, or choose **Local GitHub CLI** in Settings → Account.
3. Open the dashboard, choose **Add Repository**, and select repositories to
   monitor.
4. Configure filters and notifications, then pin up to five pull requests.

Alternatively, choose **GitNotary GitHub App** in Settings → Account. That mode
uses the public [GitNotary GitHub App](https://github.com/apps/gitnotary), its
fine-grained read-only permissions, and GitHub device flow. Install it only for
the repositories GitPings should see. Organization approval may be required.

Neither mode uses a GitPings-operated server.

### Why the app is not sandboxed

Apple's App Sandbox does not allow an app to run programs outside its bundle or
container. Local GitHub CLI mode must run the user's Homebrew-installed `gh`
executable, so the independently distributed app does not enable App Sandbox.
It remains Developer ID signed, notarized, protected by Hardened Runtime, and
limited by implementation to read-only GitHub queries. Users who do not accept
the broader local CLI credential can use the GitHub App method instead.

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
dist/GitPings-<version>.dmg
dist/GitPings-<version>.dmg.sha256
dist/GitPings-<version>-signing.txt
dist/GitPings-<version>-entitlements.plist
dist/GitPings-<version>-notarization.json
dist/GitPings-<version>-dmg-notarization.json
dist/gitpings.rb
```

Create an immutable GitHub Release tagged `v<version>` and attach the ZIP, DMG,
checksums, and notarization evidence. The generated Cask references the exact
versioned ZIP URL and checksum.

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
