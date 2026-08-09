import Foundation

public actor InMemoryPRCacheStore: PRCacheStore {
    private var cache: [PullRequestSummary] = []
    private var lastSuccess: Date?

    public init(cache: [PullRequestSummary] = [], lastSuccess: Date? = nil) {
        self.cache = cache
        self.lastSuccess = lastSuccess
    }

    public func cachedPullRequests() async throws -> [PullRequestSummary] {
        cache
    }

    public func replaceCache(with prs: [PullRequestSummary], refreshedAt: Date) async throws {
        cache = prs
        lastSuccess = refreshedAt
    }

    public func lastSuccessfulRefreshAt() async throws -> Date? {
        lastSuccess
    }

    public func purgePrivateGitHubData() async throws {
        cache = []
        lastSuccess = nil
    }
}
