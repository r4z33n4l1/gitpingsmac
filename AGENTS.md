# GitPings agent operating rules

These instructions apply to every agent working under this folder.

## Read before editing

Read these documents in order:

1. README.md
2. docs/REQUIREMENTS.md
3. The relevant docs/architecture ADRs
4. docs/EXECUTION_PLAN.md

The requirements and accepted ADRs are the source of truth. The execution plan controls ownership, sequencing, gates, and handoffs.

## Fixed MVP boundaries

- Native Swift 6 app targeting macOS Tahoe 26 and newer.
- One GitHub.com account per local installation.
- GitHub App OAuth device flow.
- Direct Mac-to-GitHub communication only.
- No Vercel, Convex, callback server, webhooks, APNs backend, or custom API.
- Read-only GitHub permissions and operations.
- CI, mergeability, open/closed/merged lifecycle, selected repositories, configurable PR filters, and at most five pins.
- Menu-bar utility, on-demand dashboard, settings, polling, and transient notch/fallback notifications.
- No GitHub Enterprise, multiple accounts, review/deployment detail, write actions, raw advanced search, automatic updater, or older macOS support.

If a task would cross one of these boundaries, stop and escalate. Do not implement the idea as a convenience.

## Repository safety

This directory is the dedicated Git repository root. Its parent, /Users/razeenali/Documents/Solo, contains unrelated user work and an unrelated Git directory.

- Before editing, confirm git rev-parse --show-toplevel resolves exactly to /Users/razeenali/Documents/Solo/gitpingsmac.
- Run Git commands from the GitPings repository, never from Solo.
- Never stage, commit, reformat, move, or delete hardware-outreach or any unrelated parent path.
- Do not switch branches in another agent’s worktree.
- Preserve all user changes.

Worktree creation, integration branches, and release commits remain integrator-controlled.

## Single-writer rule

Only the integrator may edit:

- The Xcode project/workspace, schemes, build settings, entitlements, Info.plist, and capabilities.
- App composition root and dependency wiring.
- Frozen domain contracts and shared protocols.
- Requirements, ADRs, execution plan, and scope/change log.
- Release workflow and integration test orchestration.

Feature agents edit only their assigned paths. If a shared contract must change, send a change request to the integrator before editing.

Do not run repository-wide formatting, project generation, dependency updates, or mechanical rewrites unless the task explicitly assigns them.

## Task packet contract

Every delegated task must state:

- Task ID and objective.
- Requirement/ADR IDs covered.
- In scope.
- Explicitly out of scope.
- Owned write paths.
- Read-only dependencies.
- Expected outputs.
- Required tests and manual checks.
- Stop condition.
- Known external blockers.

An agent may read broadly but writes only within owned paths.

## Implementation rules

- Use protocols and deterministic fixtures at workstream boundaries so UI, runtime, and GitHub work can proceed in parallel.
- Do not duplicate a source of truth across SwiftUI, AppKit, persistence, and services.
- Unknown or missing GitHub data never maps to passing or mergeable.
- Disappearance from an open-PR search never implies closed or merged without a targeted lookup.
- Tokens belong in Keychain only.
- Redact tokens, authorization headers, refresh tokens, device codes, cookies, and private payloads from logs and fixtures.
- Use public macOS APIs only.
- Keep the AppKit bridge limited to the notch/fallback panel boundary.
- Avoid adding third-party runtime dependencies without an approved ADR.

## Build and test contract

The canonical local entry point is:

~~~text
./script/build_and_run.sh
~~~

It must support:

- --debug
- --logs
- --telemetry
- --verify

The Codex Run action must be wired through .codex/environments/environment.toml to that script.

Use the smallest relevant Xcode test target first. Classify failures as build, assertion, crash, timing/flake, fixture/environment, entitlement, signing, or launch failures. Do not call a task complete while its required test scope is failing.

## Handoff

Every handoff must contain:

~~~text
Task / owner:
Status: complete | partial | blocked
Branch / worktree:
Commit SHA(s):
Requirements covered:
Files changed:
Public contract or schema changes:
Tests run and exact results:
Manual verification:
Artifacts/screenshots:
Known limitations:
Security/privacy notes:
ADR deviations:
Dependencies now unblocked:
Required integration order:
Deferred suggestions:
~~~

Agents report handoffs to the integrator. Only the integrator updates persistent status/traceability documents.

## Definition of task completion

A task is complete only when:

- Its assigned requirements are implemented.
- The relevant build and tests pass.
- Required manual/device evidence is attached.
- No secret or unrelated user change is included.
- No scope or ADR deviation is hidden.
- The handoff is complete.

Agent-generated nice-to-haves belong under Deferred suggestions. They are not authorization to add scope.
