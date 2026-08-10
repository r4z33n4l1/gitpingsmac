# GitPings AI-assisted setup guide

This document is for an AI agent helping a person install and configure
GitPings on their Mac. It describes the end-user setup flow, not the maintainer
release process.

GitPings is a read-only macOS utility that talks directly to GitHub. It does not
need a GitPings server, OAuth callback site, Vercel project, Convex database,
personal access token, GitHub App private key, or client secret.

## Copy-paste prompt for a setup agent

```text
Help me install and configure GitPings from its official GitHub release or
Homebrew tap. Read AGENT_SETUP.md, README.md, and docs/DISTRIBUTION.md before
acting. Guide me one step at a time, explain every command that changes my Mac,
and verify each completed step.

Use the GitHub CLI account already selected on this Mac, but never read, print,
copy, or import its token. GitPings must complete its own read-only GitHub App
Device Flow. Hand control back to me for browser authorization or any permission
prompt. Never ask me to paste a PAT, password, device code, client secret,
private key, or Apple credential into chat.

Prefer the public Homebrew tap when its Cask is available. Do not bypass
Gatekeeper, remove quarantine attributes, weaken macOS security, or install an
unsigned build. After setup, verify the installed version, GitHub account,
repository access, menu-bar item, dashboard, and test notch notification.
```

## Agent contract

Before making changes, the agent should:

1. Confirm this is macOS 26 or newer and that the user wants the public
   `r4z33n4l1/gitpingsmac` project.
2. Read [README.md](README.md) and
   [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md).
3. Inspect rather than assume the current installation state.
4. Explain any installation command before running it.
5. Preserve an existing working installation unless the user approves replacing
   or upgrading it.

The agent must not:

- request, display, or store the user's GitHub CLI token;
- use `gh auth token`, import a token into GitPings, or ask for a PAT;
- request a GitHub App private key or client secret;
- request an Apple ID password or app-specific password from an end user;
- use `xattr -d`, `spctl --master-disable`, ad-hoc signing, or another Gatekeeper
  bypass;
- authorize repositories beyond the selection the user approves; or
- claim success without running the verification steps below.

## Guided setup flow

### 1. Check the Mac and prerequisites

Run read-only checks first:

```bash
sw_vers -productVersion
uname -m
command -v brew || true
command -v gh || true
gh auth status
```

Requirements:

- macOS Tahoe 26 or newer;
- Homebrew for the preferred installation path; and
- GitHub CLI authenticated to the GitHub.com account the user wants to use.

If `gh` is missing and the user approves installing it:

```bash
brew install gh
```

If GitHub CLI is not authenticated, ask the user to run:

```bash
gh auth login
```

GitHub CLI identifies the expected account only. GitPings performs a separate
GitHub App authorization and stores its own token in macOS Keychain.

### 2. Install GitPings

Prefer the project-owned public tap:

```bash
brew info --cask r4z33n4l1/gitnorary/gitpings
brew install --cask r4z33n4l1/gitnorary/gitpings
```

If the Cask is not available, stop and direct the user to the signed assets on
the project's [GitHub Releases](https://github.com/r4z33n4l1/gitpingsmac/releases)
page. Do not substitute an unnotarized build or bypass Gatekeeper.

For a manual release install, verify the matching checksum before opening it:

```bash
shasum -a 256 -c GitPings-<version>.zip.sha256
```

Then extract `GitPings.app` and move it to `/Applications`.

### 3. Connect GitHub

Run:

```bash
gitnotary setup
```

The command verifies the active `gh` login, launches GitPings, and starts the
public GitNotary GitHub App Device Flow. The agent must hand control to the user
for the browser authorization step. Do not copy the one-time code into chat or
retain it in logs.

When GitHub asks where to install GitNotary, let the user choose their personal
account or an approved organization and select the repositories they want the
app to read. Organization installations may require owner approval.

The public GitHub App is:

- [GitNotary](https://github.com/apps/gitnotary)
- read-only for repository metadata, contents, pull requests, checks, and commit
  statuses;
- configured without webhooks or a GitPings-operated server.

### 4. Select repositories in GitPings

After authorization:

1. Open the GitPings dashboard.
2. Choose **Add Repository**.
3. Search the repositories available to the GitHub App.
4. Add only the repositories the user wants monitored.
5. Configure the PR filters in Settings.
6. Pin up to five pull requests for the menu-bar quick view.

The dashboard intentionally shows only selected repositories. GitHub App access
and GitPings selection are separate: granting a repository to the App makes it
available, while adding it in GitPings begins monitoring it.

### 5. Verify the installation

Run:

```bash
gitnotary version
gitnotary doctor
brew list --cask gitpings
codesign --verify --deep --strict --verbose=2 /Applications/GitPings.app
spctl --assess --type execute --verbose=4 /Applications/GitPings.app
xcrun stapler validate /Applications/GitPings.app
```

Then verify in the UI:

1. GitPings appears in the Dock while its dashboard is open.
2. A GitPings status item remains in the menu bar while the app is running.
3. The dashboard lists only repositories selected in GitPings.
4. A PR row shows repository/number, title, CI state, and merge state.
5. Clicking a PR opens its GitHub URL in the default browser.
6. **Settings → Notifications → Send Test Notification** presents the notch
   animation on a notched built-in display, or the top-center fallback pill on a
   notchless/external display.

Do not describe the macOS presentation as ActivityKit or a native Dynamic Island.
It is a public-API AppKit `NSPanel` hosting SwiftUI and visually attaching to the
MacBook notch.

## Troubleshooting

### `gitnotary: command not found`

For a manual installation, run the bundled helper directly:

```bash
/Applications/GitPings.app/Contents/Resources/gitnotary doctor
/Applications/GitPings.app/Contents/Resources/gitnotary setup
```

For a Homebrew installation, inspect the Cask and linked binary:

```bash
brew list --cask gitpings
command -v gitnotary
```

### No repositories appear

Confirm the GitNotary installation has access to the expected repositories:

```bash
open https://github.com/settings/installations
```

After access is approved, reopen GitPings, use **Add Repository**, and refresh.

### Wrong GitHub account

First select the intended GitHub CLI account, then restart the GitPings flow:

```bash
gh auth status
gh auth switch
gitnotary setup
```

Do not transfer the GitHub CLI token into GitPings.

### No menu-bar item or notification

```bash
open -a GitPings
gitnotary doctor
```

Check that GitPings is still running, look for hidden menu-bar items when the bar
is crowded, and confirm the notch/fallback channel is enabled in
**Settings → Notifications**. Custom notifications are suppressed over
full-screen apps by default.

### Gatekeeper rejects the app

Stop. Record the exact `spctl` and `stapler` output and report it to the project.
Do not remove quarantine attributes or disable macOS security.

## Setup completion report

A setup agent should finish with a concise report containing:

- installation source and installed version;
- `gitnotary doctor` result;
- expected GitHub login (never a token);
- number of repositories made available and selected;
- menu-bar/dashboard verification;
- test notification result and display type; and
- any remaining approval or troubleshooting action.

