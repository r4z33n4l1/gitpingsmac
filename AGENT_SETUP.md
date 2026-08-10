# GitPings AI-assisted setup guide

This document is for an AI agent helping a person install and configure
GitPings on their Mac. It describes the end-user setup flow, not the maintainer
release process.

GitPings is a read-only macOS utility that talks directly to GitHub. Its default
setup uses the GitHub CLI account already authenticated on the Mac. It does not
need a GitPings server, OAuth callback site, Vercel project, Convex database,
personal access token paste, GitHub App private key, or client secret.

## Copy-paste prompt for a setup agent

```text
Help me install and configure GitPings from its official GitHub release or
Homebrew tap. Read AGENT_SETUP.md, README.md, and docs/DISTRIBUTION.md before
acting. Guide me one step at a time, explain every command that changes my Mac,
and verify each completed step.

Use the GitHub CLI account already selected on this Mac, but never read, print,
copy, export, or import its token. GitPings should use Local GitHub CLI mode and
execute read-only `gh api graphql` queries. Hand control back to me for `gh auth
login`, SSO, browser authorization, or any permission prompt. Never ask me to
paste a PAT, password, device code, client secret, private key, or Apple
credential into chat.

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

GitPings uses GitHub CLI as its credential owner and API transport. It never asks
GitHub CLI to reveal the token.

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

The command verifies the active `gh` login, launches GitPings, selects **Local
GitHub CLI**, and connects that account. GitPings invokes `gh api graphql` and
consumes only JSON responses. If access to an organization requires SSO or OAuth
approval, hand control to the user to complete it.

An optional **GitNotary GitHub App** method is available in Settings → Account
for users who prefer fine-grained selected-repository permissions. Its device
flow and installation may require organization approval. Do not switch methods
without explaining that GitPings clears its private local cache and creates a
fresh notification baseline.

### 4. Select repositories in GitPings

After authorization:

1. Open the GitPings dashboard.
2. Choose **Add Repository**.
3. Search the repositories available through the active authentication method.
4. Add only the repositories the user wants monitored.
5. Configure the PR filters in Settings.
6. Pin up to five pull requests for the menu-bar quick view.

The dashboard intentionally shows only selected repositories. Provider access
and GitPings selection are separate: making a repository available through the
CLI or App allows discovery, while adding it in GitPings begins monitoring it.

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
3. Settings → Account reports the intended authentication method and account.
4. The dashboard lists only repositories selected in GitPings.
5. A PR row shows repository/number, title, CI state, and merge state.
6. Clicking a PR opens its GitHub URL in the default browser.
7. **Settings → Notifications → Test Notch Notification** presents the notch
   animation on a notched built-in display, or the top-center fallback pill on a
   notchless/external display.
8. **Test 4-PR Notification Queue** shows one PR at a time and advances through
   the remaining locally queued alerts.

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

For Local GitHub CLI mode, confirm the CLI can access the expected repository:

```bash
gh repo view OWNER/REPOSITORY
```

For GitHub App mode, confirm the GitNotary installation at
`https://github.com/settings/installations`. After access is approved, reopen
GitPings, use **Add Repository**, and refresh.

### Wrong GitHub account

Select the intended GitHub CLI account, then restart the GitPings flow:

```bash
gh auth status
gh auth switch
gitnotary setup
```

Do not transfer the GitHub CLI token into GitPings. The app will invoke `gh`
using the newly active account.

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
