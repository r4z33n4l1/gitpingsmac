import Foundation

public actor InMemoryPreferencesStore: PreferencesStore {
    private var selectedIDs: [GitHubNodeID]
    private var filters: PRFilterConfiguration

    public init(
        selectedIDs: [GitHubNodeID] = [],
        filters: PRFilterConfiguration = .mvpDefault
    ) {
        self.selectedIDs = selectedIDs
        self.filters = filters
    }

    public func selectedRepositoryIDs() async throws -> [GitHubNodeID] {
        selectedIDs
    }

    public func setSelectedRepositoryIDs(_ ids: [GitHubNodeID]) async throws {
        var seen = Set<GitHubNodeID>()
        selectedIDs = ids.filter { seen.insert($0).inserted }
    }

    public func filterConfiguration() async throws -> PRFilterConfiguration {
        filters
    }

    public func setFilterConfiguration(_ configuration: PRFilterConfiguration) async throws {
        filters = configuration
    }
}
