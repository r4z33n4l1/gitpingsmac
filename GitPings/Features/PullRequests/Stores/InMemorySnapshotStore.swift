import Foundation

public actor InMemorySnapshotStore: SnapshotStore {
    private var snapshots: [GitHubNodeID: PullRequestSummary] = [:]

    public init(snapshots: [GitHubNodeID: PullRequestSummary] = [:]) {
        self.snapshots = snapshots
    }

    public func lastNormalizedSnapshots() async throws -> [GitHubNodeID: PullRequestSummary] {
        snapshots
    }

    public func saveNormalizedSnapshots(_ snapshots: [GitHubNodeID: PullRequestSummary]) async throws {
        self.snapshots = snapshots
    }
}
