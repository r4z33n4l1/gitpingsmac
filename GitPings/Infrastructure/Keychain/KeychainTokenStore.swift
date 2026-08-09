import Foundation

#if canImport(Security)
import Security
#endif

/// Concrete Keychain-backed token store (AUTH-5).
/// API matches Domain `KeychainTokenStore`. Tokens are never written to disk/logs.
///
/// Keychain usage (macOS):
/// - Service: `com.razeenali.gitpings.github-tokens`
/// - Account: GitHub account node ID (`GitHubNodeID.rawValue`)
/// - Accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
/// - Value: JSON `{ "accessToken": "...", "refreshToken": "..."? }` stored as `kSecClassGenericPassword`
/// - On sign-out: delete item(s); `deleteAllTokens` clears the service.
///
/// Linux / non-Security hosts: methods throw `unsupportedConfiguration` (spike only).
public actor MacKeychainTokenStore: KeychainTokenStore {
    public static let service = "com.razeenali.gitpings.github-tokens"

    public init() {}

    public func loadTokens(for accountID: GitHubNodeID) async throws -> (accessToken: String, refreshToken: String?)? {
        #if canImport(Security) && os(macOS)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: accountID.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw GitPingsError.unsupportedConfiguration("Keychain read failed: \(status)")
        }
        let payload = try JSONDecoder().decode(TokenPayload.self, from: data)
        return (payload.accessToken, payload.refreshToken)
        #else
        throw GitPingsError.unsupportedConfiguration(
            "MacKeychainTokenStore requires macOS Security framework; unavailable on this host"
        )
        #endif
    }

    public func saveTokens(accountID: GitHubNodeID, accessToken: String, refreshToken: String?) async throws {
        #if canImport(Security) && os(macOS)
        let payload = TokenPayload(accessToken: accessToken, refreshToken: refreshToken)
        let data = try JSONEncoder().encode(payload)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: accountID.rawValue,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            throw GitPingsError.unsupportedConfiguration("Keychain update failed: \(updateStatus)")
        }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw GitPingsError.unsupportedConfiguration("Keychain add failed: \(addStatus)")
        }
        #else
        _ = accountID
        _ = accessToken
        _ = refreshToken
        throw GitPingsError.unsupportedConfiguration(
            "MacKeychainTokenStore requires macOS Security framework; unavailable on this host"
        )
        #endif
    }

    public func deleteTokens(for accountID: GitHubNodeID) async throws {
        #if canImport(Security) && os(macOS)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: accountID.rawValue,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GitPingsError.unsupportedConfiguration("Keychain delete failed: \(status)")
        }
        #else
        _ = accountID
        throw GitPingsError.unsupportedConfiguration(
            "MacKeychainTokenStore requires macOS Security framework; unavailable on this host"
        )
        #endif
    }

    public func deleteAllTokens() async throws {
        #if canImport(Security) && os(macOS)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GitPingsError.unsupportedConfiguration("Keychain deleteAll failed: \(status)")
        }
        #else
        throw GitPingsError.unsupportedConfiguration(
            "MacKeychainTokenStore requires macOS Security framework; unavailable on this host"
        )
        #endif
    }

    private struct TokenPayload: Codable, Sendable {
        var accessToken: String
        var refreshToken: String?
    }
}
