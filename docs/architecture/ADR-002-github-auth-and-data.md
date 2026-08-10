# ADR 002: GitHub authentication and data access

Status: Accepted for MVP; amended for selectable local GitHub CLI authentication
Date: 2026-08-09

## Context

GitPings needs one-account sign-in, access to selected private repositories, configurable PR filters, CI status, and mergeability. The MVP must be read-only and should be shareable with teammates without asking them to paste personal access tokens.

A classic GitHub OAuth App is easy to understand, but its repo scope grants broad read/write access to private repository data. That conflicts with the product’s read-only promise. A native app also cannot safely embed a confidential client secret or GitHub App private key.

## Decision

Offer two user-selectable authentication methods:

1. **Local GitHub CLI (recommended for local use).** GitPings locates the
   installed `gh` executable and sends GraphQL documents through `gh api
   graphql`. It consumes JSON responses only and never calls `gh auth token`,
   prints, copies, imports, logs, or stores the CLI token. Requests are
   implementation-limited to read-only GraphQL queries. Access follows the
   active CLI account, its existing credential scopes, organization policy, and
   SSO authorization.
2. **GitNotary GitHub App.** GitPings authenticates through the public GitHub
   App's OAuth device flow and uses its fine-grained, selected-repository,
   read-only permissions. App access/refresh tokens are stored in Keychain.

The runtime architecture is deliberately client-only. The Mac app requests a device/user code from GitHub, opens GitHub’s verification page, polls GitHub for authorization, calls GitHub APIs directly, and refreshes tokens directly with GitHub. Device flow does not require a GitPings callback URL. No Vercel site, Next.js callback handler, Convex deployment, custom API, or developer-operated database is part of the MVP.

If the product later abandons device flow for a browser authorization-code flow, callback handling and secret custody must be reconsidered in a new ADR rather than silently added to this client.

GitHub App mode will:

- Be installable on selected personal or organization repositories.
- Request only read-only repository permissions required for metadata, pull requests, checks, and commit statuses.
- Use user-to-server access tokens so each local installation operates as its signed-in user within the intersection of user access, GitHub App permissions, and selected installations.
- Keep expiring user access tokens enabled.
- Store access and refresh tokens in macOS Keychain.
- Never ship a client secret or GitHub App private key.

GitHub App onboarding has two related steps:

1. Authorize the user through the device flow.
2. Install or update the GitHub App on accounts/repositories to grant repository access.

Local GitHub CLI onboarding verifies `gh auth status`/`gh api user`, then opens
GitPings with the expected login and method. Switching methods disconnects the
old provider, clears private cached repository/PR data, selections, and pins,
and establishes new transition baselines. Disconnecting CLI mode does not run
`gh auth logout`.

Organization owners may need to approve installation. SAML-protected organizations may require an active SSO session.

## Query strategy

Use GitHub GraphQL as the primary product API.

### Discover repositories

List repositories visible through the active method, then persist the user's
local selected set by stable node ID.

### Find matching PRs

Compile the enabled product filters into one or more GitHub search-syntax queries:

- Base: open pull requests in selected repositories
- All: no actor qualifier
- Authored: author plus authenticated login
- Assigned: assignee plus authenticated login
- Review requested: review-requested plus authenticated login

Run separate queries where needed for unambiguous OR behavior, merge results locally by PR global node ID, and paginate. This deliberately uses GitHub’s search semantics instead of reimplementing them from a downloaded universe.

### Fetch product fields

Request only fields needed for the MVP:

- Stable PR/repository IDs
- Repository owner/name and visibility
- PR number, title, URL, author, state, branches, updated time
- Status check rollup for the head ref
- Mergeable
- Merge-state status

The technical spike must confirm the exact GraphQL permission set and schema fields against a private organization repository before implementation is considered unblocked.

## Normalization

GitHub’s raw fields are mapped to the product states defined in REQUIREMENTS.md. Mapping occurs in a pure, versioned normalization layer.

Rules:

- Missing or unrecognized enum values map to Unknown, not success.
- CI and mergeability remain independent.
- GitHub’s UNKNOWN mergeability maps to Checking during a fresh calculation window and Unknown when stale.
- A technically mergeable PR with a blocked merge-state maps to Blocked.
- A conflicting/dirty result maps to Conflicting regardless of CI.

