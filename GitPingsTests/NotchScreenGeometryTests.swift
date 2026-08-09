import XCTest
@testable import GitPings

final class NotchScreenGeometryTests: XCTestCase {
    func testNotchlessDisplayUsesFallbackPill() {
        let metrics = ScreenTopMetrics(
            screenID: "external",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1055),
            safeAreaInsetsTop: 0
        )

        XCTAssertFalse(ScreenGeometry.hasTopObstruction(metrics))
        XCTAssertEqual(ScreenGeometry.presentationMode(for: metrics), .fallbackPill)

        let layout = ScreenGeometry.layout(for: metrics)
        XCTAssertEqual(layout?.mode, .fallbackPill)
        XCTAssertNil(layout?.reservedTopCenter)
        XCTAssertEqual(layout!.expandedFrame.midX, 960, accuracy: 0.5)
        XCTAssertLessThan(layout!.expandedFrame.maxY, metrics.visibleFrame.maxY)
    }

    func testNonzeroTopSafeAreaSelectsNotchAttached() {
        let metrics = ScreenTopMetrics(
            screenID: "builtin",
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 944),
            safeAreaInsetsTop: 32,
            auxiliaryTopLeftArea: CGRect(x: 0, y: 950, width: 620, height: 32),
            auxiliaryTopRightArea: CGRect(x: 892, y: 950, width: 620, height: 32)
        )

        XCTAssertTrue(ScreenGeometry.hasTopObstruction(metrics))
        XCTAssertEqual(ScreenGeometry.presentationMode(for: metrics), .notchAttached)

        let reserved = ScreenGeometry.reservedTopCenterBand(in: metrics)
        XCTAssertEqual(reserved!.minX, 620, accuracy: 0.5)
        XCTAssertEqual(reserved!.maxX, 892, accuracy: 0.5)

        let layout = ScreenGeometry.layout(for: metrics)
        XCTAssertEqual(layout?.mode, .notchAttached)
        XCTAssertNotNil(layout?.reservedTopCenter)
        // Expanded content must sit below the reserved housing band (NOTCH-10).
        XCTAssertLessThanOrEqual(layout!.expandedFrame.maxY, reserved!.minY + 0.5)
    }

    func testFallbackCanBeDisabled() {
        let metrics = ScreenTopMetrics(
            frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1280, height: 775)
        )
        XCTAssertNil(ScreenGeometry.layout(for: metrics, fallbackEnabled: false))
    }

    func testTransitionCopyUsesPublicPhrases() {
        let event = TransitionEvent(
            pullRequestID: GitHubNodeID("PR_1"),
            repositoryNameWithOwner: "acme-fixture/private-service",
            number: 9,
            title: "Normalize merge states",
            kind: .ciChanged,
            oldValue: CIState.pending.rawValue,
            newValue: CIState.passing.rawValue,
            observedAt: GitPingsFixtures.fixedNow
        )
        XCTAssertEqual(NotchEventPresentation.identityLine(for: event), "acme-fixture/private-service #9")
        XCTAssertEqual(NotchEventPresentation.transitionLine(for: event), "CI passed")

        var newPullRequestEvent = event
        newPullRequestEvent.kind = .newPullRequestAuthoredByMe
        newPullRequestEvent.oldValue = ""
        newPullRequestEvent.newValue = PullRequestLifecycleState.open.rawValue
        XCTAssertEqual(
            NotchEventPresentation.transitionLine(for: newPullRequestEvent),
            "New PR authored by you"
        )
    }
}
