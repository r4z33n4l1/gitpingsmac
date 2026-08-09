import Foundation

/// Deterministic fixtures for UI, monitoring, and GitHub boundary tests.
/// Contains no tokens, authorization headers, device codes, or private payloads.
public enum GitPingsFixtures {
    public static let fixedNow = Date(timeIntervalSince1970: 1_786_291_200) // 2026-08-09T00:00:00Z

    public static let account = GitHubAccount(
        id: GitHubNodeID("ACCT_USER_1"),
        login: "octocat-fixture"
    )

    public static let publicRepo = RepositorySummary(
        id: GitHubNodeID("REPO_PUBLIC_1"),
        ownerLogin: "octocat-fixture",
        name: "public-demo",
        nameWithOwner: "octocat-fixture/public-demo",
        visibility: .public,
        isOrganizationOwned: false
    )

    public static let privateOrgRepo = RepositorySummary(
        id: GitHubNodeID("REPO_PRIVATE_ORG_1"),
        ownerLogin: "acme-fixture",
        name: "private-service",
        nameWithOwner: "acme-fixture/private-service",
        visibility: .private,
        isOrganizationOwned: true
    )

    public static func pullRequest(
        id: String = "PR_1",
        repository: RepositorySummary = publicRepo,
        number: Int = 42,
        title: String = "Fixture PR",
        author: String = "octocat-fixture",
        ci: CIState = .passing,
        merge: MergeState = .mergeable,
        lifecycle: PullRequestLifecycleState = .open
    ) -> PullRequestSummary {
        PullRequestSummary(
            id: GitHubNodeID(id),
            repositoryID: repository.id,
            repositoryNameWithOwner: repository.nameWithOwner,
            number: number,
            title: title,
            url: URL(string: "https://github.com/\(repository.nameWithOwner)/pull/\(number)")!,
            authorLogin: author,
            lifecycleState: lifecycle,
            headRefName: "feature/fixture",
            baseRefName: "main",
            ciState: ci,
            mergeState: merge,
            updatedAt: fixedNow.addingTimeInterval(-3600),
            lastSuccessfulRefreshAt: fixedNow
        )
    }

    public static let sampleTrackedPRs: [PullRequestSummary] = [
        pullRequest(id: "PR_1", number: 42, title: "Add menu bar status", ci: .passing, merge: .mergeable),
        pullRequest(
            id: "PR_2",
            repository: privateOrgRepo,
            number: 7,
            title: "Wire device flow",
            author: "agent-fixture",
            ci: .pending,
            merge: .checking
        ),
        pullRequest(
            id: "PR_3",
            repository: privateOrgRepo,
            number: 9,
            title: "Normalize merge states",
            ci: .failing,
            merge: .conflicting
        ),
        pullRequest(id: "PR_4", number: 11, title: "Unknown CI sample", ci: .unknown, merge: .unknown),
        pullRequest(id: "PR_5", number: 12, title: "Blocked merge sample", ci: .passing, merge: .blocked),
    ]

    public static let defaultFilters = PRFilterConfiguration.mvpDefault
}
