import Foundation

/// Decoding stubs for GraphQL envelopes. Fixtures must stay redacted — no tokens.
public struct GraphQLResponse<T: Decodable>: Decodable, Sendable where T: Sendable {
    public var data: T?
    public var errors: [GraphQLErrorDTO]?
}

public struct GraphQLErrorDTO: Decodable, Hashable, Sendable {
    public var message: String

    public var indicatesMissingNode: Bool {
        let normalized = message.lowercased()
        return normalized.contains("could not resolve to a node")
            && normalized.contains("global id")
    }
}

public struct RateLimitDTO: Decodable, Hashable, Sendable {
    public var limit: Int?
    public var remaining: Int?
    public var resetAt: String?
    public var cost: Int?

    public func asSnapshot(retryAfter: TimeInterval? = nil) -> RateLimitSnapshot {
        let reset: Date?
        if let resetAt {
            reset = ISO8601DateFormatter().date(from: resetAt)
        } else {
            reset = nil
        }
        return RateLimitSnapshot(
            remaining: remaining,
            limit: limit,
            resetAt: reset,
            retryAfter: retryAfter
        )
    }
}

public struct ViewerLoginDTO: Decodable, Hashable, Sendable {
    public var viewer: ViewerDTO
    public var rateLimit: RateLimitDTO?
}

public struct ViewerDTO: Decodable, Hashable, Sendable {
    public var id: String
    public var login: String
}

public struct PullRequestSearchDTO: Decodable, Sendable {
    public var search: SearchConnectionDTO
    public var rateLimit: RateLimitDTO?
}

public struct SearchConnectionDTO: Decodable, Sendable {
    public var pageInfo: PageInfoDTO
    public var nodes: [PullRequestNodeDTO?]
}

public struct PageInfoDTO: Decodable, Hashable, Sendable {
    public var hasNextPage: Bool
    public var endCursor: String?
}

public struct PullRequestNodeDTO: Decodable, Hashable, Sendable {
    public var id: String
    public var number: Int
    public var title: String
    public var url: URL
    public var state: String?
    public var merged: Bool?
    public var headRefName: String?
    public var baseRefName: String?
    public var updatedAt: String?
    public var mergeable: String?
    public var mergeStateStatus: String?
    public var author: AuthorDTO?
    public var repository: RepositoryDTO?
    public var commits: CommitConnectionDTO?

    public func asSummary(lastSuccessfulRefreshAt: Date?, isFreshMergeCalculation: Bool) -> PullRequestSummary? {
        guard let repository else { return nil }
        let rollup = commits?.nodes?.first?.commit?.statusCheckRollup
        let ci = GitHubStateMapping.ciState(
            rollupState: rollup?.state,
            contextCount: rollup?.contexts?.totalCount
        )
        let merge = GitHubStateMapping.mergeState(
            mergeable: mergeable,
            mergeStateStatus: mergeStateStatus,
            isFreshCalculation: isFreshMergeCalculation
        )
        let updated = updatedAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(timeIntervalSince1970: 0)

        return PullRequestSummary(
            id: GitHubNodeID(id),
            repositoryID: GitHubNodeID(repository.id),
            repositoryNameWithOwner: repository.nameWithOwner,
            number: number,
            title: title,
            url: url,
            authorLogin: author?.login ?? "",
            lifecycleState: GitHubStateMapping.lifecycleState(state: state, merged: merged),
            headRefName: headRefName ?? "",
            baseRefName: baseRefName ?? "",
            ciState: ci,
            mergeState: merge,
            updatedAt: updated,
            lastSuccessfulRefreshAt: lastSuccessfulRefreshAt
        )
    }
}

public struct AuthorDTO: Decodable, Hashable, Sendable {
    public var login: String
}

public struct RepositoryDTO: Decodable, Hashable, Sendable {
    public var id: String
    public var nameWithOwner: String
    public var isPrivate: Bool?
}

public struct CommitConnectionDTO: Decodable, Hashable, Sendable {
    public var nodes: [CommitNodeDTO]?
}

public struct CommitNodeDTO: Decodable, Hashable, Sendable {
    public var commit: CommitDTO?
}

public struct CommitDTO: Decodable, Hashable, Sendable {
    public var statusCheckRollup: StatusCheckRollupDTO?
}

public struct StatusCheckRollupDTO: Decodable, Hashable, Sendable {
    public var state: String?
    public var contexts: ContextCountDTO?
}

public struct ContextCountDTO: Decodable, Hashable, Sendable {
    public var totalCount: Int
}
