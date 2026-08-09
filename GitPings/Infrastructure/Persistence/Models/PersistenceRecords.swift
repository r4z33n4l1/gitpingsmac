import Foundation

#if canImport(SwiftData)
import SwiftData
#endif

// MARK: - Codable schema drafts (fixture / documentation surface)

/// Schema v1 account metadata. Tokens are never stored here.
public struct AccountMetadataDraft: Hashable, Sendable, Codable {
    public var accountNodeID: String
    public var login: String
    public var installationCount: Int
    public var updatedAt: Date

    public init(
        accountNodeID: String,
        login: String,
        installationCount: Int = 0,
        updatedAt: Date
    ) {
        self.accountNodeID = accountNodeID
        self.login = login
        self.installationCount = installationCount
        self.updatedAt = updatedAt
    }
}

public struct SelectedRepositoryDraft: Hashable, Sendable, Codable {
    public var repositoryNodeID: String
    public var nameWithOwner: String
    public var visibility: String
    public var isOrganizationOwned: Bool
    public var selectedAt: Date

    public init(
        repositoryNodeID: String,
        nameWithOwner: String,
        visibility: String,
        isOrganizationOwned: Bool,
        selectedAt: Date
    ) {
        self.repositoryNodeID = repositoryNodeID
        self.nameWithOwner = nameWithOwner
        self.visibility = visibility
        self.isOrganizationOwned = isOrganizationOwned
        self.selectedAt = selectedAt
    }
}

public struct FilterConfigurationDraft: Hashable, Sendable, Codable {
    public var includeAllOpen: Bool
    public var includeAuthoredByMe: Bool
    public var includeAssignedToMe: Bool
    public var includeReviewRequestedFromMe: Bool

    public init(from configuration: PRFilterConfiguration) {
        includeAllOpen = configuration.includeAllOpen
        includeAuthoredByMe = configuration.includeAuthoredByMe
        includeAssignedToMe = configuration.includeAssignedToMe
        includeReviewRequestedFromMe = configuration.includeReviewRequestedFromMe
    }

    public func asDomain() -> PRFilterConfiguration {
        PRFilterConfiguration(
            includeAllOpen: includeAllOpen,
            includeAuthoredByMe: includeAuthoredByMe,
            includeAssignedToMe: includeAssignedToMe,
            includeReviewRequestedFromMe: includeReviewRequestedFromMe
        )
    }
}

public struct PinDraft: Hashable, Sendable, Codable {
    public var pullRequestNodeID: String
    public var sortIndex: Int
    public var pinnedAt: Date

    public init(pullRequestNodeID: String, sortIndex: Int, pinnedAt: Date) {
        self.pullRequestNodeID = pullRequestNodeID
        self.sortIndex = sortIndex
        self.pinnedAt = pinnedAt
    }
}

/// Normalized PR row shared by cache and snapshot tables.
public struct PersistedPullRequestDraft: Hashable, Sendable, Codable {
    public var pullRequestNodeID: String
    public var repositoryNodeID: String
    public var repositoryNameWithOwner: String
    public var number: Int
    public var title: String
    public var url: URL
    public var authorLogin: String
    public var lifecycleState: String
    public var headRefName: String
    public var baseRefName: String
    public var ciState: String
    public var mergeState: String
    public var updatedAt: Date
    public var lastSuccessfulRefreshAt: Date?

    public init(from summary: PullRequestSummary) {
        pullRequestNodeID = summary.id.rawValue
        repositoryNodeID = summary.repositoryID.rawValue
        repositoryNameWithOwner = summary.repositoryNameWithOwner
        number = summary.number
        title = summary.title
        url = summary.url
        authorLogin = summary.authorLogin
        lifecycleState = summary.lifecycleState.rawValue
        headRefName = summary.headRefName
        baseRefName = summary.baseRefName
        ciState = summary.ciState.rawValue
        mergeState = summary.mergeState.rawValue
        updatedAt = summary.updatedAt
        lastSuccessfulRefreshAt = summary.lastSuccessfulRefreshAt
    }

    public func asDomain() -> PullRequestSummary? {
        guard
            let lifecycle = PullRequestLifecycleState(rawValue: lifecycleState),
            let ci = CIState(rawValue: ciState),
            let merge = MergeState(rawValue: mergeState)
        else {
            return nil
        }
        return PullRequestSummary(
            id: GitHubNodeID(pullRequestNodeID),
            repositoryID: GitHubNodeID(repositoryNodeID),
            repositoryNameWithOwner: repositoryNameWithOwner,
            number: number,
            title: title,
            url: url,
            authorLogin: authorLogin,
            lifecycleState: lifecycle,
            headRefName: headRefName,
            baseRefName: baseRefName,
            ciState: ci,
            mergeState: merge,
            updatedAt: updatedAt,
            lastSuccessfulRefreshAt: lastSuccessfulRefreshAt
        )
    }
}

