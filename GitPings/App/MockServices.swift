import Foundation

actor MockAuthService: AuthService {
    private var state: AuthSessionState = .signedOut

    func currentSession() async -> AuthSessionState { state }

    func beginDeviceFlow() async throws -> AuthSessionState {
        state = .deviceFlowPending(
            userCode: "XXXX-MOCK",
            verificationURL: URL(string: "https://github.com/login/device")!
        )
        return state
    }

    func pollDeviceFlow() async throws -> AuthSessionState {
        state = .signedIn(GitPingsFixtures.account)
        return state
    }

    func cancelDeviceFlow() async {
        state = .signedOut
    }

    func signOut() async throws {
        state = .signedOut
    }

    func refreshAccessTokenIfNeeded() async throws {}
}

actor MockRepositoryCatalogService: RepositoryCatalogService {
    func listInstallableRepositories() async throws -> [RepositorySummary] {
        [GitPingsFixtures.publicRepo, GitPingsFixtures.privateOrgRepo]
    }
}

actor MockPullRequestQueryService: PullRequestQueryService {
    func fetchTrackedPullRequests(
        repositories: [RepositorySummary],
        filters: PRFilterConfiguration,
        authenticatedLogin: String
    ) async throws -> (prs: [PullRequestSummary], rateLimit: RateLimitSnapshot) {
        _ = repositories
        _ = filters
        _ = authenticatedLogin
        return (GitPingsFixtures.sampleTrackedPRs, RateLimitSnapshot(remaining: 4_500, limit: 5_000))
    }

    func lookupPullRequest(id: GitHubNodeID) async throws -> PullRequestSummary? {
        GitPingsFixtures.sampleTrackedPRs.first(where: { $0.id == id })
    }
}

actor MockKeychainTokenStore: KeychainTokenStore {
    private var storage: [String: (String, String?)] = [:]

    func loadTokens(for accountID: GitHubNodeID) async throws -> (accessToken: String, refreshToken: String?)? {
        storage[accountID.rawValue]
    }

    func saveTokens(accountID: GitHubNodeID, accessToken: String, refreshToken: String?) async throws {
        storage[accountID.rawValue] = (accessToken, refreshToken)
    }

    func deleteTokens(for accountID: GitHubNodeID) async throws {
        storage.removeValue(forKey: accountID.rawValue)
    }

    func deleteAllTokens() async throws {
        storage.removeAll()
    }
}
