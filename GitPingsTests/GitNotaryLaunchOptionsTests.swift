import XCTest
@testable import GitPings

final class GitNotaryLaunchOptionsTests: XCTestCase {
    func testProductionGitHubAppConfigurationIsPublicAndComplete() {
        XCTAssertEqual(GitNotaryConfiguration.clientID, "Iv23li1INlISnAzx1Nsj")
        XCTAssertEqual(GitNotaryConfiguration.publicURL.absoluteString, "https://github.com/apps/gitnotary")
        XCTAssertEqual(
            GitNotaryConfiguration.installationURL.absoluteString,
            "https://github.com/apps/gitnotary/installations/new"
        )
    }

    func testSetupFlagEnablesSetupMode() {
        let options = GitNotaryLaunchOptions(arguments: ["GitPings", "--gitnotary-setup"])

        XCTAssertTrue(options.shouldBeginSetup)
        XCTAssertNil(options.expectedGitHubLogin)
        XCTAssertNil(options.preferredAuthenticationMethod)
    }

    func testExpectedLoginIsParsedWithoutReadingCredentials() {
        let options = GitNotaryLaunchOptions(arguments: [
            "GitPings",
            "--gitnotary-setup",
            "--expected-github-login",
            "octocat",
        ])

        XCTAssertEqual(options.expectedGitHubLogin, "octocat")
    }

    func testSetupCanSelectLocalGitHubCLIAuthentication() {
        let options = GitNotaryLaunchOptions(arguments: [
            "GitPings",
            "--gitnotary-setup",
            "--authentication-method",
            "githubCLI",
        ])

        XCTAssertEqual(options.preferredAuthenticationMethod, .githubCLI)
    }

    func testUnknownAuthenticationMethodIsIgnored() {
        let options = GitNotaryLaunchOptions(arguments: [
            "GitPings",
            "--authentication-method",
            "unknown-provider",
        ])

        XCTAssertNil(options.preferredAuthenticationMethod)
    }

    func testMissingExpectedLoginValueIsIgnored() {
        let options = GitNotaryLaunchOptions(arguments: [
            "GitPings",
            "--expected-github-login",
        ])

        XCTAssertFalse(options.shouldBeginSetup)
        XCTAssertNil(options.expectedGitHubLogin)
        XCTAssertNil(options.preferredAuthenticationMethod)
    }
}
