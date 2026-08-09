import Foundation

/// Direct GitHub.com session and GraphQL transport. The access token stays in
/// memory and Keychain; GitPings has no callback server or hosted database.
public actor LiveGitHubService {
    private static let activeAccountKey = "GitPings.activeGitHubAccountID"

    private let tokenStore: any KeychainTokenStore
    private let urlSession: URLSession
    private var accessToken: String?
    private var refreshToken: String?
    private var currentAccount: GitHubAccount?
    private var pendingDeviceCode: String?
    private var pendingPollInterval: TimeInterval = 5
    private var oauthClientID: String

    public init(
        tokenStore: any KeychainTokenStore = MacKeychainTokenStore(),
        urlSession: URLSession = .shared,
        oauthClientID: String = ""
    ) {
        self.tokenStore = tokenStore
        self.urlSession = urlSession
        self.oauthClientID = oauthClientID
    }

    public func configureOAuthClientID(_ clientID: String) {
        oauthClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Restore either the app's Keychain session or a development-only token
    /// supplied in the process environment. Environment tokens are never saved.
    public func restoreSession() async throws -> GitHubAccount? {
        if let environmentToken = ProcessInfo.processInfo.environment["GITPINGS_GITHUB_TOKEN"],
           !environmentToken.isEmpty
        {
            accessToken = environmentToken
            let account = try await fetchViewer()
            currentAccount = account
            return account
        }

        guard let rawID = UserDefaults.standard.string(forKey: Self.activeAccountKey) else {
            return nil
        }
        let accountID = GitHubNodeID(rawID)
        guard let stored = try await tokenStore.loadTokens(for: accountID) else {
            UserDefaults.standard.removeObject(forKey: Self.activeAccountKey)
            return nil
        }
        accessToken = stored.accessToken
        refreshToken = stored.refreshToken
        do {
            let account = try await fetchViewer()
            currentAccount = account
            if let accessToken {
                try await tokenStore.saveTokens(
                    accountID: account.id,
                    accessToken: accessToken,
                    refreshToken: refreshToken
                )
            }
            return account
        } catch {
            accessToken = nil
            refreshToken = nil
            throw error
        }
    }

    public func beginDeviceFlow() async throws -> DeviceAuthorizationResponse {
        let client = URLSessionDeviceFlowClient(clientID: oauthClientID, session: urlSession)
        let response = try await client.requestDeviceCode()
        pendingDeviceCode = response.deviceCode
        pendingPollInterval = max(response.interval, 5)
        return response
    }

    public func pollDeviceFlow() async throws -> AuthSessionState {
        guard let pendingDeviceCode else {
            throw GitPingsError.unsupportedConfiguration("No GitHub sign-in is pending")
        }
        let client = URLSessionDeviceFlowClient(clientID: oauthClientID, session: urlSession)
        switch try await client.pollAccessToken(deviceCode: pendingDeviceCode) {
        case .authorizationPending(let interval), .slowDown(let interval):
            pendingPollInterval = max(interval, 5)
            return .deviceFlowPending(
                userCode: "",
                verificationURL: URL(string: "https://github.com/login/device")!
            )
        case .expiredToken:
            clearPendingFlow()
            return .needsReauthorization(reason: "The GitHub sign-in code expired")
        case .accessDenied:
            clearPendingFlow()
            return .needsReauthorization(reason: "GitHub authorization was cancelled")
        case .incorrectClientCredentials:
            clearPendingFlow()
            return .needsReauthorization(reason: "The GitHub OAuth client ID is invalid")
        case .success(let tokens):
            accessToken = tokens.accessToken
            refreshToken = tokens.refreshToken
            do {
                let account = try await fetchViewer()
                try await tokenStore.saveTokens(
                    accountID: account.id,
                    accessToken: tokens.accessToken,
                    refreshToken: tokens.refreshToken
                )
                UserDefaults.standard.set(account.id.rawValue, forKey: Self.activeAccountKey)
                currentAccount = account
                clearPendingFlow()
                return .signedIn(account)
            } catch {
                accessToken = nil
                refreshToken = nil
                throw error
            }
        }
    }

    public func nextDevicePollInterval() -> TimeInterval { pendingPollInterval }

    public func cancelDeviceFlow() {
        clearPendingFlow()
    }

    public func signOut() async throws {
        if let account = currentAccount {
            try await tokenStore.deleteTokens(for: account.id)
        }
        UserDefaults.standard.removeObject(forKey: Self.activeAccountKey)
        accessToken = nil
        refreshToken = nil
        currentAccount = nil
        clearPendingFlow()
    }

    public func listRepositories() async throws -> [RepositorySummary] {
        var repositories: [RepositorySummary] = []
        var cursor: String?
        repeat {
            let page: GraphQLResponse<ViewerRepositoriesDTO> = try await graphQL(
                document: GraphQLQueries.viewerRepositoriesPage,
                variables: ["first": .int(100), "after": cursor.map(JSONValue.string) ?? .null]
            )
            let connection = try requireData(page).viewer.repositories
            repositories.append(contentsOf: connection.nodes.compactMap { $0?.asSummary() })
            cursor = connection.pageInfo.hasNextPage ? connection.pageInfo.endCursor : nil
        } while cursor != nil
        return repositories.sorted { $0.nameWithOwner.localizedCaseInsensitiveCompare($1.nameWithOwner) == .orderedAscending }
    }

    public func fetchPullRequests(
        repositories: [RepositorySummary],
        filters: PRFilterConfiguration,
        login: String
    ) async throws -> (pullRequests: [PullRequestSummary], rateLimit: RateLimitSnapshot) {
        let searches = FilterQueryCompiler.compile(
            filters: filters,
            authenticatedLogin: login,
            repositories: repositories
        )
        var byID: [GitHubNodeID: PullRequestSummary] = [:]
        var latestRateLimit = RateLimitSnapshot()

        for search in searches {
            var cursor: String?
            repeat {
                let response: GraphQLResponse<PullRequestSearchDTO> = try await graphQL(
                    document: GraphQLQueries.pullRequestSearchPage,
                    variables: [
                        "query": .string(search.query),
                        "first": .int(100),
                        "after": cursor.map(JSONValue.string) ?? .null,
                    ]
                )
                let data = try requireData(response)
                latestRateLimit = data.rateLimit?.asSnapshot() ?? latestRateLimit
                for node in data.search.nodes.compactMap({ $0 }) {
                    if let summary = node.asSummary(lastSuccessfulRefreshAt: Date(), isFreshMergeCalculation: true) {
                        byID[summary.id] = summary
                    }
                }
                cursor = data.search.pageInfo.hasNextPage ? data.search.pageInfo.endCursor : nil
            } while cursor != nil
        }

        return (
            byID.values.sorted { lhs, rhs in
                if lhs.repositoryNameWithOwner == rhs.repositoryNameWithOwner { return lhs.number > rhs.number }
                return lhs.repositoryNameWithOwner < rhs.repositoryNameWithOwner
            },
            latestRateLimit
        )
    }

    public func lookupPullRequest(id: GitHubNodeID) async throws -> PullRequestSummary? {
        let response: GraphQLResponse<PullRequestLookupDTO> = try await graphQL(
            document: GraphQLQueries.pullRequestByNodeID,
            variables: ["id": .string(id.rawValue)]
        )
        if let error = response.errors?.first {
            if error.indicatesMissingNode { return nil }
            throw GitPingsError.partialData(error.message)
        }
        guard let data = response.data else {
            throw GitPingsError.partialData("GitHub returned no data")
        }
        return data.node?.asSummary(lastSuccessfulRefreshAt: Date(), isFreshMergeCalculation: true)
    }

    private func fetchViewer() async throws -> GitHubAccount {
        let response: GraphQLResponse<ViewerLoginDTO> = try await graphQL(
            document: GraphQLQueries.viewerLogin,
            variables: [:]
        )
        let viewer = try requireData(response).viewer
        return GitHubAccount(id: GitHubNodeID(viewer.id), login: viewer.login)
    }

    private func graphQL<Response: Decodable & Sendable>(
        document: String,
        variables: [String: JSONValue],
        mayRefreshToken: Bool = true
    ) async throws -> GraphQLResponse<Response> {
        guard let accessToken, !accessToken.isEmpty else { throw GitPingsError.notAuthenticated }
        var request = URLRequest(url: GraphQLQueries.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.httpBody = try JSONEncoder().encode(GraphQLRequest(query: document, variables: variables))
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitPingsError.networkUnavailable }
        if http.statusCode == 401, mayRefreshToken, let refreshToken {
            let client = URLSessionDeviceFlowClient(clientID: oauthClientID, session: urlSession)
            do {
                let refreshed = try await client.refreshAccessToken(refreshToken: refreshToken)
                self.accessToken = refreshed.accessToken
                self.refreshToken = refreshed.refreshToken ?? refreshToken
                if let account = currentAccount {
                    try await tokenStore.saveTokens(
                        accountID: account.id,
                        accessToken: refreshed.accessToken,
                        refreshToken: self.refreshToken
                    )
                }
                return try await graphQL(
                    document: document,
                    variables: variables,
                    mayRefreshToken: false
                )
            } catch {
                throw GitPingsError.reauthorizationRequired("GitHub rejected the saved session")
            }
        }
        if http.statusCode == 401 { throw GitPingsError.reauthorizationRequired("GitHub rejected the saved session") }
        if http.statusCode == 403 || http.statusCode == 429 {
            throw GitPingsError.rateLimited(retryAfter: http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init))
        }
        guard (200..<300).contains(http.statusCode) else { throw GitPingsError.networkUnavailable }
        return try JSONDecoder().decode(GraphQLResponse<Response>.self, from: data)
    }

    private func requireData<Value>(_ response: GraphQLResponse<Value>) throws -> Value {
        if let message = response.errors?.first?.message {
            throw GitPingsError.partialData(message)
        }
        guard let data = response.data else { throw GitPingsError.partialData("GitHub returned no data") }
        return data
    }

    private func clearPendingFlow() {
        pendingDeviceCode = nil
        pendingPollInterval = 5
    }
}

