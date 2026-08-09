import Foundation
import Observation

/// Composition root owned by the integrator. Feature agents must not edit this file.
@MainActor
@Observable
final class AppModel {
    var authState: AuthSessionState = .signedOut
    var repositories: [RepositorySummary] = []
    var selectedRepositoryIDs: Set<GitHubNodeID> = []
    var filters: PRFilterConfiguration = .mvpDefault
    var pullRequests: [PullRequestSummary] = []
    var pinnedIDs: [GitHubNodeID] = []
    var menuBarSeverity: MenuBarSeverity = .neutral
    var lastSuccessfulRefreshAt: Date?
    var statusMessage: String = "Foundation scaffold — Gate 0 pending"

    var pinnedPullRequests: [PullRequestSummary] {
        pinnedIDs.compactMap { id in pullRequests.first(where: { $0.id == id }) }
    }

    func applyFixturePreview() {
        authState = .signedIn(GitPingsFixtures.account)
        repositories = [GitPingsFixtures.publicRepo, GitPingsFixtures.privateOrgRepo]
        selectedRepositoryIDs = Set(repositories.map(\.id))
        filters = GitPingsFixtures.defaultFilters
        pullRequests = GitPingsFixtures.sampleTrackedPRs
        pinnedIDs = Array(pullRequests.prefix(PinPolicy.maximumPinCount).map(\.id))
        menuBarSeverity = MenuBarSeverityCalculator.severity(for: pinnedPullRequests)
        lastSuccessfulRefreshAt = GitPingsFixtures.fixedNow
        statusMessage = "Loaded deterministic fixtures"
    }
}

@MainActor
final class AppDependencyContainer {
    let appModel: AppModel
    let clock: any ClockProviding
    let authService: any AuthService
    let pullRequestQueryService: any PullRequestQueryService
    let repositoryCatalog: any RepositoryCatalogService

    init(
        appModel: AppModel = AppModel(),
        clock: any ClockProviding = SystemClock(),
        authService: any AuthService = MockAuthService(),
        pullRequestQueryService: any PullRequestQueryService = MockPullRequestQueryService(),
        repositoryCatalog: any RepositoryCatalogService = MockRepositoryCatalogService()
    ) {
        self.appModel = appModel
        self.clock = clock
        self.authService = authService
        self.pullRequestQueryService = pullRequestQueryService
        self.repositoryCatalog = repositoryCatalog
    }

    static func bootstrap() -> AppDependencyContainer {
        let container = AppDependencyContainer()
        // Wave 0: seed UI with fixtures so the launched bundle is inspectable without live GitHub.
        container.appModel.applyFixturePreview()
        return container
    }
}
