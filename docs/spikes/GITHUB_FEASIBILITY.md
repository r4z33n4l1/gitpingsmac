# GitHub client-only feasibility spike

Task: S1 (GitHub Platform)  
Branch: `cursor/s1-github-feasibility-03e3` (from `codex/wave-0-foundation`)  
ADR: ADR-002  
Requirements: AUTH-1..AUTH-8, REPO-1..REPO-6, FILTER-1..FILTER-5, PR-4/PR-9, REFRESH-4/REFRESH-5  
Host evidence: **Linux cloud agent — no live Xcode / no live device-flow claim**

## Verdict (fixture-backed)

Client-only GitHub App **OAuth device flow** + **GraphQL search** is the correct MVP shape and is sketchable against frozen Domain contracts without a callback server, client secret, or private key.

Live proof (real client ID, private org repo field capture, Keychain round-trip) remains **blocked** until a macOS host and GitHub App registration exist.

## Device flow (no callback)

GitHub App is a **public** client. Device flow talks Mac ↔ GitHub only (AUTH-2, AUTH-2A).

| Step | Endpoint | Notes |
| --- | --- | --- |
| 1. Request codes | `POST https://github.com/login/device/code` | Body: `client_id`, `scope` (empty / omitted for GitHub App user-to-server). Response: `device_code`, `user_code`, `verification_uri`, `expires_in`, `interval`. |
| 2. Show user code | Local UI only | Display `user_code`; open `verification_uri` (or `verification_uri_complete` if present). **Never log** device/user codes. |
| 3. Poll token | `POST https://github.com/login/oauth/access_token` | Body: `client_id`, `device_code`, `grant_type=urn:ietf:params:oauth:grant-type:device_code`. Accept `application/json`. |
| 4. Handle poll | Local state machine | `authorization_pending` → wait `interval`; `slow_down` → increase interval; `expired_token` / `access_denied` → recoverable failure; success → store tokens. |
| 5. Refresh | Same token endpoint | `grant_type=refresh_token` + `refresh_token`. Serialize refresh; one coordinated retry (ADR-002). |
| 6. Install App | Browser | Separate from authorize: user installs/updates App on selected repos/orgs (AUTH-3, REPO-6). |

**Not used:** authorization-code callback URL, Vercel/Convex, PAT paste, installation JWT signed with App private key.

**Client credentials on device:** only the public `client_id` (injected at build/config time by integrator). No client secret, no App private key (AUTH-6).

Sketch: `DeviceFlowClient` + `DeviceFlowAuthService` under owned paths. Domain `AuthService` remains the product boundary.

## Required read-only permissions

See `permission-manifest.json`. MVP App repository permissions (all **read**):

| Permission | Access | Why |
| --- | --- | --- |
| Metadata | read (mandatory) | Repo identity / listing via installation |
| Pull requests | read | PR search + fields |
| Checks | read | Check runs / status check rollup |
| Commit statuses | read | Combined status when rollup depends on it |
| Contents | read | Conservative; may be needed for some head-ref / file metadata — **confirm live** |

No write permissions. No admin, no Actions write, no webhook delivery for MVP.

User-to-server tokens are further limited by the signed-in user’s access ∩ App installation selection.

## GraphQL field list (product minimum)

Primary API: GraphQL (`POST https://api.github.com/graphql`).

### Viewer / login (FILTER-4)

```graphql
viewer { id login }
```

### Installations → repositories (REPO-1..3)

Prefer GraphQL `viewer { repositories(...) }` **only if** it reflects App-installed access; otherwise narrow REST `GET /user/installations` + `GET /user/installations/{id}/repositories` (ADR-002 allows narrow REST). Spike default GraphQL draft is in `GraphQLQueries.swift`.

Needed fields:

- `id` (global node)
- `name`, `nameWithOwner`, `isPrivate`
- `owner { login __typename }` (personal vs organization)