public struct AppSettingsDraft: Hashable, Sendable, Codable {
    public var notificationsMasterEnabled: Bool
    public var notifyCI: Bool
    public var notifyMerge: Bool
    public var notifyClosedOrMerged: Bool
    public var channelNotch: Bool
    public var channelSystem: Bool
    public var channelSound: Bool
    public var suppressInFullScreen: Bool
    public var desiredRefreshIntervalSeconds: Int
    public var updatedAt: Date

    public static func mvpDefaults(at date: Date) -> AppSettingsDraft {
        AppSettingsDraft(
            notificationsMasterEnabled: true,
            notifyCI: true,
            notifyMerge: true,
            notifyClosedOrMerged: true,
            channelNotch: true,
            channelSystem: false,
            channelSound: false,
            suppressInFullScreen: true,
            desiredRefreshIntervalSeconds: 60,
            updatedAt: date
        )
    }

    public init(
        notificationsMasterEnabled: Bool,
        notifyCI: Bool,
        notifyMerge: Bool,
        notifyClosedOrMerged: Bool,
        channelNotch: Bool,
        channelSystem: Bool,
        channelSound: Bool,
        suppressInFullScreen: Bool,
        desiredRefreshIntervalSeconds: Int,
        updatedAt: Date
    ) {
        self.notificationsMasterEnabled = notificationsMasterEnabled
        self.notifyCI = notifyCI
        self.notifyMerge = notifyMerge
        self.notifyClosedOrMerged = notifyClosedOrMerged
        self.channelNotch = channelNotch
        self.channelSystem = channelSystem
        self.channelSound = channelSound
        self.suppressInFullScreen = suppressInFullScreen
        self.desiredRefreshIntervalSeconds = desiredRefreshIntervalSeconds
        self.updatedAt = updatedAt
    }
}

public struct TransitionHistoryDraft: Hashable, Sendable, Codable {
    public var eventID: UUID
    public var pullRequestNodeID: String
    public var repositoryNameWithOwner: String
    public var number: Int
    public var title: String
    public var kind: String
    public var oldValue: String
    public var newValue: String
    public var observedAt: Date

    public init(from event: TransitionEvent) {
        eventID = event.id
        pullRequestNodeID = event.pullRequestID.rawValue
        repositoryNameWithOwner = event.repositoryNameWithOwner
        number = event.number
        title = event.title
        kind = event.kind.rawValue
        oldValue = event.oldValue
        newValue = event.newValue
        observedAt = event.observedAt
    }

    public func asDomain() -> TransitionEvent? {
        guard let kind = TransitionEventKind(rawValue: kind) else { return nil }
        return TransitionEvent(
            id: eventID,
            pullRequestID: GitHubNodeID(pullRequestNodeID),
            repositoryNameWithOwner: repositoryNameWithOwner,
            number: number,
            title: title,
            kind: kind,
            oldValue: oldValue,
            newValue: newValue,
            observedAt: observedAt
        )
    }
}

// MARK: - SwiftData @Model drafts (macOS runtime)

#if canImport(SwiftData)

@Model
public final class AccountMetadataRecord {
    @Attribute(.unique) public var accountNodeID: String
    public var login: String
    public var installationCount: Int
    public var updatedAt: Date

    public init(accountNodeID: String, login: String, installationCount: Int = 0, updatedAt: Date) {
        self.accountNodeID = accountNodeID
        self.login = login
        self.installationCount = installationCount
        self.updatedAt = updatedAt
    }
}

@Model
public final class SelectedRepositoryRecord {
    @Attribute(.unique) public var repositoryNodeID: String
    public var nameWithOwner: String
    public var visibility: String
    public var isOrganizationOwned: Bool
    public var selectedAt: Date

    public init(
        repositoryNodeID: String,
        nameWithOwner: String,
        visibility: String,
        isOrganizationOwned: Bool,
        selectedAt: Date
    ) {
        self.repositoryNodeID = repositoryNodeID
        self.nameWithOwner = nameWithOwner
        self.visibility = visibility
        self.isOrganizationOwned = isOrganizationOwned
        self.selectedAt = selectedAt
    }
}

@Model
public final class FilterConfigurationRecord {
    @Attribute(.unique) public var singletonID: String
    public var includeAllOpen: Bool
    public var includeAuthoredByMe: Bool
    public var includeAssignedToMe: Bool
    public var includeReviewRequestedFromMe: Bool

    public init(from configuration: PRFilterConfiguration) {
        singletonID = "filters"
        includeAllOpen = configuration.includeAllOpen
        includeAuthoredByMe = configuration.includeAuthoredByMe
        includeAssignedToMe = configuration.includeAssignedToMe
        includeReviewRequestedFromMe = configuration.includeReviewRequestedFromMe
    }
}