private struct GraphQLRequest: Encodable {
    let query: String
    let variables: [String: JSONValue]
}

private enum JSONValue: Encodable {
    case string(String)
    case int(Int)
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

public struct ViewerRepositoriesDTO: Decodable, Sendable {
    public let viewer: ViewerRepositoriesViewerDTO
    public let rateLimit: RateLimitDTO?
}

public struct ViewerRepositoriesViewerDTO: Decodable, Sendable {
    public let repositories: RepositoryConnectionDTO
}

public struct RepositoryConnectionDTO: Decodable, Sendable {
    public let pageInfo: PageInfoDTO
    public let nodes: [RepositoryNodeDTO?]
}

public struct RepositoryNodeDTO: Decodable, Sendable {
    public let id: String
    public let name: String
    public let nameWithOwner: String
    public let isPrivate: Bool
    public let owner: RepositoryOwnerDTO

    public func asSummary() -> RepositorySummary {
        RepositorySummary(
            id: GitHubNodeID(id),
            ownerLogin: owner.login,
            name: name,
            nameWithOwner: nameWithOwner,
            visibility: isPrivate ? .private : .public,
            isOrganizationOwned: owner.typename == "Organization"
        )
    }
}

public struct RepositoryOwnerDTO: Decodable, Sendable {
    public let login: String
    public let typename: String

    enum CodingKeys: String, CodingKey {
        case login
        case typename = "__typename"
    }
}

public struct PullRequestLookupDTO: Decodable, Sendable {
    public let node: PullRequestNodeDTO?
    public let rateLimit: RateLimitDTO?
}
