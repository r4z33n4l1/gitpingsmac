import Foundation

struct GitNotaryLaunchOptions: Equatable, Sendable {
    static let setupFlag = "--gitnotary-setup"
    static let expectedLoginFlag = "--expected-github-login"
    static let authenticationMethodFlag = "--authentication-method"

    var shouldBeginSetup: Bool
    var expectedGitHubLogin: String?
    var preferredAuthenticationMethod: GitHubAuthenticationMethod?

    init(arguments: [String]) {
        shouldBeginSetup = arguments.contains(Self.setupFlag)

        expectedGitHubLogin = Self.value(after: Self.expectedLoginFlag, in: arguments)
        preferredAuthenticationMethod = Self.value(
            after: Self.authenticationMethodFlag,
            in: arguments
        ).flatMap(GitHubAuthenticationMethod.init(rawValue:))
    }

    static var current: GitNotaryLaunchOptions {
        GitNotaryLaunchOptions(arguments: ProcessInfo.processInfo.arguments)
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let flagIndex = arguments.firstIndex(of: flag),
              arguments.indices.contains(flagIndex + 1)
        else { return nil }

        let value = arguments[flagIndex + 1].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
