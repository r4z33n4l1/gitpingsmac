import Foundation

/// Low-level GitHub OAuth device-flow transport (AUTH-2 / AUTH-2A).
/// Speaks only to GitHub.com — no GitPings callback server.
public protocol DeviceFlowClient: Sendable {
    func requestDeviceCode() async throws -> DeviceAuthorizationResponse
    func pollAccessToken(deviceCode: String) async throws -> DeviceTokenPollResult
    func refreshAccessToken(refreshToken: String) async throws -> DeviceTokenSuccess
}

/// Redact before logging. Fixtures use placeholders only.
public struct DeviceAuthorizationResponse: Hashable, Sendable {
    public var deviceCode: String
    public var userCode: String
    public var verificationURI: URL
    public var verificationURIComplete: URL?
    public var expiresIn: TimeInterval
    public var interval: TimeInterval

    public init(
        deviceCode: String,
        userCode: String,
        verificationURI: URL,
        verificationURIComplete: URL? = nil,
        expiresIn: TimeInterval,
        interval: TimeInterval
    ) {
        self.deviceCode = deviceCode
        self.userCode = userCode
        self.verificationURI = verificationURI
        self.verificationURIComplete = verificationURIComplete
        self.expiresIn = expiresIn
        self.interval = interval
    }
}

public struct DeviceTokenSuccess: Hashable, Sendable {
    public var accessToken: String
    public var refreshToken: String?
    public var tokenType: String
    public var scope: String?
    public var expiresIn: TimeInterval?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        tokenType: String = "bearer",
        scope: String? = nil,
        expiresIn: TimeInterval? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.scope = scope
        self.expiresIn = expiresIn
    }
}

public enum DeviceTokenPollResult: Hashable, Sendable {
    case success(DeviceTokenSuccess)
    case authorizationPending(interval: TimeInterval)
    case slowDown(interval: TimeInterval)
    case expiredToken
    case accessDenied
    case incorrectClientCredentials
}

/// Spike stub: documents endpoints and JSON shapes. Does not perform live network I/O
/// until a public `client_id` is injected by the integrator and a macOS host is available.
public struct StubDeviceFlowClient: DeviceFlowClient {
    public var clientID: String

    public init(clientID: String = "") {
        self.clientID = clientID
    }

    /// `POST https://github.com/login/device/code`
    public static let deviceCodeURL = URL(string: "https://github.com/login/device/code")!

    /// `POST https://github.com/login/oauth/access_token`
    public static let accessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!

    public func requestDeviceCode() async throws -> DeviceAuthorizationResponse {
        guard !clientID.isEmpty else {
            throw GitPingsError.unsupportedConfiguration(
                "GitHub App client_id is not configured; live device-flow blocked in this spike"
            )
        }
        throw GitPingsError.unsupportedConfiguration(
            "StubDeviceFlowClient does not perform live HTTP; wire URLSession on macOS host"
        )
    }

    public func pollAccessToken(deviceCode: String) async throws -> DeviceTokenPollResult {
        _ = deviceCode
        guard !clientID.isEmpty else {
            throw GitPingsError.unsupportedConfiguration(
                "GitHub App client_id is not configured; live device-flow blocked in this spike"
            )
        }
        throw GitPingsError.unsupportedConfiguration(
            "StubDeviceFlowClient does not perform live HTTP; wire URLSession on macOS host"
        )
    }

    public func refreshAccessToken(refreshToken: String) async throws -> DeviceTokenSuccess {
        _ = refreshToken
        guard !clientID.isEmpty else {
            throw GitPingsError.unsupportedConfiguration(
                "GitHub App client_id is not configured; live device-flow blocked in this spike"
            )
        }
        throw GitPingsError.unsupportedConfiguration(
            "StubDeviceFlowClient does not perform live HTTP; wire URLSession on macOS host"
        )
    }
}