### Filtered open PR search (FILTER-1..5, REFRESH-4)

`search(query:, type: ISSUE, first:, after:)` with compiled GitHub search syntax from `FilterQueryCompiler`.

Per node (`... on PullRequest`):

| Field | Product use |
| --- | --- |
| `id` | Stable identity / pins |
| `number`, `title`, `url` | Row / detail |
| `author { login }` | Row |
| `state`, `merged` | Lifecycle (open/closed/merged) |
| `headRefName`, `baseRefName` | Detail |
| `updatedAt` | Detail / ordering |
| `mergeable` | Merge normalization |
| `mergeStateStatus` | Merge normalization |
| `repository { id nameWithOwner isPrivate }` | Repo association |
| `commits(last: 1) { nodes { commit { statusCheckRollup { state contexts { totalCount } } } } }` | CI rollup |

Targeted lookup before classifying disappearance (CHANGE-3A):

```graphql
node(id: $id) { ... on PullRequest { /* same fields */ } }
```

## Pagination

- Search connection: `pageInfo { hasNextPage endCursor }`, page size ≤ 100 (GitHub max).
- One enabled filter ⇒ one search query stream; multiple enabled filters ⇒ **separate** queries (OR), merge by PR `id` locally.
- Selected repos encoded as repeated `repo:owner/name` qualifiers; if query string length risks GitHub limits, shard repos across queries (documented in `FilterQueryCompiler`).
- Nested `commits` uses `last: 1` only (head tip for rollup).
- Cost worksheet: `COST_PROJECTION.md`.

## Rate-limit notes (REFRESH-5)

- Read `rateLimit { limit remaining resetAt cost }` on every GraphQL document (or response headers `x-ratelimit-*` / `retry-after`).
- Map into Domain `RateLimitSnapshot`.
- On exhaustion or secondary rate limit: backoff visible to Settings; backoff beats the 60s poll target.
- Point cost grows with search pages × filter fan-out × selected-repo shards; keep field selection minimal.
- Search API also has its own abuse/secondary limits — treat `403`/`502` with Retry-After as backoff, not empty success.

## Normalization rules (PR-9)

Implemented as pure helpers in `GitHubStateMapping.swift`:

- Missing / unrecognized CI rollup → `CIState.unknown` (never `.passing`).
- Empty rollup / no contexts → `CIState.noChecks` when GitHub clearly reports absence; otherwise unknown.
- Missing / unrecognized merge fields → `MergeState.unknown` (never `.mergeable`).
- `mergeable == UNKNOWN` → `.checking` when observation is fresh; `.unknown` when stale (caller supplies freshness).
- `mergeStateStatus == BLOCKED` → `.blocked` even if mergeable is MERGEABLE.
- Dirty / conflicting → `.conflicting` regardless of CI.

## Fixtures

Under `Fixtures/github/`:

- Extended `sample_tracked_prs.json`
- Redacted device-flow poll shapes (`device_flow_responses.json`) — codes replaced with `[REDACTED]`
- Redacted GraphQL search / installation envelopes
- No tokens, Authorization headers, cookies, or private file contents

## Blockers (external)

1. **GitHub App client ID** not available in this environment.
2. **macOS Tahoe + Xcode** host required for Keychain, signing, and `xcodebuild` tests.
3. **Org App install approval** + SAML SSO session for private org proof.
4. **Private test repository** to confirm exact GraphQL permission/field availability (ADR-002 spike gate).
5. Integrator must wire new Swift files into `GitPings.xcodeproj` (single-writer).

## Stop condition status

| Item | Status |
| --- | --- |
| Query/permission feasibility documented | Done (fixture-backed) |
| No secrets committed | Done |
| Live device-flow + private org capture | **Blocked** |
| Unit tests authored | Done (`GitHubFilterCompilerTests.swift`) — not executed (no Xcode) |

Escalate to integrator: project membership for new sources; client ID injection site; confirm Contents:read necessity live.
