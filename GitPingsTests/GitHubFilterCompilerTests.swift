import XCTest
@testable import GitPings

final class GitHubFilterCompilerTests: XCTestCase {
    private let login = "octocat-fixture"
    private let repos = [GitPingsFixtures.publicRepo, GitPingsFixtures.privateOrgRepo]

    func testCompileProducesSeparateQueriesForORFilters() {
        let filters = PRFilterConfiguration(
            includeAllOpen: false,
            includeAuthoredByMe: true,
            includeAssignedToMe: true,
            includeReviewRequestedFromMe: true
        )
        let queries = FilterQueryCompiler.compile(
            filters: filters,
            authenticatedLogin: login,
            repositories: repos
        )
        XCTAssertEqual(queries.count, 3)
        XCTAssertEqual(
            Set(queries.map(\.dimension)),
            [.authoredByMe, .assignedToMe, .reviewRequestedFromMe]
        )
        XCTAssertTrue(queries.allSatisfy { $0.query.contains("is:pr") && $0.query.contains("is:open") })
        XCTAssertTrue(queries.contains { $0.query.contains("author:octocat-fixture") })
        XCTAssertTrue(queries.contains { $0.query.contains("assignee:octocat-fixture") })
        XCTAssertTrue(queries.contains { $0.query.contains("review-requested:octocat-fixture") })
        for query in queries {
            XCTAssertTrue(query.query.contains("repo:octocat-fixture/public-demo"))
            XCTAssertTrue(query.query.contains("repo:acme-fixture/private-service"))
        }
    }

    func testIncludeAllOpenSkipsActorScopedQueries() {
        let filters = PRFilterConfiguration(
            includeAllOpen: true,
            includeAuthoredByMe: true,
            includeAssignedToMe: true,
            includeReviewRequestedFromMe: true
        )
        let queries = FilterQueryCompiler.compile(
            filters: filters,
            authenticatedLogin: login,
            repositories: repos
        )
        XCTAssertEqual(queries.count, 1)
        XCTAssertEqual(queries[0].dimension, .allOpen)
        XCTAssertFalse(queries[0].query.contains("author:"))
        XCTAssertFalse(queries[0].query.contains("assignee:"))
        XCTAssertFalse(queries[0].query.contains("review-requested:"))
    }

    func testEmptyLoginOrReposYieldsNoQueries() {
        XCTAssertTrue(
            FilterQueryCompiler.compile(
                filters: .mvpDefault,
                authenticatedLogin: "  ",
                repositories: repos
            ).isEmpty
        )
        XCTAssertTrue(
            FilterQueryCompiler.compile(
                filters: .mvpDefault,
                authenticatedLogin: login,
                repositories: []
            ).isEmpty
        )
    }

    func testRepositorySharding() {
        let many = (0..<45).map { index in
            RepositorySummary(
                id: GitHubNodeID("REPO_\(index)"),
                ownerLogin: "org",
                name: "repo-\(index)",
                nameWithOwner: "org/repo-\(index)",
                visibility: .public,
                isOrganizationOwned: true
            )
        }
        let queries = FilterQueryCompiler.compile(
            filters: PRFilterConfiguration(
                includeAllOpen: true,
                includeAuthoredByMe: false,
                includeAssignedToMe: false,
                includeReviewRequestedFromMe: false
            ),
            authenticatedLogin: login,
            repositories: many,
            repositoriesPerShard: 20
        )
        XCTAssertEqual(queries.count, 3)
        XCTAssertEqual(Set(queries.map(\.repositoryShardIndex)), [0, 1, 2])
    }

