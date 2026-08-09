import Foundation

/// One GitHub search-syntax query produced for a single enabled filter dimension.
public struct CompiledSearchQuery: Hashable, Sendable {
    public enum Dimension: String, Hashable, Sendable {
        case allOpen
        case authoredByMe
        case assignedToMe
        case reviewRequestedFromMe
    }

    public var dimension: Dimension
    public var query: String
    /// Zero-based shard index when selected repos are split for query-length safety.
    public var repositoryShardIndex: Int

    public init(dimension: Dimension, query: String, repositoryShardIndex: Int = 0) {
        self.dimension = dimension
        self.query = query
        self.repositoryShardIndex = repositoryShardIndex
    }
}

/// Maps `PRFilterConfiguration` + login + selected repos to GitHub search qualifiers (FILTER-1..5).
/// Multiple enabled filters become **separate** queries (OR semantics); callers merge by PR node ID.
public enum FilterQueryCompiler {
    /// Soft cap to keep `repo:` lists inside GitHub search query length limits.
    public static let defaultRepositoriesPerShard = 20

    public static func compile(
        filters: PRFilterConfiguration,
        authenticatedLogin: String,
        repositories: [RepositorySummary],
        repositoriesPerShard: Int = defaultRepositoriesPerShard
    ) -> [CompiledSearchQuery] {
        let login = authenticatedLogin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !login.isEmpty else { return [] }
        guard !repositories.isEmpty else { return [] }
        guard repositoriesPerShard > 0 else { return [] }

        let repoNames = repositories.map(\.nameWithOwner).filter { !$0.isEmpty }
        guard !repoNames.isEmpty else { return [] }

        let shards = shard(repoNames, size: repositoriesPerShard)
        var compiled: [CompiledSearchQuery] = []

        // When "all open" is enabled it already covers every open PR in selected repos;
        // skip redundant actor-scoped queries to control GraphQL cost.
        if filters.includeAllOpen {
            for (index, shard) in shards.enumerated() {
                compiled.append(
                    CompiledSearchQuery(
                        dimension: .allOpen,
                        query: baseQuery(repoShard: shard, actorQualifier: nil),
                        repositoryShardIndex: index
                    )
                )
            }
            return compiled
        }

        if filters.includeAuthoredByMe {
            appendDimension(
                .authoredByMe,
                actorQualifier: "author:\(login)",
                shards: shards,
                into: &compiled
            )
        }
        if filters.includeAssignedToMe {
            appendDimension(
                .assignedToMe,
                actorQualifier: "assignee:\(login)",
                shards: shards,
                into: &compiled
            )
        }
        if filters.includeReviewRequestedFromMe {
            appendDimension(
                .reviewRequestedFromMe,
                actorQualifier: "review-requested:\(login)",
                shards: shards,
                into: &compiled
            )
        }

        return compiled
    }

    private static func appendDimension(
        _ dimension: CompiledSearchQuery.Dimension,
        actorQualifier: String,
        shards: [[String]],
        into compiled: inout [CompiledSearchQuery]
    ) {
        for (index, shard) in shards.enumerated() {
            compiled.append(
                CompiledSearchQuery(
                    dimension: dimension,
                    query: baseQuery(repoShard: shard, actorQualifier: actorQualifier),
                    repositoryShardIndex: index
                )
            )
        }
    }

    /// Base: open pull requests in selected repositories (+ optional actor qualifier).
    private static func baseQuery(repoShard: [String], actorQualifier: String?) -> String {
        var parts = ["is:pr", "is:open"]
        parts.append(contentsOf: repoShard.map { "repo:\($0)" })
        if let actorQualifier {
            parts.append(actorQualifier)
        }
        return parts.joined(separator: " ")
    }

    private static func shard(_ values: [String], size: Int) -> [[String]] {
        guard size > 0, !values.isEmpty else { return [] }
        var result: [[String]] = []
        var index = 0
        while index < values.count {
            let end = min(index + size, values.count)
            result.append(Array(values[index..<end]))
            index = end
        }
        return result
    }
}
