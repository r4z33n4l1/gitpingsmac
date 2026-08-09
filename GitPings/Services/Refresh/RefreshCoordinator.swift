import Foundation

/// Single-flight refresh coordinator with trigger coalescing (ADR-003 / REFRESH-*).
///
/// - Only one cycle runs at a time.
/// - Timer/manual/popover/dashboard/wake/network/config triggers coalesce.
/// - Uses an injected clock; does not wall-sleep.
/// - Missing open-search PRs require targeted lookup before transition detection.
public actor RefreshCoordinator: RefreshCoordinating {
    public struct Status: Hashable, Sendable {
        public var isRunning: Bool
        public var lastAttemptAt: Date?
        public var lastSuccessAt: Date?
        public var nextEligibleAt: Date?
        public var pendingTriggerCount: Int
        public var lastRateLimit: RateLimitSnapshot?
        public var baselinePending: Bool
    }

    private let clock: any ClockProviding
    private let queryService: any PullRequestQueryService
    private let preferences: any PreferencesStore
    private let cache: any PRCacheStore
    private let snapshots: any SnapshotStore
    private let detector: any TransitionDetecting
    private let router: any NotificationRouting
    private let history: any TransitionHistoryStore
    private let repositoriesProvider: @Sendable () async throws -> [RepositorySummary]
    private let authenticatedLoginProvider: @Sendable () async throws -> String

    private var started = false
    private var cycleRunning = false
    private var pendingTriggers = Set<RefreshTrigger>()
    private var lastAttemptAt: Date?
    private var lastSuccessAt: Date?
    private var nextEligibleAt: Date?
    private var lastRateLimit: RateLimitSnapshot?
    private var baselinePending = true
    private var backoffSeconds: TimeInterval = 0

    public static let desiredInterval: TimeInterval = 60
    public static let wakeDebounce: TimeInterval = 2

    public init(
        clock: any ClockProviding,
        queryService: any PullRequestQueryService,
        preferences: any PreferencesStore,
        cache: any PRCacheStore,
        snapshots: any SnapshotStore,
        detector: any TransitionDetecting = TransitionDetector(),
        router: any NotificationRouting,
        history: any TransitionHistoryStore,
        repositoriesProvider: @escaping @Sendable () async throws -> [RepositorySummary],
        authenticatedLoginProvider: @escaping @Sendable () async throws -> String
    ) {
        self.clock = clock
        self.queryService = queryService
        self.preferences = preferences
        self.cache = cache
        self.snapshots = snapshots
        self.detector = detector
        self.router = router
        self.history = history
        self.repositoriesProvider = repositoriesProvider
        self.authenticatedLoginProvider = authenticatedLoginProvider
    }

    public func status() -> Status {
        Status(
            isRunning: cycleRunning,
            lastAttemptAt: lastAttemptAt,
            lastSuccessAt: lastSuccessAt,
            nextEligibleAt: nextEligibleAt,
            pendingTriggerCount: pendingTriggers.count,
            lastRateLimit: lastRateLimit,
            baselinePending: baselinePending
        )
    }

    public func start() async {
        started = true
        await requestRefresh(reason: .timer)
    }

    public func stop() async {
        started = false
        pendingTriggers.removeAll()
    }

    public func requestRefresh(reason: RefreshTrigger) async {
        guard started || reason == .manual || reason == .configurationChanged else { return }
        pendingTriggers.insert(reason)
        if reason == .configurationChanged {
            baselinePending = true
        }
        await pump()
    }

    /// Marks that the next successful cycle should establish baselines without events.
    public func markBaselinePending() {
        baselinePending = true
    }

    private func pump() async {
        guard !cycleRunning else { return }
        cycleRunning = true
        defer { cycleRunning = false }

        while started || !pendingTriggers.isEmpty {
            guard !pendingTriggers.isEmpty else { break }

            let now = clock.now()
            if let nextEligibleAt, now < nextEligibleAt {
                // No wall sleep: leave triggers pending until a later request after clock advances.
                break
            }

            let triggers = pendingTriggers
            pendingTriggers.removeAll()
            await runCycle(triggers: triggers)
        }
    }

    private func runCycle(triggers: Set<RefreshTrigger>) async {
        let now = clock.now()
        lastAttemptAt = now

        do {
            let login = try await authenticatedLoginProvider()
            let repositories = try await repositoriesProvider()
            let selectedIDs = Set(try await preferences.selectedRepositoryIDs())
            let selectedRepos = repositories.filter { selectedIDs.contains($0.id) }
            let filters = try await preferences.filterConfiguration()

            let fetch = try await queryService.fetchTrackedPullRequests(
                repositories: selectedRepos,
                filters: filters,
                authenticatedLogin: login
            )
            lastRateLimit = fetch.rateLimit

            let previous = try await snapshots.lastNormalizedSnapshots()
            let verifiedCurrent = try await resolveMissingWithLookup(
                previous: previous,
                openSearch: fetch.prs
            )

            let events = detector.detectTransitions(
                previous: previous,
                current: verifiedCurrent,
                baselineMode: baselinePending,
                observedAt: now
            )

            try await cache.replaceCache(with: verifiedCurrent, refreshedAt: now)
            let snapshotMap = Dictionary(uniqueKeysWithValues: verifiedCurrent.map { ($0.id, $0) })
            try await snapshots.saveNormalizedSnapshots(snapshotMap)

            if !baselinePending {
                for event in events {
                    try await history.append(event)
                }
                await router.route(events: events)
            }

            baselinePending = false
            lastSuccessAt = now
            backoffSeconds = 0
            nextEligibleAt = now.addingTimeInterval(Self.desiredInterval)
            _ = triggers
        } catch {
            backoffSeconds = backoffSeconds == 0 ? 30 : min(backoffSeconds * 2, 15 * 60)
            nextEligibleAt = now.addingTimeInterval(backoffSeconds)
            // Preserve last successful cache/snapshots on failure (ADR-003).
        }
    }

    /// CHANGE-3A: disappearance from open search requires targeted lookup.
    private func resolveMissingWithLookup(
        previous: [GitHubNodeID: PullRequestSummary],
        openSearch: [PullRequestSummary]
    ) async throws -> [PullRequestSummary] {
        var byID = Dictionary(uniqueKeysWithValues: openSearch.map { ($0.id, $0) })
        let missing = previous.keys.filter { byID[$0] == nil }
        for id in missing {
            if let lookedUp = try await queryService.lookupPullRequest(id: id) {
                // Include only when lookup yields a verified terminal or still-tracked row.
                // Still-open but filter-excluded rows are omitted → no false closed event.
                if lookedUp.lifecycleState == .closed || lookedUp.lifecycleState == .merged {
                    byID[id] = lookedUp
                }
            }
            // Lookup nil / failure: omit → detector will not emit closedOrMerged.
        }
        return Array(byID.values)
    }
}
