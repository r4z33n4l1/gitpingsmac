import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var authState: AuthSessionState = .signedOut
    var repositories: [RepositorySummary] = []
    var selectedRepositoryIDs: Set<GitHubNodeID> = [] {
        didSet { persistSelectedRepositories() }
    }
    var filters: PRFilterConfiguration = .mvpDefault {
        didSet { persistFilters() }
    }
    var pullRequests: [PullRequestSummary] = []
    var pinnedIDs: [GitHubNodeID] = [] {
        didSet { persistPins() }
    }
    private var retainedPinnedPullRequests: [GitHubNodeID: PullRequestSummary] = [:]
    var menuBarSeverity: MenuBarSeverity = .neutral
    var lastSuccessfulRefreshAt: Date?
    var statusMessage: String = "Sign in to GitHub to begin"
    var errorMessage: String?
    var isRefreshing = false
    var repositorySearch = ""
    private(set) var authenticationMethod: GitHubAuthenticationMethod
    private(set) var isChangingAuthenticationMethod = false

    var oauthClientID: String {
        didSet { UserDefaults.standard.set(oauthClientID, forKey: Keys.oauthClientID) }
    }
    var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
            if notificationsEnabled, !oldValue, didStart {
                authoredPullRequestBaselinePending = true
                refresh()
            }
        }
    }
    var newAuthoredPullRequestNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                newAuthoredPullRequestNotificationsEnabled,
                forKey: Keys.newAuthoredPullRequestNotificationsEnabled
            )
            if newAuthoredPullRequestNotificationsEnabled, !oldValue, didStart {
                authoredPullRequestBaselinePending = true
                refresh()
            }
        }
    }
    var notchNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notchNotificationsEnabled, forKey: Keys.notchEnabled) }
    }
    var systemNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(systemNotificationsEnabled, forKey: Keys.systemEnabled) }
    }
    var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: Keys.soundEnabled) }
    }

    @ObservationIgnored private let github: LiveGitHubService
    @ObservationIgnored private let detector = TransitionDetector()
    @ObservationIgnored private var didStart = false
    @ObservationIgnored private var baselinePending = true
    @ObservationIgnored private var authoredPullRequestBaselinePending = true
    @ObservationIgnored private var observedAuthoredPullRequests: [GitHubNodeID: PullRequestSummary] = [:]
    @ObservationIgnored private var refreshLoopTask: Task<Void, Never>?
    @ObservationIgnored private var authPollingTask: Task<Void, Never>?
    @ObservationIgnored private lazy var notchPresenter = NotchPanelCoordinator(
        callbacks: NotchPanelCallbacks(onEventClicked: { [weak self] event in
            Task { @MainActor in self?.openPullRequest(id: event.pullRequestID) }
        })
    )
    @ObservationIgnored private lazy var systemPresenter = SystemNotificationPresenter()

    init(github: LiveGitHubService = LiveGitHubService()) {
        self.github = github
        let defaults = UserDefaults.standard
        if let rawMethod = defaults.string(forKey: Keys.authenticationMethod),
           let savedMethod = GitHubAuthenticationMethod(rawValue: rawMethod)
        {
            authenticationMethod = savedMethod
        } else if defaults.string(forKey: Keys.legacyActiveGitHubAccountID) != nil {
            // Preserve the existing GitHub App session when upgrading from a
            // version that predates selectable authentication.
            authenticationMethod = .githubApp
        } else {
            authenticationMethod = .githubCLI
        }
        oauthClientID = ProcessInfo.processInfo.environment["GITPINGS_GITHUB_CLIENT_ID"]
            ?? (Bundle.main.object(forInfoDictionaryKey: "GitHubClientID") as? String)
            ?? GitNotaryConfiguration.clientID
        notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        newAuthoredPullRequestNotificationsEnabled = defaults.object(
            forKey: Keys.newAuthoredPullRequestNotificationsEnabled
        ) as? Bool ?? true
        notchNotificationsEnabled = defaults.object(forKey: Keys.notchEnabled) as? Bool ?? true
        systemNotificationsEnabled = defaults.object(forKey: Keys.systemEnabled) as? Bool ?? false
        soundEnabled = defaults.object(forKey: Keys.soundEnabled) as? Bool ?? false

        selectedRepositoryIDs = Set(defaults.stringArray(forKey: Keys.selectedRepositories)?.map { GitHubNodeID($0) } ?? [])
        pinnedIDs = defaults.stringArray(forKey: Keys.pins)?.map { GitHubNodeID($0) } ?? []
        if let data = defaults.data(forKey: Keys.filters),
           let savedFilters = try? JSONDecoder().decode(PRFilterConfiguration.self, from: data)
        {
            filters = savedFilters
        }
    }

    deinit {
        refreshLoopTask?.cancel()
        authPollingTask?.cancel()
    }

    var signedInAccount: GitHubAccount? {
        guard case .signedIn(let account) = authState else { return nil }
        return account
    }

    var hasBundledOAuthConfiguration: Bool {
        !GitNotaryConfiguration.clientID.isEmpty
    }

    var filteredRepositories: [RepositorySummary] {
        let query = repositorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return repositories }
        return repositories.filter { $0.nameWithOwner.localizedCaseInsensitiveContains(query) }
    }

    var selectedRepositories: [RepositorySummary] {
        repositories.filter { selectedRepositoryIDs.contains($0.id) }
    }

    var pinnedPullRequests: [PullRequestSummary] {
        pinnedIDs.compactMap { id in
            pullRequests.first(where: { $0.id == id }) ?? retainedPinnedPullRequests[id]
        }
    }

    func start(
        beginSignInIfNeeded: Bool = false,
        expectedGitHubLogin: String? = nil,
        preferredAuthenticationMethod: GitHubAuthenticationMethod? = nil
    ) {
        guard !didStart else { return }
        didStart = true
        Task {
            await github.configureOAuthClientID(oauthClientID)
            await github.configureAuthenticationMethod(authenticationMethod)
            do {
                if let preferredAuthenticationMethod,
                   preferredAuthenticationMethod != authenticationMethod
                {
                    try await github.signOut()
                    setAuthenticationMethod(preferredAuthenticationMethod)
                    await github.configureAuthenticationMethod(preferredAuthenticationMethod)
                    clearLocalGitHubState(status: "Authentication method changed")
                }

                let mayRestoreSession = authenticationMethod == .githubApp
                    || UserDefaults.standard.bool(forKey: Keys.githubCLIConnected)
                    || beginSignInIfNeeded
                if mayRestoreSession, let account = try await github.restoreSession() {
                    if let expectedGitHubLogin,
                       account.login.caseInsensitiveCompare(expectedGitHubLogin) != .orderedSame
                    {
                        throw GitPingsError.reauthorizationRequired(
                            "GitHub CLI is signed in as @\(account.login), not @\(expectedGitHubLogin). Run ‘gh auth switch’ and try again."
                        )
                    }
                    if authenticationMethod == .githubCLI {
                        UserDefaults.standard.set(true, forKey: Keys.githubCLIConnected)
                    }
                    authState = .signedIn(account)
                    statusMessage = "Connected as @\(account.login) via \(authenticationMethod.displayName)"
                    try await loadRepositoriesAndRefresh()
                    startRefreshLoop()
                } else if beginSignInIfNeeded {
                    if let expectedGitHubLogin {
                        statusMessage = "GitHub CLI detected @\(expectedGitHubLogin)"
                    }
                    beginSignIn()
                }
            } catch {
                authState = .needsReauthorization(reason: userFacing(error))
                errorMessage = userFacing(error)
                statusMessage = "GitHub session needs attention"
            }
        }
    }

    func beginSignIn() {
        errorMessage = nil
        authPollingTask?.cancel()
        if authenticationMethod == .githubCLI {
            connectGitHubCLI()
            return
        }
        authPollingTask = Task {
            await github.configureOAuthClientID(oauthClientID)
            do {
                let response = try await github.beginDeviceFlow()
                authState = .deviceFlowPending(
                    userCode: response.userCode,
                    verificationURL: response.verificationURIComplete ?? response.verificationURI
                )
                statusMessage = "Finish authorization in your browser"
                NSWorkspace.shared.open(response.verificationURIComplete ?? response.verificationURI)
                await pollForAuthorization()
            } catch {
                errorMessage = userFacing(error)
                statusMessage = "Could not start GitHub sign-in"
            }
        }
    }

    func cancelSignIn() {
        authPollingTask?.cancel()
        authPollingTask = nil
        Task { await github.cancelDeviceFlow() }
        authState = .signedOut
        statusMessage = "Sign in to GitHub to begin"
    }

    func signOut() {
        Task {
            do { try await github.signOut() } catch { errorMessage = userFacing(error) }
            if authenticationMethod == .githubCLI {
                UserDefaults.standard.set(false, forKey: Keys.githubCLIConnected)
            }
            clearLocalGitHubState(status: "Disconnected from GitHub")
        }
    }

    func selectAuthenticationMethod(_ method: GitHubAuthenticationMethod) {
        guard method != authenticationMethod, !isChangingAuthenticationMethod else { return }
        isChangingAuthenticationMethod = true
        errorMessage = nil
        Task {
            defer { isChangingAuthenticationMethod = false }
            do {
                try await github.signOut()
                UserDefaults.standard.set(false, forKey: Keys.githubCLIConnected)
                setAuthenticationMethod(method)
                await github.configureAuthenticationMethod(method)
                clearLocalGitHubState(status: "Using \(method.displayName)")
                if method == .githubCLI {
                    connectGitHubCLI()
                }
            } catch {
                errorMessage = userFacing(error)
            }
        }
    }

    func refresh(silent: Bool = false) {
        guard signedInAccount != nil, !isRefreshing else { return }
        Task { await performRefresh(silent: silent) }
    }

    func reloadRepositories() {
        guard signedInAccount != nil else { return }
        Task {
            do {
                repositories = try await github.listRepositories()
                statusMessage = "Found \(repositories.count) accessible repositories"
            } catch {
                errorMessage = userFacing(error)
            }
        }
    }

    func toggleRepository(_ repository: RepositorySummary) {
        if selectedRepositoryIDs.contains(repository.id) {
            selectedRepositoryIDs.remove(repository.id)
        } else {
            selectedRepositoryIDs.insert(repository.id)
        }
        baselinePending = true
        authoredPullRequestBaselinePending = true
        refresh()
    }

    func togglePin(_ pullRequest: PullRequestSummary) {
        errorMessage = nil
        if let index = pinnedIDs.firstIndex(of: pullRequest.id) {
            pinnedIDs.remove(at: index)
            retainedPinnedPullRequests[pullRequest.id] = nil
        } else if PinPolicy.canPin(currentCount: pinnedIDs.count) {
            pinnedIDs.append(pullRequest.id)
        } else {
            errorMessage = "You can pin up to five pull requests. Unpin one first."
        }
        updateMenuBarSeverity()
    }

    func filtersChanged() {
        baselinePending = true
        authoredPullRequestBaselinePending = true
        refresh()
    }

    func sendTestNotchNotification() {
        let sample = pinnedPullRequests.first ?? pullRequests.first ?? GitPingsFixtures.pullRequest()
        let event = TransitionEvent(
            pullRequestID: sample.id,
            repositoryNameWithOwner: sample.repositoryNameWithOwner,
            number: sample.number,
            title: sample.title,
            kind: .ciChanged,
            oldValue: CIState.pending.rawValue,
            newValue: CIState.passing.rawValue,
            observedAt: Date()
        )
        Task { await notchPresenter.present(events: [event]) }
    }

    func sendTestNotchQueue() {
        let source = Array(pullRequests.prefix(4))
        let events: [TransitionEvent] = (0..<4).map { index in
            let pullRequest = source.indices.contains(index) ? source[index] : nil
            return TransitionEvent(
                pullRequestID: pullRequest?.id ?? GitHubNodeID("PR_TEST_QUEUE_\(index + 1)"),
                repositoryNameWithOwner: pullRequest?.repositoryNameWithOwner ?? "gitpings/demo",
                number: pullRequest?.number ?? index + 1,
                title: pullRequest?.title ?? "Queued notification \(index + 1)",
                kind: index.isMultiple(of: 2) ? .ciChanged : .mergeChanged,
                oldValue: index.isMultiple(of: 2) ? CIState.pending.rawValue : MergeState.checking.rawValue,
                newValue: index.isMultiple(of: 2) ? CIState.passing.rawValue : MergeState.blocked.rawValue,
                observedAt: Date()
            )
        }
        Task { await notchPresenter.present(events: events) }
    }

    func openPullRequest(id: GitHubNodeID) {
        guard let url = pullRequests.first(where: { $0.id == id })?.url
            ?? retainedPinnedPullRequests[id]?.url
            ?? observedAuthoredPullRequests[id]?.url,
            url.scheme == "https",
            url.host?.lowercased() == "github.com"
        else { return }
        NSWorkspace.shared.open(url)
    }

    private func pollForAuthorization() async {
        while !Task.isCancelled {
            let interval = await github.nextDevicePollInterval()
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            do {
                let next = try await github.pollDeviceFlow()
                switch next {
                case .deviceFlowPending:
                    continue
                case .signedIn(let account):
                    authState = .signedIn(account)
                    statusMessage = "Connected as @\(account.login) via \(authenticationMethod.displayName)"
                    try await loadRepositoriesAndRefresh()
                    startRefreshLoop()
                    return
                case .needsReauthorization(let reason):
                    authState = next
                    errorMessage = reason
                    return
                case .signedOut:
                    authState = .signedOut
                    return
                }
            } catch {
                errorMessage = userFacing(error)
                return
            }
        }
    }

    private func loadRepositoriesAndRefresh() async throws {
        repositories = try await github.listRepositories()
        let available = Set(repositories.map(\.id))
        selectedRepositoryIDs = selectedRepositoryIDs.intersection(available)
        statusMessage = selectedRepositoryIDs.isEmpty
            ? "Select repositories to monitor"
            : "Loaded \(repositories.count) repositories"
        await performRefresh(silent: true)
    }

    private func performRefresh(silent: Bool) async {
        guard let account = signedInAccount else { return }
        let selected = repositories.filter { selectedRepositoryIDs.contains($0.id) }
        guard !selected.isEmpty else {
            pullRequests = []
            observedAuthoredPullRequests = [:]
            authoredPullRequestBaselinePending = true
            lastSuccessfulRefreshAt = nil
            statusMessage = "Select repositories to monitor"
            updateMenuBarSeverity()
            return
        }

        isRefreshing = true
        if !silent { statusMessage = "Refreshing from GitHub…" }
        defer { isRefreshing = false }
        do {
            var previous = Dictionary(uniqueKeysWithValues: pullRequests.map { ($0.id, $0) })
            for pinnedID in pinnedIDs {
                if let retained = retainedPinnedPullRequests[pinnedID] {
                    previous[pinnedID] = retained
                }
            }
            var result = try await github.fetchPullRequests(
                repositories: selected,
                filters: filters,
                login: account.login
            ).pullRequests
            let filterMatchedIDs = Set(result.map(\.id))

            var authoredPullRequests = result.filter {
                $0.authorLogin.caseInsensitiveCompare(account.login) == .orderedSame
            }
            if notificationsEnabled,
               newAuthoredPullRequestNotificationsEnabled,
               !filters.includeAllOpen,
               !filters.includeAuthoredByMe
            {
                let authoredOnly = PRFilterConfiguration(
                    includeAllOpen: false,
                    includeAuthoredByMe: true,
                    includeAssignedToMe: false,
                    includeReviewRequestedFromMe: false
                )
                authoredPullRequests = try await github.fetchPullRequests(
                    repositories: selected,
                    filters: authoredOnly,
                    login: account.login
                ).pullRequests
            }

            let idsToVerify = Set(previous.keys).union(pinnedIDs)
            var inaccessiblePinnedIDs: Set<GitHubNodeID> = []
            for missingID in idsToVerify where !result.contains(where: { $0.id == missingID }) {
                if let verified = try await github.lookupPullRequest(id: missingID) {
                    if PinPolicy.shouldMonitorVerifiedLookup(
                        verified,
                        isPinned: pinnedIDs.contains(missingID)
                    ) {
                        // Pins remain actively monitored even when a filter
                        // change removes them from the dashboard query.
                        result.append(verified)
                    }
                } else if pinnedIDs.contains(missingID) {
                    inaccessiblePinnedIDs.insert(missingID)
                }
            }
            if !inaccessiblePinnedIDs.isEmpty {
                pinnedIDs.removeAll { inaccessiblePinnedIDs.contains($0) }
                retainedPinnedPullRequests = retainedPinnedPullRequests.filter {
                    !inaccessiblePinnedIDs.contains($0.key)
                }
            }

            let now = Date()
            let stateEvents = detector.detectTransitions(
                previous: previous,
                current: result,
                baselineMode: baselinePending,
                observedAt: now
            )
            var authoredEvents: [TransitionEvent] = []
            if notificationsEnabled, newAuthoredPullRequestNotificationsEnabled {
                authoredEvents = detector.detectNewAuthoredPullRequests(
                    previouslyObserved: observedAuthoredPullRequests,
                    current: authoredPullRequests,
                    authenticatedLogin: account.login,
                    baselineMode: authoredPullRequestBaselinePending,
                    observedAt: now
                )
                for pullRequest in authoredPullRequests {
                    observedAuthoredPullRequests[pullRequest.id] = pullRequest
                }
                authoredPullRequestBaselinePending = false
            }
            let events = authoredEvents + stateEvents
            pinnedIDs = PinPolicy.removingTerminalPullRequests(
                from: pinnedIDs,
                pullRequests: result
            )
            pullRequests = result.filter {
                $0.lifecycleState == .open && filterMatchedIDs.contains($0.id)
            }
            retainedPinnedPullRequests = [:]
            for pullRequest in result {
                if pullRequest.lifecycleState == .closed || pullRequest.lifecycleState == .merged {
                    // Keep one refresh cycle of terminal metadata so clicking
                    // its transition notification can still open GitHub.
                    retainedPinnedPullRequests[pullRequest.id] = pullRequest
                } else if pinnedIDs.contains(pullRequest.id)
                    && !filterMatchedIDs.contains(pullRequest.id)
                {
                    retainedPinnedPullRequests[pullRequest.id] = pullRequest
                }
            }
            for pullRequest in pullRequests {
                retainedPinnedPullRequests[pullRequest.id] = nil
            }
            baselinePending = false
            lastSuccessfulRefreshAt = now
            statusMessage = "Updated \(now.formatted(date: .omitted, time: .shortened)) · \(pullRequests.count) open PRs"
            errorMessage = nil
            updateMenuBarSeverity()
            if !events.isEmpty { await deliver(events: events) }
        } catch {
            errorMessage = userFacing(error)
            statusMessage = "Refresh failed · showing last known status"
        }
    }

    private func deliver(events: [TransitionEvent]) async {
        guard notificationsEnabled else { return }
        if notchNotificationsEnabled { await notchPresenter.present(events: events) }
        if systemNotificationsEnabled {
            for event in events { await systemPresenter.present(event: event) }
        }
        if soundEnabled { NSSound(named: "Glass")?.play() }
    }

    private func startRefreshLoop() {
        refreshLoopTask?.cancel()
        refreshLoopTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                self?.refresh(silent: true)
            }
        }
    }

    private func connectGitHubCLI() {
        authPollingTask?.cancel()
        authPollingTask = Task {
            await github.configureAuthenticationMethod(.githubCLI)
            do {
                guard let account = try await github.restoreSession() else {
                    throw GitPingsError.notAuthenticated
                }
                UserDefaults.standard.set(true, forKey: Keys.githubCLIConnected)
                authState = .signedIn(account)
                statusMessage = "Connected as @\(account.login) via Local GitHub CLI"
                try await loadRepositoriesAndRefresh()
                startRefreshLoop()
            } catch {
                authState = .needsReauthorization(reason: userFacing(error))
                errorMessage = userFacing(error)
                statusMessage = "GitHub CLI needs attention"
            }
        }
    }

    private func setAuthenticationMethod(_ method: GitHubAuthenticationMethod) {
        authenticationMethod = method
        UserDefaults.standard.set(method.rawValue, forKey: Keys.authenticationMethod)
    }

    private func clearLocalGitHubState(status: String) {
        authPollingTask?.cancel()
        refreshLoopTask?.cancel()
        authState = .signedOut
        repositories = []
        selectedRepositoryIDs = []
        pullRequests = []
        pinnedIDs = []
        retainedPinnedPullRequests = [:]
        observedAuthoredPullRequests = [:]
        authoredPullRequestBaselinePending = true
        baselinePending = true
        lastSuccessfulRefreshAt = nil
        menuBarSeverity = .neutral
        statusMessage = status
    }

    private func updateMenuBarSeverity() {
        menuBarSeverity = MenuBarSeverityCalculator.severity(for: pinnedPullRequests)
    }

    private func persistSelectedRepositories() {
        UserDefaults.standard.set(selectedRepositoryIDs.map(\.rawValue).sorted(), forKey: Keys.selectedRepositories)
    }

    private func persistPins() {
        UserDefaults.standard.set(pinnedIDs.map(\.rawValue), forKey: Keys.pins)
    }

    private func persistFilters() {
        if let data = try? JSONEncoder().encode(filters) {
            UserDefaults.standard.set(data, forKey: Keys.filters)
        }
    }

    private func userFacing(_ error: Error) -> String {
        switch error {
        case GitPingsError.notAuthenticated: return "Sign in to GitHub again."
        case GitPingsError.reauthorizationRequired(let reason): return reason
        case GitPingsError.rateLimited(let retry):
            return retry.map { "GitHub rate limit reached. Try again in \(Int($0)) seconds." }
                ?? "GitHub rate limit reached. Try again later."
        case GitPingsError.networkUnavailable: return "GitHub could not be reached. Check your connection."
        case GitPingsError.partialData(let message): return message
        case GitPingsError.pinLimitReached: return "You can pin up to five pull requests."
        case GitPingsError.unsupportedConfiguration(let message): return message
        default: return error.localizedDescription
        }
    }

    private enum Keys {
        static let authenticationMethod = "GitPings.authenticationMethod"
        static let githubCLIConnected = "GitPings.githubCLIConnected"
        static let legacyActiveGitHubAccountID = "GitPings.activeGitHubAccountID"
        static let oauthClientID = "GitPings.oauthClientID"
        static let selectedRepositories = "GitPings.selectedRepositories"
        static let pins = "GitPings.pins"
        static let filters = "GitPings.filters"
        static let notificationsEnabled = "GitPings.notifications.enabled"
        static let newAuthoredPullRequestNotificationsEnabled = "GitPings.notifications.newAuthoredPullRequest"
        static let notchEnabled = "GitPings.notifications.notch"
        static let systemEnabled = "GitPings.notifications.system"
        static let soundEnabled = "GitPings.notifications.sound"
    }
}

@MainActor
final class AppDependencyContainer {
    let appModel: AppModel

    init(appModel: AppModel = AppModel()) {
        self.appModel = appModel
    }

    static func bootstrap() -> AppDependencyContainer { AppDependencyContainer() }
}
