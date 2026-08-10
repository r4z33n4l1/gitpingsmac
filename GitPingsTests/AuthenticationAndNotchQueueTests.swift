import XCTest
@testable import GitPings

final class AuthenticationAndNotchQueueTests: XCTestCase {
    func testLiveGitHubCLITransportWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["GITPINGS_RUN_LIVE_GH_TEST"] == "1" else {
            throw XCTSkip("Set GITPINGS_RUN_LIVE_GH_TEST=1 for the local GitHub CLI smoke test")
        }

        let service = LiveGitHubService()
        await service.configureAuthenticationMethod(.githubCLI)
        let account = try await service.restoreSession()
        let repositories = try await service.listRepositories()

        XCTAssertFalse(account?.login.isEmpty ?? true)
        XCTAssertFalse(repositories.isEmpty)
        XCTAssertTrue(repositories.contains { $0.visibility == .private })
    }

    func testGitHubCLILocatorIncludesPATHAndHomebrewLocationsWithoutDuplicates() {
        let candidates = GitHubCLIExecutableLocator.candidates(
            pathEnvironment: "/custom/bin:/opt/homebrew/bin:/custom/bin"
        ).map(\.path)

        XCTAssertEqual(candidates.first, "/custom/bin/gh")
        XCTAssertTrue(candidates.contains("/opt/homebrew/bin/gh"))
        XCTAssertTrue(candidates.contains("/usr/local/bin/gh"))
        XCTAssertEqual(Set(candidates).count, candidates.count)
    }

    func testNotchQueueKeepsDistinctPullRequestsInArrivalOrder() {
        var queue = NotchEventQueue()
        let first = event(prID: "PR_1", number: 1, kind: .ciChanged, value: CIState.passing.rawValue)
        let second = event(prID: "PR_2", number: 2, kind: .mergeChanged, value: MergeState.blocked.rawValue)

        queue.enqueue([first, second])

        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue.popFirst()?.map(\.pullRequestID), [first.pullRequestID])
        XCTAssertEqual(queue.popFirst()?.map(\.pullRequestID), [second.pullRequestID])
        XCTAssertTrue(queue.isEmpty)
    }

    func testNotchQueueCoalescesSamePullRequestAndDeduplicatesSameTransition() {
        var queue = NotchEventQueue()
        let ci = event(prID: "PR_1", number: 1, kind: .ciChanged, value: CIState.passing.rawValue)
        let merge = event(prID: "PR_1", number: 1, kind: .mergeChanged, value: MergeState.mergeable.rawValue)
        let duplicateCI = event(prID: "PR_1", number: 1, kind: .ciChanged, value: CIState.passing.rawValue)

        queue.enqueue([ci, merge, duplicateCI])

        XCTAssertEqual(queue.count, 1)
        let group = queue.popFirst()
        XCTAssertEqual(group?.count, 2)
        XCTAssertEqual(group?.map(\.kind), [.ciChanged, .mergeChanged])
        XCTAssertEqual(
            group.map(NotchEventPresentation.transitionLine(for:)),
            "CI passed · Mergeable"
        )
    }

    func testNotchQueueDoesNotRequeueVisibleTransition() {
        var queue = NotchEventQueue()
        let visible = event(prID: "PR_1", number: 1, kind: .ciChanged, value: CIState.failing.rawValue)

        queue.enqueue([visible], excluding: [visible])

        XCTAssertTrue(queue.isEmpty)
    }

    private func event(
        prID: String,
        number: Int,
        kind: TransitionEventKind,
        value: String
    ) -> TransitionEvent {
        TransitionEvent(
            pullRequestID: GitHubNodeID(prID),
            repositoryNameWithOwner: "octocat/repo",
            number: number,
            title: "Pull request \(number)",
            kind: kind,
            oldValue: "old",
            newValue: value,
            observedAt: GitPingsFixtures.fixedNow
        )
    }
}
