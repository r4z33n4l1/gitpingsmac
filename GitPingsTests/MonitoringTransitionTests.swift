import XCTest
@testable import GitPings

final class MonitoringTransitionTests: XCTestCase {
    private let detector = TransitionDetector()
    private let now = GitPingsFixtures.fixedNow

    func testBaselineModeEmitsNoEvents() {
        let previous: [GitHubNodeID: PullRequestSummary] = [:]
        let current = GitPingsFixtures.sampleTrackedPRs
        let events = detector.detectTransitions(
            previous: previous,
            current: current,
            baselineMode: true,
            observedAt: now
        )
        XCTAssertEqual(events.count, 0)
    }

    func testBaselineFixtureExpectsZeroEvents() throws {
        let url = fixturesRoot()
            .appendingPathComponent("transitions", isDirectory: true)
            .appendingPathComponent("baseline_no_events.json")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["baselineMode"] as? Bool, true)
        XCTAssertEqual(json?["expectedEventCount"] as? Int, 0)
    }

    func testCIChangeEmitsSingleEvent() {
        let prior = GitPingsFixtures.pullRequest(id: "PR_1", ci: .pending, merge: .mergeable)
        let next = GitPingsFixtures.pullRequest(id: "PR_1", ci: .passing, merge: .mergeable)
        let events = detector.detectTransitions(
            previous: [prior.id: prior],
            current: [next],
            baselineMode: false,
            observedAt: now
        )
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .ciChanged)
        XCTAssertEqual(events[0].oldValue, CIState.pending.rawValue)
        XCTAssertEqual(events[0].newValue, CIState.passing.rawValue)
    }

    func testIdenticalSnapshotsEmitNothing() {
        let pr = GitPingsFixtures.pullRequest(id: "PR_1", ci: .passing, merge: .mergeable)
        let events = detector.detectTransitions(
            previous: [pr.id: pr],
            current: [pr],
            baselineMode: false,
            observedAt: now
        )
        XCTAssertTrue(events.isEmpty)
    }

    func testAbsenceFromCurrentDoesNotEmitClosed() {
        let prior = GitPingsFixtures.pullRequest(id: "PR_1", lifecycle: .open)
        let events = detector.detectTransitions(
            previous: [prior.id: prior],
            current: [],
            baselineMode: false,
            observedAt: now
        )
        XCTAssertTrue(events.isEmpty)
        XCTAssertFalse(events.contains(where: { $0.kind == .closedOrMerged }))
    }

    func testVerifiedMergedAfterLookupEmitsClosedOrMerged() {
        let prior = GitPingsFixtures.pullRequest(id: "PR_1", lifecycle: .open)
        let merged = GitPingsFixtures.pullRequest(id: "PR_1", lifecycle: .merged)
        let events = detector.detectTransitions(
            previous: [prior.id: prior],
            current: [merged],
            baselineMode: false,
            observedAt: now
        )
        XCTAssertEqual(events.map(\.kind), [.closedOrMerged])
        XCTAssertEqual(events[0].newValue, PullRequestLifecycleState.merged.rawValue)
    }

    func testSameCycleCIAndMergeChangesCoalescePerPR() {
        let prior = GitPingsFixtures.pullRequest(id: "PR_1", ci: .pending, merge: .checking)
        let next = GitPingsFixtures.pullRequest(id: "PR_1", ci: .passing, merge: .mergeable)
        let events = detector.detectTransitions(
            previous: [prior.id: prior],
            current: [next],
            baselineMode: false,
            observedAt: now
        )
        XCTAssertEqual(Set(events.map(\.kind)), [.ciChanged, .mergeChanged])
        let groups = TransitionCoalescing.groupByPullRequest(events)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].count, 2)
    }

    func testUnknownNeverEqualsPassingOrMergeable() {
        XCTAssertNotEqual(CIState.unknown, CIState.passing)
        XCTAssertNotEqual(MergeState.unknown, MergeState.mergeable)

        let unknown = GitPingsFixtures.pullRequest(id: "PR_4", ci: .unknown, merge: .unknown)
        XCTAssertNotEqual(MenuBarSeverityCalculator.severity(for: [unknown]), .healthy)
        XCTAssertEqual(MenuBarSeverityCalculator.severity(for: [unknown]), .inProgress)
    }

    func testUnknownToPassingIsExplicitTransitionNotImplicitSuccessMapping() {
        let prior = GitPingsFixtures.pullRequest(id: "PR_4", ci: .unknown, merge: .unknown)
        let next = GitPingsFixtures.pullRequest(id: "PR_4", ci: .passing, merge: .unknown)
        let events = detector.detectTransitions(
            previous: [prior.id: prior],
            current: [next],
            baselineMode: false,
            observedAt: now
        )
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].oldValue, CIState.unknown.rawValue)
        XCTAssertEqual(events[0].newValue, CIState.passing.rawValue)
    }

    func testRawCheckNoiseWithSameNormalizedCIDoesNotNotify() {
        // Detector only sees normalized states; identical CI means no event (CHANGE-4).
        let prior = GitPingsFixtures.pullRequest(id: "PR_1", ci: .pending, merge: .mergeable)
        let next = GitPingsFixtures.pullRequest(id: "PR_1", ci: .pending, merge: .mergeable)
        let events = detector.detectTransitions(
            previous: [prior.id: prior],
            current: [next],
            baselineMode: false,
            observedAt: now
        )
        XCTAssertTrue(events.isEmpty)
    }

    func testNewlyAppearingPRAfterBaselineEmitsNothing() {
        let prior = GitPingsFixtures.pullRequest(id: "PR_1")
        let newPR = GitPingsFixtures.pullRequest(id: "PR_9", number: 99, title: "Newly included")
        let events = detector.detectTransitions(
            previous: [prior.id: prior],
            current: [prior, newPR],
            baselineMode: false,
            observedAt: now
        )
        XCTAssertTrue(events.isEmpty)
    }

    func testNewAuthoredPullRequestAfterBaselineEmitsEvent() {
        let prior = GitPingsFixtures.pullRequest(id: "PR_1")
        let newPR = GitPingsFixtures.pullRequest(
            id: "PR_9",
            number: 99,
            title: "Agent-authored follow-up",
            author: "OCTOCAT-FIXTURE"
        )
        let events = detector.detectNewAuthoredPullRequests(
            previouslyObserved: [prior.id: prior],
            current: [prior, newPR],
            authenticatedLogin: "octocat-fixture",
            baselineMode: false,
            observedAt: now
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .newPullRequestAuthoredByMe)
        XCTAssertEqual(events[0].pullRequestID, newPR.id)
        XCTAssertEqual(events[0].newValue, PullRequestLifecycleState.open.rawValue)
    }

    func testNewAuthoredPullRequestBaselineAndOtherAuthorsStaySilent() {
        let mine = GitPingsFixtures.pullRequest(id: "PR_MINE", author: "octocat-fixture")
        let theirs = GitPingsFixtures.pullRequest(id: "PR_THEIRS", author: "agent-fixture")

        XCTAssertTrue(detector.detectNewAuthoredPullRequests(
            previouslyObserved: [:],
            current: [mine],
            authenticatedLogin: "octocat-fixture",
            baselineMode: true,
            observedAt: now
        ).isEmpty)
        XCTAssertTrue(detector.detectNewAuthoredPullRequests(
            previouslyObserved: [:],
            current: [theirs],
            authenticatedLogin: "octocat-fixture",
            baselineMode: false,
            observedAt: now
        ).isEmpty)
    }

    func testPreviouslyObservedAuthoredPullRequestDoesNotRepeat() {
        let mine = GitPingsFixtures.pullRequest(id: "PR_MINE", author: "octocat-fixture")
        let events = detector.detectNewAuthoredPullRequests(
            previouslyObserved: [mine.id: mine],
            current: [mine],
            authenticatedLogin: "octocat-fixture",
            baselineMode: false,
            observedAt: now
        )
        XCTAssertTrue(events.isEmpty)
    }

    private func fixturesRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
    }
}