Unit tests must cover every currently documented enum value plus an unknown/default case.

## Authentication lifecycle

- Device authorization codes are displayed only during GitHub App onboarding and never logged.
- GitHub App access and refresh tokens are Keychain items scoped to the bundle identifier and GitHub account ID.
- GitHub CLI credentials remain owned by `gh`; GitPings retains only the selected method and connected account metadata.
- Refresh happens before expiry when possible and is serialized.
- One failed request may trigger one coordinated refresh-and-retry, never a retry storm.
- A rejected refresh returns the app to a visible reauthorization state.
- Disconnect deletes GitPings' GitHub App tokens when applicable and clears cached GitHub data; it never signs out GitHub CLI globally.

## Alternatives considered

### Classic OAuth App

Rejected for MVP private-repository access. GitHub’s repo OAuth scope includes write access, even though GitPings would choose not to call write endpoints. This makes the authorization prompt and potential token impact broader than the product requires.

### Personal access token

Rejected. PAT setup is poor onboarding, encourages manual secret handling, complicates teammate sharing, and undermines a native sign-in experience.

### Import the GitHub CLI token

Rejected. Calling `gh auth token` would copy a broader credential into another
process and storage boundary. Invoking `gh api graphql` keeps credential custody
with GitHub CLI and lets GitPings receive only API JSON.

### GitHub App installation tokens generated locally

Rejected. Generating installation tokens requires signing a JWT with the GitHub App private key; embedding that private key in a distributable client would compromise it.

### Hosted token broker and webhooks

Deferred. A backend can hold GitHub App credentials, issue installation tokens, and receive webhooks, but adds operations, data handling, cost, and privacy scope. The local MVP does not require it.

### Vercel callback plus Convex state

Deferred for the same reason. It would make a browser authorization-code callback and shared state straightforward, but it is unnecessary for device flow and local persistence. Introduce it only with a new ADR if a future requirement needs webhooks, cross-device/team synchronization, a web surface, or server-mediated installation tokens.

### REST-only

Not selected. GraphQL can retrieve the exact nested PR/check/merge fields needed with fewer round trips and supports GitHub search syntax. REST may be used narrowly if a required installation/discovery operation is clearer or unavailable in GraphQL.

## Consequences

Positive:

- One-command local setup for people already using GitHub CLI.
- Optional fine-grained, read-only GitHub App permissions and repository-level installation control.
- No PAT and no embedded secret.
- Suitable for teammate installs.
- Search semantics align with GitHub’s own PR filtering concepts.

Negative:

- CLI credentials may have broader scopes than GitPings uses.
- CLI mode requires `gh`, follows its organization/SSO policies, and requires a non-sandboxed Developer ID build because App Sandbox cannot execute the Homebrew binary.
- GitHub App onboarding includes authorization and installation; organization approval can block private repo access.
- User tokens expire and require refresh handling.
- Search results and nested status connections must be paginated and kept within node/rate limits.
- GraphQL permissions are less self-describing than REST and require an explicit spike.

## Sources

- GitHub recommends GitHub Apps for fine-grained permissions and short-lived tokens: https://docs.github.com/en/apps/oauth-apps/building-oauth-apps
- A classic OAuth repo scope grants broad access including write capabilities: https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps
- GitHub App user tokens are limited by both the user and installed app permissions: https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-with-a-github-app-on-behalf-of-a-user
- GitHub documents device flow for desktop applications and GitHub Apps: https://docs.github.com/en/enterprise-cloud@latest/apps/creating-github-apps/writing-code-for-a-github-app/building-a-cli-with-a-github-app
- Expiring user tokens and refresh tokens: https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/refreshing-user-access-tokens
- GraphQL pagination and one-to-100 connection page sizing: https://docs.github.com/en/graphql/guides/using-pagination-in-the-graphql-api
- GraphQL point, node, and secondary limits: https://docs.github.com/en/graphql/overview/rate-limits-and-query-limits-for-the-graphql-api
- GitHub CLI `gh api` supports GraphQL and standard-input request bodies: https://cli.github.com/manual/gh_api
- Apple documents that a sandboxed app cannot run programs outside its bundle, container, or app-group containers: https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox
