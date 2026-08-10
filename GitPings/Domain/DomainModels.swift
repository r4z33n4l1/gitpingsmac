import Foundation

/// Stable GitHub GraphQL global node identifier.
public struct GitHubNodeID: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct GitHubAccount: Hashable, Sendable, Codable {
    public var id: GitHubNodeID
    public var login: String

    public init(id: GitHubNodeID, login: String) {
        self.id = id
        self.login = login
    }
}

/// The credential source GitPings uses for GitHub API requests.
///
/// GitHub CLI mode never asks `gh` to reveal its token. GitPings executes
/// read-only `gh api graphql` queries and consumes only the JSON response.
public enum GitHubAuthenticationMethod: String, Hashable, Sendable, Codable, CaseIterable, Identifiable {
    case githubCLI
    case githubApp

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .githubCLI: "Local GitHub CLI"
        case .githubApp: "GitNotary GitHub App"
        }
    }
}

public enum RepositoryVisibility: String, Hashable, Sendable, Codable {
    case `public`
    case `private`
    case unknown
}

public struct RepositorySummary: Hashable, Sendable, Codable, Identifiable {
    public var id: GitHubNodeID
    public var ownerLogin: String
    public var name: String
    public var nameWithOwner: String
    public var visibility: RepositoryVisibility
    public var isOrganizationOwned: Bool

    public init(
        id: GitHubNodeID,
        ownerLogin: String,
        name: String,
        nameWithOwner: String,
        visibility: RepositoryVisibility,
        isOrganizationOwned: Bool
    ) {
        self.id = id
        self.ownerLogin = ownerLogin
        self.name = name
        self.nameWithOwner = nameWithOwner
        self.visibility = visibility
        self.isOrganizationOwned = isOrganizationOwned
    }
}

/// Normalized CI rollup. Unknown/missing GitHub data never maps to passing.
public enum CIState: String, Hashable, Sendable, Codable, CaseIterable {
    case passing
    case pending
    case failing
    case noChecks
    case unknown
}

/// Normalized mergeability. Unknown/missing GitHub data never maps to mergeable.
public enum MergeState: String, Hashable, Sendable, Codable, CaseIterable {
    case mergeable
    case blocked
    case conflicting
    case checking
    case unknown
}

public enum PullRequestLifecycleState: String, Hashable, Sendable, Codable {
    case open
    case closed
    case merged
    case unknown
}

public struct PullRequestSummary: Hashable, Sendable, Codable, Identifiable {
    public var id: GitHubNodeID
    public var repositoryID: GitHubNodeID
    public var repositoryNameWithOwner: String
    public var number: Int
    public var title: String
    public var url: URL
    public var authorLogin: String
    public var lifecycleState: PullRequestLifecycleState
    public var headRefName: String
    public var baseRefName: String
    public var ciState: CIState
    public var mergeState: MergeState
    public var updatedAt: Date
    public var lastSuccessfulRefreshAt: Date?

    public init(
        id: GitHubNodeID,
        repositoryID: GitHubNodeID,
        repositoryNameWithOwner: String,
        number: Int,
        title: String,
        url: URL,
        authorLogin: String,
        lifecycleState: PullRequestLifecycleState,
        headRefName: String,
        baseRefName: String,
        ciState: CIState,
        mergeState: MergeState,
        updatedAt: Date,
        lastSuccessfulRefreshAt: Date? = nil
    ) {
        self.id = id
        self.repositoryID = repositoryID
        self.repositoryNameWithOwner = repositoryNameWithOwner
        self.number = number
        self.title = title
        self.url = url
        self.authorLogin = authorLogin
        self.lifecycleState = lifecycleState
        self.headRefName = headRefName
        self.baseRefName = baseRefName
        self.ciState = ciState
        self.mergeState = mergeState
        self.updatedAt = updatedAt
        self.lastSuccessfulRefreshAt = lastSuccessfulRefreshAt
    }
}

public struct PRFilterConfiguration: Hashable, Sendable, Codable {
    public var includeAllOpen: Bool
    public var includeAuthoredByMe: Bool
    public var includeAssignedToMe: Bool
    public var includeReviewRequestedFromMe: Bool

    public init(
        includeAllOpen: Bool = false,
        includeAuthoredByMe: Bool = true,
        includeAssignedToMe: Bool = true,
        includeReviewRequestedFromMe: Bool = true
    ) {
        self.includeAllOpen = includeAllOpen
        self.includeAuthoredByMe = includeAuthoredByMe
        self.includeAssignedToMe = includeAssignedToMe
        self.includeReviewRequestedFromMe = includeReviewRequestedFromMe
    }

    public static let mvpDefault = PRFilterConfiguration()
}

public enum TransitionEventKind: String, Hashable, Sendable, Codable {
    case newPullRequestAuthoredByMe
    case ciChanged
    case mergeChanged
    case closedOrMerged
}

public struct TransitionEvent: Hashable, Sendable, Codable, Identifiable {
    public var id: UUID
    public var pullRequestID: GitHubNodeID
    public var repositoryNameWithOwner: String
    public var number: Int
    public var title: String
    public var kind: TransitionEventKind
    public var oldValue: String
    public var newValue: String
    public var observedAt: Date

    public init(
        id: UUID = UUID(),
        pullRequestID: GitHubNodeID,
        repositoryNameWithOwner: String,
        number: Int,
        title: String,
        kind: TransitionEventKind,
        oldValue: String,
        newValue: String,
        observedAt: Date
    ) {
        self.id = id
        self.pullRequestID = pullRequestID
        self.repositoryNameWithOwner = repositoryNameWithOwner
        self.number = number
        self.title = title
        self.kind = kind
        self.oldValue = oldValue
        self.newValue = newValue
        self.observedAt = observedAt
    }
}

public enum MenuBarSeverity: String, Hashable, Sendable, Codable, CaseIterable {
    case attention
    case inProgress
    case healthy
    case neutral
}

public enum AuthSessionState: Hashable, Sendable {
    case signedOut
    case deviceFlowPending(userCode: String, verificationURL: URL)
    case signedIn(GitHubAccount)
    case needsReauthorization(reason: String)
}

public struct RateLimitSnapshot: Hashable, Sendable, Codable {
    public var remaining: Int?
    public var limit: Int?
    public var resetAt: Date?
    public var retryAfter: TimeInterval?

    public init(
        remaining: Int? = nil,
        limit: Int? = nil,
        resetAt: Date? = nil,
        retryAfter: TimeInterval? = nil
    ) {
        self.remaining = remaining
        self.limit = limit
        self.resetAt = resetAt
        self.retryAfter = retryAfter
    }
}

public enum GitPingsError: Error, Sendable, Equatable {
    case notAuthenticated
    case reauthorizationRequired(String)
    case rateLimited(retryAfter: TimeInterval?)
    case networkUnavailable
    case partialData(String)
    case pinLimitReached
    case unsupportedConfiguration(String)
}
