import XCTest
@testable import GitPings

final class DomainContractTests: XCTestCase {
    func testCIStateUnknownIsDistinctFromPassing() {
        XCTAssertNotEqual(CIState.unknown, CIState.passing)
        XCTAssertTrue(CIState.allCases.contains(.unknown))
        XCTAssertTrue(CIState.allCases.contains(.noChecks))
    }

    func testMergeStateUnknownIsDistinctFromMergeable() {
        XCTAssertNotEqual(MergeState.unknown, MergeState.mergeable)
        XCTAssertTrue(MergeState.allCases.contains(.blocked))
        XCTAssertTrue(MergeState.allCases.contains(.checking))
    }

    func testPinPolicyEnforcesFive() {
        XCTAssertEqual(PinPolicy.maximumPinCount, 5)
        XCTAssertTrue(PinPolicy.canPin(currentCount: 4))
        XCTAssertFalse(PinPolicy.canPin(currentCount: 5))
    }

    func testMenuBarSeverityAttentionForFailingOrConflict() {
        let failing = GitPingsFixtures.pullRequest(ci: .failing, merge: .mergeable)
        XCTAssertEqual(MenuBarSeverityCalculator.severity(for: [failing]), .attention)

        let conflict = GitPingsFixtures.pullRequest(ci: .passing, merge: .conflicting)
        XCTAssertEqual(MenuBarSeverityCalculator.severity(for: [conflict]), .attention)
    }

    func testMenuBarSeverityHealthyOnlyWhenAllPassingAndMergeable() {
        let healthy = GitPingsFixtures.pullRequest(ci: .passing, merge: .mergeable)
        XCTAssertEqual(MenuBarSeverityCalculator.severity(for: [healthy]), .healthy)
        XCTAssertEqual(MenuBarSeverityCalculator.severity(for: []), .neutral)
    }

    func testRedactingLoggerRemovesSecrets() {
        let raw = "Authorization: Bearer abc.def.ghi access_token=secret device_code=ABCD"
        let redacted = RedactingLogger.redact(raw)
        XCTAssertFalse(redacted.contains("abc.def.ghi"))
        XCTAssertFalse(redacted.contains("secret"))
        XCTAssertFalse(redacted.contains("ABCD"))
        XCTAssertTrue(redacted.contains("[REDACTED]"))
    }

    func testFixturesContainNoPrivatePayloadMarkers() throws {
        let fixturesRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
        let sample = fixturesRoot
            .appendingPathComponent("github", isDirectory: true)
            .appendingPathComponent("sample_tracked_prs.json")
        let data = try Data(contentsOf: sample)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.localizedCaseInsensitiveContains("authorization"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("access_token"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("refresh_token"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("device_code"))
    }
}
