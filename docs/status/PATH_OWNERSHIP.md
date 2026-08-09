# Path ownership (Wave 0)

Integrator-controlled files must not be edited by feature agents.

| Path | Owner |
| --- | --- |
| `GitPings.xcodeproj/**` | Integrator |
| `GitPings/App/**` | Integrator |
| `GitPings/Domain/**` | Integrator (frozen after Gate 0) |
| `GitPings/Support/**` | Integrator |
| `GitPings/*.entitlements` | Integrator |
| `script/**` | Integrator |
| `.codex/**` | Integrator |
| `docs/**` | Integrator |
| `GitPings/Infrastructure/GitHub/**` | GitHub Platform |
| `GitPings/Infrastructure/Keychain/**` | GitHub Platform |
| `GitPings/Features/Authentication/**` | GitHub Platform |
| `GitPings/Features/Repositories/**` except `Views/` | GitHub Platform |
| `GitPings/Features/Repositories/Views/**` | macOS Experience |
| `GitPings/Infrastructure/Persistence/**` | Monitoring Core |
| `GitPings/Services/Refresh/**` | Monitoring Core |
| `GitPings/Services/Transitions/**` | Monitoring Core |
| `GitPings/Services/Notifications/**` | Monitoring Core |
| `GitPings/Features/PullRequests/Services/**` | Monitoring Core / GitHub as split by task packet |
| `GitPings/Features/PullRequests/Stores/**` | Monitoring Core |
| `GitPings/Features/PullRequests/Views/**` | macOS Experience |
| `GitPings/Features/MenuBar/**` | macOS Experience |
| `GitPings/Features/Notch/**` | macOS Experience |
| `GitPings/Features/Settings/**` | macOS Experience |
| `GitPings/Platform/**` | macOS Experience |
| `Fixtures/**` | Shared; each agent adds only under its task packet paths |
| `GitPingsTests/**` | Shared; prefer feature-prefixed test files |
| `GitPingsUITests/**` | macOS Experience |
| `artifacts/verification/**` | Local evidence; gitignored |
