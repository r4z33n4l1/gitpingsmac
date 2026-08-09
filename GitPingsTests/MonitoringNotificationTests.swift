import XCTest
@testable import GitPings

final class MonitoringNotificationTests: XCTestCase {
    func testTestNotificationDoesNotEnterHistory() async throws {
        let history = InMemoryTransitionHistoryStore()
        let router = NotificationRouter(
            preferences: .mvpTesting,
            history: history
        )

        await router.sendTestNotification(channel: .notch)
        await router.sendTestNotification(channel: .sound)

        let count = await history.count()
        XCTAssertEqual(count, 0)

        let testCount = await router.testDeliveryCount
        XCTAssertEqual(testCount, 2)
    }

    func testDisabledEventKindIsNotRouted() async throws {
        var prefs = NotificationPreferences.mvpTesting
        prefs.ciEnabled = false
        let router = NotificationRouter(preferences: prefs)

        let event = TransitionEvent(
            pullRequestID: GitHubNodeID("PR_1"),
            repositoryNameWithOwner: "octocat-fixture/public-demo",
            number: 42,
            title: "CI flip",
            kind: .ciChanged,
            oldValue: CIState.pending.rawValue,
            newValue: CIState.failing.rawValue,
            observedAt: GitPingsFixtures.fixedNow
        )
        await router.route(events: [event])
        let delivered = await router.delivered
        XCTAssertTrue(delivered.isEmpty)
    }

    func testNewAuthoredPullRequestIsRoutedByDefault() async {
        let router = NotificationRouter(preferences: .mvpTesting)
        let event = TransitionEvent(
            pullRequestID: GitHubNodeID("PR_NEW"),
            repositoryNameWithOwner: "octocat-fixture/public-demo",
            number: 101,
            title: "New agent PR",
            kind: .newPullRequestAuthoredByMe,
            oldValue: "",
            newValue: PullRequestLifecycleState.open.rawValue,
            observedAt: GitPingsFixtures.fixedNow
        )

        await router.route(events: [event])
        let delivered = await router.delivered
        XCTAssertEqual(delivered.count, 1)
        XCTAssertEqual(delivered[0].channel, .notch)
        XCTAssertEqual(delivered[0].events.first?.kind, .newPullRequestAuthoredByMe)
    }

    func testChannelTogglesGateDelivery() async throws {
        var prefs = NotificationPreferences.mvpTesting
        prefs.notchEnabled = false
        prefs.systemEnabled = false
        prefs.soundEnabled = true
        let router = NotificationRouter(preferences: prefs)

        let event = TransitionEvent(
            pullRequestID: GitHubNodeID("PR_1"),
            repositoryNameWithOwner: "octocat-fixture/public-demo",
            number: 42,
            title: "Merge flip",
            kind: .mergeChanged,
            oldValue: MergeState.checking.rawValue,
            newValue: MergeState.mergeable.rawValue,
            observedAt: GitPingsFixtures.fixedNow
        )
        await router.route(events: [event])
        let delivered = await router.delivered
        XCTAssertEqual(delivered.count, 1)
        XCTAssertEqual(delivered[0].channel, .sound)
        XCTAssertFalse(delivered[0].isTest)
    }

    func testMasterToggleDisablesAllChannels() async throws {
        var prefs = NotificationPreferences.mvpTesting
        prefs.masterEnabled = false
        let router = NotificationRouter(preferences: prefs)
        let event = TransitionEvent(
            pullRequestID: GitHubNodeID("PR_1"),
            repositoryNameWithOwner: "octocat-fixture/public-demo",
            number: 1,
            title: "x",
            kind: .ciChanged,
            oldValue: "pending",
            newValue: "passing",
            observedAt: GitPingsFixtures.fixedNow
        )
        await router.route(events: [event])
        let delivered = await router.delivered
        XCTAssertTrue(delivered.isEmpty)
    }

    func testSignOutPurgeClearsCachePinsAndHistory() async throws {
        let clock = FixedClock(GitPingsFixtures.fixedNow)
        let preferences = InMemoryPreferencesStore(
            selectedIDs: [GitPingsFixtures.publicRepo.id]
        )
        let pins = InMemoryPinStore(initial: [GitHubNodeID("PR_1")])
        let cache = InMemoryPRCacheStore(
            cache: GitPingsFixtures.sampleTrackedPRs,
            lastSuccess: GitPingsFixtures.fixedNow
        )
        let snapshots = InMemorySnapshotStore(
            snapshots: [GitHubNodeID("PR_1"): GitPingsFixtures.pullRequest()]
        )
        let history = InMemoryTransitionHistoryStore(events: [
            TransitionEvent(
                pullRequestID: GitHubNodeID("PR_1"),
                repositoryNameWithOwner: "octocat-fixture/public-demo",
                number: 42,
                title: "past",
                kind: .ciChanged,
                oldValue: "pending",
                newValue: "passing",
                observedAt: GitPingsFixtures.fixedNow
            ),
        ])
        let settings = InMemoryAppSettingsStore(clock: clock)
        let purger = LocalDataPurger(
            preferences: preferences,
            pins: pins,
            cache: cache,
            snapshots: snapshots,
            history: history,
            settingsStore: settings
        )

        try await purger.purge(clock: clock)

        let pinnedIDs = try await pins.pinnedIDs()
        let cachedPullRequests = try await cache.cachedPullRequests()
        let normalizedSnapshots = try await snapshots.lastNormalizedSnapshots()
        let historyCount = await history.count()
        let selectedRepositoryIDs = try await preferences.selectedRepositoryIDs()

        XCTAssertTrue(pinnedIDs.isEmpty)
        XCTAssertTrue(cachedPullRequests.isEmpty)
        XCTAssertTrue(normalizedSnapshots.isEmpty)
        XCTAssertEqual(historyCount, 0)
        XCTAssertTrue(selectedRepositoryIDs.isEmpty)
    }
}
