import Foundation
import Observation

/// UI-facing store sketch for dashboard/menu-bar consumers.
/// Owns presentation cache only; durable writes go through Domain store protocols.
@MainActor
@Observable
public final class PullRequestMonitorStore {
    public private(set) var pullRequests: [PullRequestSummary] = []
    public private(set) var pinnedIDs: [GitHubNodeID] = []
    public private(set) var lastSuccessfulRefreshAt: Date?
    public private(set) var isBaselinePending: Bool = true
    public private(set) var menuBarSeverity: MenuBarSeverity = .neutral

    public init() {}

    public var pinnedPullRequests: [PullRequestSummary] {
        pinnedIDs.compactMap { id in pullRequests.first(where: { $0.id == id }) }
    }

    public func applyCache(
        pullRequests: [PullRequestSummary],
        pinnedIDs: [GitHubNodeID],
        refreshedAt: Date?,
        baselinePending: Bool
    ) {
        self.pullRequests = pullRequests
        self.pinnedIDs = Array(pinnedIDs.prefix(PinPolicy.maximumPinCount))
        self.lastSuccessfulRefreshAt = refreshedAt
        self.isBaselinePending = baselinePending
        self.menuBarSeverity = MenuBarSeverityCalculator.severity(for: pinnedPullRequests)
    }
}