@Model
public final class PinRecord {
    @Attribute(.unique) public var pullRequestNodeID: String
    public var sortIndex: Int
    public var pinnedAt: Date

    public init(pullRequestNodeID: String, sortIndex: Int, pinnedAt: Date) {
        self.pullRequestNodeID = pullRequestNodeID
        self.sortIndex = sortIndex
        self.pinnedAt = pinnedAt
    }
}

@Model
public final class CachedPullRequestRecord {
    @Attribute(.unique) public var pullRequestNodeID: String
    public var repositoryNodeID: String
    public var repositoryNameWithOwner: String
    public var number: Int
    public var title: String
    public var urlString: String
    public var authorLogin: String
    public var lifecycleState: String
    public var headRefName: String
    public var baseRefName: String
    public var ciState: String
    public var mergeState: String
    public var updatedAt: Date
    public var lastSuccessfulRefreshAt: Date?

    public init(from summary: PullRequestSummary) {
        pullRequestNodeID = summary.id.rawValue
        repositoryNodeID = summary.repositoryID.rawValue
        repositoryNameWithOwner = summary.repositoryNameWithOwner
        number = summary.number
        title = summary.title
        urlString = summary.url.absoluteString
        authorLogin = summary.authorLogin
        lifecycleState = summary.lifecycleState.rawValue
        headRefName = summary.headRefName
        baseRefName = summary.baseRefName
        ciState = summary.ciState.rawValue
        mergeState = summary.mergeState.rawValue
        updatedAt = summary.updatedAt
        lastSuccessfulRefreshAt = summary.lastSuccessfulRefreshAt
    }
}

@Model
public final class NormalizedSnapshotRecord {
    @Attribute(.unique) public var pullRequestNodeID: String
    public var repositoryNodeID: String
    public var repositoryNameWithOwner: String
    public var number: Int
    public var title: String
    public var urlString: String
    public var authorLogin: String
    public var lifecycleState: String
    public var headRefName: String
    public var baseRefName: String
    public var ciState: String
    public var mergeState: String
    public var updatedAt: Date
    public var lastSuccessfulRefreshAt: Date?

    public init(from summary: PullRequestSummary) {
        pullRequestNodeID = summary.id.rawValue
        repositoryNodeID = summary.repositoryID.rawValue
        repositoryNameWithOwner = summary.repositoryNameWithOwner
        number = summary.number
        title = summary.title
        urlString = summary.url.absoluteString
        authorLogin = summary.authorLogin
        lifecycleState = summary.lifecycleState.rawValue
        headRefName = summary.headRefName
        baseRefName = summary.baseRefName
        ciState = summary.ciState.rawValue
        mergeState = summary.mergeState.rawValue
        updatedAt = summary.updatedAt
        lastSuccessfulRefreshAt = summary.lastSuccessfulRefreshAt
    }
}

@Model
public final class AppSettingsRecord {
    @Attribute(.unique) public var singletonID: String
    public var notificationsMasterEnabled: Bool
    public var notifyCI: Bool
    public var notifyMerge: Bool
    public var notifyClosedOrMerged: Bool
    public var channelNotch: Bool
    public var channelSystem: Bool
    public var channelSound: Bool
    public var suppressInFullScreen: Bool
    public var desiredRefreshIntervalSeconds: Int
    public var updatedAt: Date

    public init(draft: AppSettingsDraft) {
        singletonID = "settings"
        notificationsMasterEnabled = draft.notificationsMasterEnabled
        notifyCI = draft.notifyCI
        notifyMerge = draft.notifyMerge
        notifyClosedOrMerged = draft.notifyClosedOrMerged
        channelNotch = draft.channelNotch
        channelSystem = draft.channelSystem
        channelSound = draft.channelSound
        suppressInFullScreen = draft.suppressInFullScreen
        desiredRefreshIntervalSeconds = draft.desiredRefreshIntervalSeconds
        updatedAt = draft.updatedAt
    }
}

@Model
public final class TransitionHistoryRecord {
    @Attribute(.unique) public var eventID: UUID
    public var pullRequestNodeID: String
    public var repositoryNameWithOwner: String
    public var number: Int
    public var title: String
    public var kind: String
    public var oldValue: String
    public var newValue: String
    public var observedAt: Date

    public init(from event: TransitionEvent) {
        eventID = event.id
        pullRequestNodeID = event.pullRequestID.rawValue
        repositoryNameWithOwner = event.repositoryNameWithOwner
        number = event.number
        title = event.title
        kind = event.kind.rawValue
        oldValue = event.oldValue
        newValue = event.newValue
        observedAt = event.observedAt
    }
}

#endif
