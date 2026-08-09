import Foundation

/// AuthService sketch over device flow + Keychain (AUTH-1..AUTH-8).
/// Not production-polished UI; no live network until client_id + macOS host exist.
public actor DeviceFlowAuthService: AuthService {
    private let deviceFlow: any DeviceFlowClient
    private let tokenStore: any KeychainTokenStore
    private var session: AuthSessionState
    private var pendingDeviceCode: String?
    private var pollInterval: TimeInterval
    private var accountIDForTokens: GitHubNodeID?

    public init(
        deviceFlow: any DeviceFlowClient = StubDeviceFlowClient(),
        tokenStore: any KeychainTokenStore = MacKeychainTokenStore(),
        initialSession: AuthSessionState = .signedOut
    ) {
        self.deviceFlow = deviceFlow
        self.tokenStore = tokenStore
        self.session = initialSession
        self.pollInterval = 5
    }

    public func currentSession() async -> AuthSessionState {
        session
    }

    public func beginDeviceFlow() async throws -> AuthSessionState {
        let response = try await deviceFlow.requestDeviceCode()
        // Device/user codes must never be logged (ADR-002 / privacy).
        pendingDeviceCode = response.deviceCode
        pollInterval = max(response.interval, 5)
        session = .deviceFlowPending(
            userCode: response.userCode,
            verificationURL: response.verificationURIComplete ?? response.verificationURI
        )
        return session
    }

    public func pollDeviceFlow() async throws -> AuthSessionState {
        guard case .deviceFlowPending = session else {
            throw GitPingsError.unsupportedConfiguration("No device flow in progress")
        }
        guard let pendingDeviceCode else {
            throw GitPingsError.unsupportedConfiguration("Missing pending device code")
        }

        let result = try await deviceFlow.pollAccessToken(deviceCode: pendingDeviceCode)
        switch result {
        case .authorizationPending(let interval):
            pollInterval = interval
            return session
        case .slowDown(let interval):
            pollInterval = interval
            return session
        case .expiredToken:
            clearPending()
            session = .needsReauthorization(reason: "Device code expired")
            return session
        case .accessDenied:
            clearPending()
            session = .needsReauthorization(reason: "Authorization denied")
            return session
        case .incorrectClientCredentials:
            clearPending()
            session = .needsReauthorization(reason: "Incorrect client credentials")
            return session
        case .success(let tokens):
            // Account identity is resolved via GraphQL viewer after token save in production.
            // Spike stores under a placeholder until viewer login is fetched.
            let account = GitPingsFixtures.account
            try await tokenStore.saveTokens(
                accountID: account.id,
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken
            )
            accountIDForTokens = account.id
            clearPending()
            session = .signedIn(account)
            return session
        }
    }

    public func cancelDeviceFlow() async {
        clearPending()
        if case .deviceFlowPending = session {
            session = .signedOut
        }
    }

    public func signOut() async throws {
        if let accountIDForTokens {
            try await tokenStore.deleteTokens(for: accountIDForTokens)
        } else {
            try await tokenStore.deleteAllTokens()
        }
        clearPending()
        accountIDForTokens = nil
        session = .signedOut
    }

    public func refreshAccessTokenIfNeeded() async throws {
        guard let accountIDForTokens else {
            throw GitPingsError.notAuthenticated
        }
        guard let stored = try await tokenStore.loadTokens(for: accountIDForTokens),
              let refresh = stored.refreshToken
        else {
            session = .needsReauthorization(reason: "Missing refresh token")
            throw GitPingsError.reauthorizationRequired("Missing refresh token")
        }
        do {
            let refreshed = try await deviceFlow.refreshAccessToken(refreshToken: refresh)
            try await tokenStore.saveTokens(
                accountID: accountIDForTokens,
                accessToken: refreshed.accessToken,
                refreshToken: refreshed.refreshToken ?? refresh
            )
        } catch {
            session = .needsReauthorization(reason: "Refresh rejected")
            throw GitPingsError.reauthorizationRequired("Refresh rejected")
        }
    }

    private func clearPending() {
        pendingDeviceCode = nil
    }
}
