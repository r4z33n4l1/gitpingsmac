# ADR 005: Packaging and teammate distribution

Status: Accepted for MVP
Date: 2026-08-09

## Context

The first audience is the owner and teammates, not the Mac App Store. Teammates should be able to install without bypassing Gatekeeper or running quarantine-removal commands. A future Homebrew Cask should install the same trusted artifact.

No release artifact exists yet, so this ADR defines required settings and validation rather than claiming the app is currently distribution-ready.

## Decision

### Development

- Use normal Xcode development signing for local builds.
- Do not require notarization for ordinary local debug runs.

### Teammate releases

Distribute outside the Mac App Store using:

- An Apple Developer Program team.
- Developer ID Application signing.
- Hardened Runtime.
- App Sandbox unless an implementation spike finds a concrete incompatibility.
- The minimum entitlements, expected to include outgoing network access for GitHub. Exact release entitlements are inspected rather than assumed.
- Apple notarization using current Xcode Organizer or notarytool.
- A stapled notarization ticket.
- A versioned ZIP or DMG containing GitPings.app.
- A GitHub Release with release notes and SHA-256 checksum.

The release must be installed and opened on a clean teammate Mac without manual Gatekeeper bypass.

### Homebrew

Start with a private or project-owned Homebrew tap after the first notarized release. Its Cask references the same versioned release URL and checksum and installs the app artifact into Applications.

After release stability and demand are demonstrated, consider submitting to the public homebrew/cask repository. Homebrew is an installation channel, not a substitute for Developer ID signing and notarization.

### Updates

Automatic in-app updates are out of scope for MVP. Teammates update by downloading a new release or running Homebrew upgrade. A later ADR may select an updater after signing identity, feed hosting, and rollback policy are established.

## Release pipeline

1. Build and test the Release configuration.
2. Archive the macOS app in Xcode.
3. Sign with Developer ID Application and Hardened Runtime.
4. Export a distributable app.
5. Package as ZIP or DMG.
6. Submit to Apple notarization using Xcode or notarytool.
7. Review the notary log.
8. Staple the ticket.
9. Validate signatures, entitlements, and Gatekeeper assessment.
10. Smoke-test on a clean supported Mac.
11. Publish the immutable versioned artifact and checksum to a GitHub Release.
12. Update and test the Homebrew Cask.

Expected validation includes:

- codesign inspection of signature and entitlements
- spctl Gatekeeper assessment
- stapler validation
- archive checksum verification
- Homebrew audit/style/install test for the Cask

Release credentials and notarization secrets belong in the developer Keychain or CI secret store, never in the repository.

## Bundle and version policy

- Stable bundle identifier chosen before Keychain item naming and GitHub App production registration are finalized.
- Semantic application version plus monotonically increasing build number.
- Versioned artifacts are immutable.
- Signing identity remains consistent so upgrades are trusted as the same app.
- Release notes call out permission, authentication, and storage changes.

## Alternatives considered

### Unsigned ZIP shared directly

Rejected for teammates. It creates alarming Gatekeeper behavior and trains users to bypass macOS security.

### Mac App Store first

Deferred. It introduces App Review and store-specific constraints without solving a current requirement. The architecture should avoid gratuitously blocking a later store build.

### Homebrew-only unsigned distribution

Rejected. Homebrew moves the bundle into Applications but does not replace Apple signing, notarization, or Gatekeeper trust.

### PKG installer

Not selected for MVP. GitPings is a self-contained app bundle with no privileged helper or system-wide payload; ZIP/DMG plus a Cask is simpler.

### Bundled auto-updater

Deferred. It increases signing and supply-chain surface before the release process is proven.

## Consequences

Positive:

- Teammates get a normal trusted macOS install.
- The same artifact supports direct download and Homebrew.
- No Terminal quarantine bypass.
- Clear path to release automation.

Negative:

- Requires Apple Developer Program membership and certificate management.
- Notarization adds release time and CI secret handling.
- Every nested executable/framework must be signed correctly.
- Homebrew metadata must be updated for versioned checksums.

## Release readiness gate

A release is not ready until:

- Release signing uses Developer ID Application, not development/ad hoc signing.
- Hardened Runtime is present.
- Entitlements are minimal and inspected.
- Notarization succeeds and its ticket is stapled.
- Gatekeeper accepts the packaged app.
- Authentication, Keychain, polling, launch at login, menu bar, and notch behavior survive the Release build.
- A teammate installs on a clean macOS 26 system without bypass commands.

## Sources

- Apple Developer ID for apps distributed outside the Mac App Store: https://developer.apple.com/support/developer-id/
- Apple notarization workflow and Hardened Runtime requirement: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Apple distribution preparation and App Sandbox distinction: https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution
- Homebrew Cask required version, checksum, URL, metadata, and app artifact: https://docs.brew.sh/Cask-Cookbook
