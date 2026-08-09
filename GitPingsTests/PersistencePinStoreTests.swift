import XCTest
@testable import GitPings

final class PersistencePinStoreTests: XCTestCase {
    func testPinLimitRejectsSixthWithoutSilentEviction() async throws {
        let store = InMemoryPinStore(initial: [
            GitHubNodeID("PR_1"),
            GitHubNodeID("PR_2"),
            GitHubNodeID("PR_3"),
            GitHubNodeID("PR_4"),
            GitHubNodeID("PR_5"),
        ])

        do {
            try await store.pin(GitHubNodeID("PR_6"))
            XCTFail("Expected pinLimitReached")
        } catch let error as GitPingsError {
            XCTAssertEqual(error, .pinLimitReached)
        }

        let pins = try await store.pinnedIDs()
        XCTAssertEqual(pins.map(\.rawValue), ["PR_1", "PR_2", "PR_3", "PR_4", "PR_5"])
    }

    func testExplicitReplacementPreservesSlot() async throws {
        let store = InMemoryPinStore(initial: [
            GitHubNodeID("PR_1"),
            GitHubNodeID("PR_2"),
            GitHubNodeID("PR_3"),
            GitHubNodeID("PR_4"),
            GitHubNodeID("PR_5"),
        ])
        try await store.replace(existing: GitHubNodeID("PR_1"), with: GitHubNodeID("PR_6"))
        let pins = try await store.pinnedIDs()
        XCTAssertEqual(pins.map(\.rawValue), ["PR_6", "PR_2", "PR_3", "PR_4", "PR_5"])
    }

    func testNewPinsAppendLast() async throws {
        let store = InMemoryPinStore()
        try await store.pin(GitHubNodeID("PR_1"))
        try await store.pin(GitHubNodeID("PR_2"))
        try await store.pin(GitHubNodeID("PR_3"))
        let pins = try await store.pinnedIDs()
        XCTAssertEqual(pins.map(\.rawValue), ["PR_1", "PR_2", "PR_3"])
    }

    func testReorderRequiresExactSet() async throws {
        let store = InMemoryPinStore(initial: [GitHubNodeID("PR_1"), GitHubNodeID("PR_2")])
        do {
            try await store.reorder(to: [GitHubNodeID("PR_1"), GitHubNodeID("PR_3")])
            XCTFail("Expected unsupportedConfiguration")
        } catch let error as GitPingsError {
            guard case .unsupportedConfiguration = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testPinLimitFixtureMatchesPolicy() throws {
        let url = fixturesRoot()
            .appendingPathComponent("pins", isDirectory: true)
            .appendingPathComponent("pin_limit.json")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["maximumPinCount"] as? Int, PinPolicy.maximumPinCount)
        XCTAssertEqual(json?["silentEvictionAllowed"] as? Bool, false)
    }

    private func fixturesRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
    }
}
