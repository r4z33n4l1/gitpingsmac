import Foundation

/// Deterministic `PinStore` sketch enforcing PIN-3/PIN-4 (max five, no silent eviction).
public actor InMemoryPinStore: PinStore {
    private var orderedIDs: [GitHubNodeID] = []

    public init(initial: [GitHubNodeID] = []) {
        orderedIDs = Array(initial.prefix(PinPolicy.maximumPinCount))
    }

    public func pinnedIDs() async throws -> [GitHubNodeID] {
        orderedIDs
    }

    public func pin(_ id: GitHubNodeID) async throws {
        if orderedIDs.contains(id) { return }
        guard PinPolicy.canPin(currentCount: orderedIDs.count) else {
            throw GitPingsError.pinLimitReached
        }
        orderedIDs.append(id)
    }

    public func unpin(_ id: GitHubNodeID) async throws {
        orderedIDs.removeAll { $0 == id }
    }

    public func reorder(to orderedIDs: [GitHubNodeID]) async throws {
        let unique = Self.deduplicated(orderedIDs)
        guard unique.count == orderedIDs.count else {
            throw GitPingsError.unsupportedConfiguration("Pin reorder contains duplicates")
        }
        guard Set(unique) == Set(self.orderedIDs) else {
            throw GitPingsError.unsupportedConfiguration("Pin reorder must contain exactly the current pin set")
        }
        guard unique.count <= PinPolicy.maximumPinCount else {
            throw GitPingsError.pinLimitReached
        }
        self.orderedIDs = unique
    }

    public func replace(existing: GitHubNodeID, with replacement: GitHubNodeID) async throws {
        guard let index = orderedIDs.firstIndex(of: existing) else {
            throw GitPingsError.unsupportedConfiguration("Replacement source pin is not pinned")
        }
        if existing == replacement { return }
        if let other = orderedIDs.firstIndex(of: replacement), other != index {
            throw GitPingsError.unsupportedConfiguration("Replacement pin is already pinned")
        }
        orderedIDs[index] = replacement
    }

    private static func deduplicated(_ ids: [GitHubNodeID]) -> [GitHubNodeID] {
        var seen = Set<GitHubNodeID>()
        var result: [GitHubNodeID] = []
        for id in ids where seen.insert(id).inserted {
            result.append(id)
        }
        return result
    }
}
