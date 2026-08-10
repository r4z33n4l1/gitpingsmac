import Foundation

/// Abstract wall clock for deterministic refresh/transition tests.
public protocol ClockProviding: Sendable {
    func now() -> Date
}

public struct SystemClock: ClockProviding {
    public init() {}
    public func now() -> Date { Date() }
}

public struct FixedClock: ClockProviding {
    private let instant: Date
    public init(_ instant: Date) { self.instant = instant }
    public func now() -> Date { instant }
}

public protocol AuthService: Sendable {
    func currentSession() async -> AuthSessionState
    func beginDeviceFlow() async throws -> AuthSessionState
    func pollDeviceFlow() async throws -> AuthSessionState
    func cancelDeviceFlow() async
    func signOut() async throws
    func refreshAccessTokenIfNeeded() async throws
}

public protocol KeychainTokenStore: Sendable {
    func loadTokens(for accountID: GitHubNodeID) async throws -> (accessToken: String, refreshToken: String?)?
    func saveTokens(accountID: GitHubNodeID, accessToken: String, refreshToken: String?) async throws
    func deleteTokens(for accountID: GitHubNodeID) async throws
    func deleteAllTokens() async throws
}

public protocol RepositoryCatalogService: Sendable {
    func listInstallableRepositories() async throws -> [RepositorySummary]
}

public protocol PullRequestQueryService: Sendable {
    func fetchTrackedPullRequests(
        repositories: [RepositorySummary],
        filters: PRFilterConfiguration,
        authenticatedLogin: String
    ) async throws -> (prs: [PullRequestSummary], rateLimit: RateLimitSnapshot)

    /// Targeted lookup before classifying disappearance from open search as closed/merged.
    func lookupPullRequest(id: GitHubNodeID) async throws -> PullRequestSummary?
}

public protocol PinStore: Sendable {
    func pinnedIDs() async throws -> [GitHubNodeID]
    func pin(_ id: GitHubNodeID) async throws
    func unpin(_ id: GitHubNodeID) async throws
    func reorder(to orderedIDs: [GitHubNodeID]) async throws
    func replace(existing: GitHubNodeID, with replacement: GitHubNodeID) async throws
}

public protocol PreferencesStore: Sendable {
    func selectedRepositoryIDs() async throws -> [GitHubNodeID]
    func setSelectedRepositoryIDs(_ ids: [GitHubNodeID]) async throws
    func filterConfiguration() async throws -> PRFilterConfiguration
    func setFilterConfiguration(_ configuration: PRFilterConfiguration) async throws
}

public protocol PRCacheStore: Sendable {
    func cachedPullRequests() async throws -> [PullRequestSummary]
    func replaceCache(with prs: [PullRequestSummary], refreshedAt: Date) async throws
    func lastSuccessfulRefreshAt() async throws -> Date?
    func purgePrivateGitHubData() async throws
}

public protocol SnapshotStore: Sendable {
    func lastNormalizedSnapshots() async throws -> [GitHubNodeID: PullRequestSummary]
    func saveNormalizedSnapshots(_ snapshots: [GitHubNodeID: PullRequestSummary]) async throws
}

public protocol TransitionHistoryStore: Sendable {
    func recentEvents(limit: Int) async throws -> [TransitionEvent]
    func append(_ event: TransitionEvent) async throws
    func prune(retainingNewest newest: Int, olderThan cutoff: Date) async throws
}

public protocol RefreshCoordinating: Sendable {
    func requestRefresh(reason: RefreshTrigger) async
    func start() async
    func stop() async
}

public enum RefreshTrigger: String, Sendable {
    case timer
    case manual
    case popoverOpen
    case dashboardOpen
    case wake
    case networkRestored
    case configurationChanged
}

public protocol TransitionDetecting: Sendable {
    func detectTransitions(
        previous: [GitHubNodeID: PullRequestSummary],
        current: [PullRequestSummary],
        baselineMode: Bool,
        observedAt: Date
    ) -> [TransitionEvent]
}

public protocol NotificationRouting: Sendable {
    func route(events: [TransitionEvent]) async
    func sendTestNotification(channel: NotificationChannel) async
}

public enum NotificationChannel: String, Sendable, CaseIterable {
    case notch
    case system
    case sound
}

@MainActor
public protocol NotchPresenting: Sendable {
    func present(events: [TransitionEvent]) async
    func dismiss() async
}

public protocol SystemNotificationPresenting: Sendable {
    func requestAuthorizationIfNeeded() async -> Bool
    func present(event: TransitionEvent) async
}

public protocol LaunchAtLoginManaging: Sendable {
    var isEnabled: Bool { get async }
    func setEnabled(_ enabled: Bool) async throws
}

public protocol URLOpening: Sendable {
    func open(_ url: URL) async
}

/// Severity for the menu-bar icon from pinned PR states (ADR 004 / MENUBAR-7).
public enum MenuBarSeverityCalculator {
    public static func severity(for pinned: [PullRequestSummary]) -> MenuBarSeverity {
        guard !pinned.isEmpty else { return .neutral }

        if pinned.contains(where: { $0.ciState == .failing || $0.mergeState == .conflicting }) {
            return .attention
        }

        if pinned.contains(where: {
            $0.ciState == .pending
                || $0.ciState == .unknown
                || $0.mergeState == .checking
                || $0.mergeState == .unknown
                || $0.mergeState == .blocked
        }) {
            return .inProgress
        }

        let allHealthy = pinned.allSatisfy {
            $0.ciState == .passing && $0.mergeState == .mergeable
        }
        return allHealthy ? .healthy : .inProgress
    }
}

public enum PinPolicy {
    public static let maximumPinCount = 5

    public static func canPin(currentCount: Int) -> Bool {
        currentCount < maximumPinCount
    }

    /// Terminal PRs leave the ambient quick view after their transition has
    /// been observed. Unknown lifecycle values stay pinned rather than being
    /// treated as closed or merged.
    public static func removingTerminalPullRequests(
        from pinnedIDs: [GitHubNodeID],
        pullRequests: [PullRequestSummary]
    ) -> [GitHubNodeID] {
        let terminalIDs = Set(
            pullRequests.lazy
                .filter { $0.lifecycleState == .closed || $0.lifecycleState == .merged }
                .map(\.id)
        )
        return pinnedIDs.filter { !terminalIDs.contains($0) }
    }

    public static func shouldMonitorVerifiedLookup(
        _ pullRequest: PullRequestSummary,
        isPinned: Bool
    ) -> Bool {
        isPinned
            || pullRequest.lifecycleState == .closed
            || pullRequest.lifecycleState == .merged
    }
}
