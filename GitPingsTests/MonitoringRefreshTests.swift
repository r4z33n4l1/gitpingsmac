import XCTest
@testable import GitPings

final class MonitoringRefreshTests: XCTestCase {
    func testSingleFlightCoalescesMultipleTriggersIntoOneSuccess() async throws {
        let clock = ControllableClock(GitPingsFixtures.fixedNow)
        let query = CountingQueryService()
        let preferences = InMemoryPreferencesStore(
            selectedIDs: [GitPingsFixtures.publicRepo.id]
        )
        let cache = InMemoryPRCacheStore()
        let snapshots = InMemorySnapshotStore()
        let history = InMemoryTransitionHistoryStore()
        let router = NotificationRouter()

        let coordinator = RefreshCoordinator(
            clock: clock,
            queryService: query,
            preferences: preferences,
            cache: cache,
            snapshots: snapshots,
            router: router,
            history: history,
            repositoriesProvider: { [GitPingsFixtures.publicRepo] },
            authenticatedLoginProvider: { GitPingsFixtures.account.login }
        )

        await coordinator.start()
        let afterStart = await query.fetchCount
        XCTAssertEqual(afterStart, 1)

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await coordinator.requestRefresh(reason: .manual) }
            group.addTask { await coordinator.requestRefresh(reason: .popoverOpen) }
            group.addTask { await coordinator.requestRefresh(reason: .dashboardOpen) }
        }

        let status = await coordinator.status()
        XCTAssertFalse(status.isRunning)
        XCTAssertEqual(status.pendingTriggerCount, 0)
        XCTAssertNotNil(status.lastSuccessAt)
        XCTAssertFalse(status.baselinePending)

        let fetchCount = await query.fetchCount
        // One in-flight cycle plus one coalesced follow-up — never one cycle per trigger.
        XCTAssertEqual(fetchCount - afterStart, 2)

        let events = try await history.recentEvents(limit: 50)
        XCTAssertTrue(events.isEmpty, "Identical post-baseline snapshots must not record history events")
    }

    func testConfigurationChangeReestablishesBaseline() async throws {
        let clock = ControllableClock(GitPingsFixtures.fixedNow)
        let query = CountingQueryService()
        let preferences = InMemoryPreferencesStore(
            selectedIDs: [GitPingsFixtures.publicRepo.id]
        )
        let cache = InMemoryPRCacheStore()
        let snapshots = InMemorySnapshotStore()
        let history = InMemoryTransitionHistoryStore()
        let router = NotificationRouter()

        let coordinator = RefreshCoordinator(
            clock: clock,
            queryService: query,
            preferences: preferences,
            cache: cache,
            snapshots: snapshots,
            router: router,
            history: history,
            repositoriesProvider: { [GitPingsFixtures.publicRepo] },
            authenticatedLoginProvider: { GitPingsFixtures.account.login }
        )

        await coordinator.start()
        // Mutate snapshot world then request config refresh (baseline).
        await query.setPullRequests([
            GitPingsFixtures.pullRequest(id: "PR_1", ci: .failing, merge: .conflicting),
        ])
        await coordinator.requestRefresh(reason: .configurationChanged)
        let events = try await history.recentEvents(limit: 50)
        XCTAssertTrue(events.isEmpty)
    }

    func testControllableClockDoesNotWallSleep() {
        let clock = ControllableClock(GitPingsFixtures.fixedNow)
        let before = clock.now()
        clock.advance(by: RefreshCoordinator.desiredInterval)
        XCTAssertEqual(clock.now().timeIntervalSince(before), RefreshCoordinator.desiredInterval)
    }
}

actor CountingQueryService: PullRequestQueryService {
    private(set) var fetchCount = 0
    private var prs: [PullRequestSummary] = GitPingsFixtures.sampleTrackedPRs

    func setPullRequests(_ prs: [PullRequestSummary]) {
        self.prs = prs
    }

    func fetchTrackedPullRequests(
        repositories: [RepositorySummary],
        filters: PRFilterConfiguration,
        authenticatedLogin: String
    ) async throws -> (prs: [PullRequestSummary], rateLimit: RateLimitSnapshot) {
        _ = repositories
        _ = filters
        _ = authenticatedLogin
        fetchCount += 1
        // Yield so concurrent refresh requests can enqueue while this cycle is in-flight.
        await Task.yield()
        return (prs, RateLimitSnapshot(remaining: 4_000, limit: 5_000))
    }

    func lookupPullRequest(id: GitHubNodeID) async throws -> PullRequestSummary? {
        prs.first(where: { $0.id == id })
    }
}
