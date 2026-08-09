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

/// Production device-flow transport. GitHub's device flow requires only the
/// public client ID; no client secret or callback server is shipped in the app.
public struct URLSessionDeviceFlowClient: DeviceFlowClient {
    public static let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    public static let accessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!

    public let clientID: String
    public let scope: String
    private let session: URLSession

    public init(clientID: String, scope: String = "", session: URLSession = .shared) {
        self.clientID = clientID
        self.scope = scope
        self.session = session
    }

    public func requestDeviceCode() async throws -> DeviceAuthorizationResponse {
        guard !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GitPingsError.unsupportedConfiguration("Add a GitHub OAuth client ID in Settings first.")
        }
        var fields = ["client_id": clientID]
        if !scope.isEmpty { fields["scope"] = scope }
        let payload: DeviceCodePayload = try await post(Self.deviceCodeURL, fields: fields)
        guard let verificationURI = URL(string: payload.verificationURI) else {
            throw GitPingsError.partialData("GitHub returned an invalid verification URL")
        }
        return DeviceAuthorizationResponse(
            deviceCode: payload.deviceCode,
            userCode: payload.userCode,
            verificationURI: verificationURI,
            verificationURIComplete: payload.verificationURIComplete.flatMap(URL.init(string:)),
            expiresIn: payload.expiresIn,
            interval: payload.interval ?? 5
        )
    }

    public func pollAccessToken(deviceCode: String) async throws -> DeviceTokenPollResult {
        let payload: TokenPayload = try await post(Self.accessTokenURL, fields: [
            "client_id": clientID,
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        ])
        if let accessToken = payload.accessToken {
            return .success(DeviceTokenSuccess(
                accessToken: accessToken,
                refreshToken: payload.refreshToken,
                tokenType: payload.tokenType ?? "bearer",
                scope: payload.scope,
                expiresIn: payload.expiresIn
            ))
        }
        switch payload.error {
        case "authorization_pending": return .authorizationPending(interval: payload.interval ?? 5)
        case "slow_down": return .slowDown(interval: payload.interval ?? 10)
        case "expired_token": return .expiredToken
        case "access_denied": return .accessDenied
        case "incorrect_client_credentials": return .incorrectClientCredentials
        default:
            throw GitPingsError.partialData(payload.errorDescription ?? payload.error ?? "GitHub authorization failed")
        }
    }

    public func refreshAccessToken(refreshToken: String) async throws -> DeviceTokenSuccess {
        let payload: TokenPayload = try await post(Self.accessTokenURL, fields: [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
        ])
        guard let accessToken = payload.accessToken else {
            throw GitPingsError.reauthorizationRequired(payload.errorDescription ?? "GitHub refresh failed")
        }
        return DeviceTokenSuccess(
            accessToken: accessToken,
            refreshToken: payload.refreshToken,
            tokenType: payload.tokenType ?? "bearer",
            scope: payload.scope,
            expiresIn: payload.expiresIn
        )
    }

    private func post<Response: Decodable>(_ url: URL, fields: [String: String]) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields
            .sorted(by: { $0.key < $1.key })
            .map { key, value in
                "\(formEncode(key))=\(formEncode(value))"
            }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GitPingsError.networkUnavailable
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private struct DeviceCodePayload: Decodable {
        let deviceCode: String
        let userCode: String
        let verificationURI: String
        let verificationURIComplete: String?
        let expiresIn: TimeInterval
        let interval: TimeInterval?

        enum CodingKeys: String, CodingKey {
            case deviceCode = "device_code"
            case userCode = "user_code"
            case verificationURI = "verification_uri"
            case verificationURIComplete = "verification_uri_complete"
            case expiresIn = "expires_in"
            case interval
        }
    }

    private struct TokenPayload: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let tokenType: String?
        let scope: String?
        let expiresIn: TimeInterval?
        let error: String?
        let errorDescription: String?
        let interval: TimeInterval?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case tokenType = "token_type"
            case scope
            case expiresIn = "expires_in"
            case error
            case errorDescription = "error_description"
            case interval
        }
    }
}
