import Foundation

struct GitNotaryLaunchOptions: Equatable, Sendable {
    static let setupFlag = "--gitnotary-setup"
    static let expectedLoginFlag = "--expected-github-login"

    var shouldBeginSetup: Bool
    var expectedGitHubLogin: String?

    init(arguments: [String]) {
        shouldBeginSetup = arguments.contains(Self.setupFlag)

        guard let flagIndex = arguments.firstIndex(of: Self.expectedLoginFlag),
              arguments.indices.contains(flagIndex + 1)
        else {
            expectedGitHubLogin = nil
            return
        }

        let value = arguments[flagIndex + 1].trimmingCharacters(in: .whitespacesAndNewlines)
        expectedGitHubLogin = value.isEmpty ? nil : value
    }

    static var current: GitNotaryLaunchOptions {
        GitNotaryLaunchOptions(arguments: ProcessInfo.processInfo.arguments)
    }
}
