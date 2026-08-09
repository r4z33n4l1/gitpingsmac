import XCTest
@testable import GitPings

final class PersistenceSchemaTests: XCTestCase {
    func testSchemaVersionIsV1() {
        XCTAssertEqual(PersistenceSchemaVersion.current, .v1)
        XCTAssertEqual(PersistenceSchemaVersion.current.rawValue, 1)
    }

    func testV1EntityListIsComplete() {
        let names = Set(PersistenceControllerSketch.v1EntityNames)
        XCTAssertEqual(names.count, 8)
        XCTAssertTrue(names.contains("PinRecord"))
        XCTAssertTrue(names.contains("NormalizedSnapshotRecord"))
        XCTAssertTrue(names.contains("TransitionHistoryRecord"))
        XCTAssertTrue(names.contains("AppSettingsRecord"))
    }

    func testPersistedPullRequestDraftRoundTripPreservesUnknown() throws {
        let original = GitPingsFixtures.pullRequest(id: "PR_4", ci: .unknown, merge: .unknown)
        let draft = PersistedPullRequestDraft(from: original)
        let restored = try XCTUnwrap(draft.asDomain())
        XCTAssertEqual(restored.ciState, .unknown)
        XCTAssertEqual(restored.mergeState, .unknown)
        XCTAssertNotEqual(restored.ciState, .passing)
        XCTAssertNotEqual(restored.mergeState, .mergeable)
    }

    func testTransitionHistoryRetentionBounds() {
        XCTAssertEqual(TransitionHistoryRetention.maximumEventCount, 100)
        XCTAssertEqual(TransitionHistoryRetention.maximumAge, 7 * 24 * 60 * 60)
    }

    func testMVPSettingsDefaultsMatchNotifyPolicy() {
        let settings = AppSettingsDraft.mvpDefaults(at: GitPingsFixtures.fixedNow)
        XCTAssertTrue(settings.notificationsMasterEnabled)
        XCTAssertTrue(settings.notifyCI)
        XCTAssertTrue(settings.notifyMerge)
        XCTAssertTrue(settings.notifyClosedOrMerged)
        XCTAssertTrue(settings.channelNotch)
        XCTAssertFalse(settings.channelSystem)
        XCTAssertFalse(settings.channelSound)
        XCTAssertEqual(settings.desiredRefreshIntervalSeconds, 60)
    }

    func testFixturesContainNoSecrets() throws {
        let roots = [
            fixturesRoot().appendingPathComponent("transitions", isDirectory: true),
            fixturesRoot().appendingPathComponent("pins", isDirectory: true),
        ]
        let forbidden = ["authorization", "access_token", "refresh_token", "device_code", "Bearer "]
        for root in roots {
            let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "json" {
                let text = String(decoding: try Data(contentsOf: file), as: UTF8.self)
                for token in forbidden {
                    XCTAssertFalse(
                        text.localizedCaseInsensitiveContains(token),
                        "Fixture \(file.lastPathComponent) unexpectedly contains \(token)"
                    )
                }
            }
        }
    }

    private func fixturesRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
    }
}
