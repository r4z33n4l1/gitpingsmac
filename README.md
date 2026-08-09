# GitPings for macOS

GitPings is a proposed macOS menu-bar utility for monitoring pull requests across selected GitHub repositories. It keeps a small set of pinned PRs close at hand and uses a notch-attached notification to surface meaningful CI and mergeability changes.

This folder currently contains product and architecture planning:

- [Product requirements](docs/REQUIREMENTS.md)
- [Multi-agent execution plan](docs/EXECUTION_PLAN.md)
- [Agent operating rules](AGENTS.md)
- [Fresh-agent bootstrap prompt](docs/AGENT_BOOTSTRAP_PROMPT.md)
- [ADR 001 — Native app architecture](docs/architecture/ADR-001-native-app-architecture.md)
- [ADR 002 — GitHub authentication and data access](docs/architecture/ADR-002-github-auth-and-data.md)
- [ADR 003 — Polling and state-change notifications](docs/architecture/ADR-003-polling-and-notifications.md)
- [ADR 004 — Menu-bar and notch presentation](docs/architecture/ADR-004-menu-bar-and-notch-ui.md)
- [ADR 005 — Packaging and teammate distribution](docs/architecture/ADR-005-packaging-and-distribution.md)

Working product name: **GitPings**
Project folder: **gitpingsmac**
Target: **macOS Tahoe 26 and newer**