    func testUnknownCIRollupNeverMapsToPassing() {
        XCTAssertEqual(
            GitHubStateMapping.ciState(rollupState: nil, contextCount: nil),
            .unknown
        )
        XCTAssertEqual(
            GitHubStateMapping.ciState(rollupState: "TOTALLY_NEW_STATE", contextCount: 1),
            .unknown
        )
        XCTAssertNotEqual(
            GitHubStateMapping.ciState(rollupState: "TOTALLY_NEW_STATE", contextCount: 1),
            .passing
        )
        XCTAssertEqual(
            GitHubStateMapping.ciState(rollupState: nil, contextCount: 0),
            .noChecks
        )
        XCTAssertEqual(
            GitHubStateMapping.ciState(rollupState: "SUCCESS", contextCount: 2),
            .passing
        )
        XCTAssertEqual(
            GitHubStateMapping.ciState(rollupState: "FAILURE", contextCount: 2),
            .failing
        )
    }

    func testUnknownMergeNeverMapsToMergeable() {
        XCTAssertEqual(
            GitHubStateMapping.mergeState(
                mergeable: nil,
                mergeStateStatus: nil,
                isFreshCalculation: true
            ),
            .unknown
        )
        XCTAssertEqual(
            GitHubStateMapping.mergeState(
                mergeable: "SOMETHING_NEW",
                mergeStateStatus: "CLEAN",
                isFreshCalculation: true
            ),
            .unknown
        )
        XCTAssertEqual(
            GitHubStateMapping.mergeState(
                mergeable: "UNKNOWN",
                mergeStateStatus: "UNKNOWN",
                isFreshCalculation: true
            ),
            .checking
        )
        XCTAssertEqual(
            GitHubStateMapping.mergeState(
                mergeable: "UNKNOWN",
                mergeStateStatus: "UNKNOWN",
                isFreshCalculation: false
            ),
            .unknown
        )
        XCTAssertEqual(
            GitHubStateMapping.mergeState(
                mergeable: "MERGEABLE",
                mergeStateStatus: "BLOCKED",
                isFreshCalculation: true
            ),
            .blocked
        )
        XCTAssertEqual(
            GitHubStateMapping.mergeState(
                mergeable: "CONFLICTING",
                mergeStateStatus: "DIRTY",
                isFreshCalculation: true
            ),
            .conflicting
        )
        XCTAssertNotEqual(
            GitHubStateMapping.mergeState(
                mergeable: "SOMETHING_NEW",
                mergeStateStatus: nil,
                isFreshCalculation: true
            ),
            .mergeable
        )
    }

    func testFixturesContainNoSecretMarkers() throws {
        let fixturesRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/github", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(
            at: fixturesRoot,
            includingPropertiesForKeys: nil
        )
        XCTAssertFalse(files.isEmpty)
        for file in files where file.pathExtension == "json" {
            let text = String(decoding: try Data(contentsOf: file), as: UTF8.self)
            XCTAssertFalse(text.localizedCaseInsensitiveContains("authorization:"), file.lastPathComponent)
            XCTAssertFalse(text.contains("ghp_"), file.lastPathComponent)
            XCTAssertFalse(text.contains("gho_"), file.lastPathComponent)
            XCTAssertFalse(text.contains("ghu_"), file.lastPathComponent)
            // Placeholder redaction is required when token keys appear in schema samples.
            if text.localizedCaseInsensitiveContains("access_token") {
                XCTAssertTrue(text.contains("[REDACTED]"), file.lastPathComponent)
            }
            if text.localizedCaseInsensitiveContains("device_code") {
                XCTAssertTrue(text.contains("[REDACTED]"), file.lastPathComponent)
            }
        }
    }

    func testPermissionManifestIsReadOnly() throws {
        let manifestURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("GitPings/Infrastructure/GitHub/permission-manifest.json")
        let data = try Data(contentsOf: manifestURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let perms = try XCTUnwrap(json["repositoryPermissions"] as? [String: String])
        XCTAssertFalse(perms.isEmpty)
        for (_, access) in perms {
            XCTAssertEqual(access, "read")
        }
        let app = try XCTUnwrap(json["githubApp"] as? [String: Any])
        XCTAssertEqual(app["shipsClientSecret"] as? Bool, false)
        XCTAssertEqual(app["shipsPrivateKey"] as? Bool, false)
        XCTAssertEqual(app["callbackURLRequired"] as? Bool, false)
    }
}
