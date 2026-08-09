import Foundation

/// Pure normalization from GitHub GraphQL enums/strings → Domain states (PR-9, ADR-002).
/// Unknown or missing data never maps to passing or mergeable.
public enum GitHubStateMapping {
    public enum MergeableGitHub: String, Sendable {
        case mergeable = "MERGEABLE"
        case conflicting = "CONFLICTING"
        case unknown = "UNKNOWN"
    }

    public enum MergeStateStatusGitHub: String, Sendable {
        case clean = "CLEAN"
        case dirty = "DIRTY"
        case blocked = "BLOCKED"
        case unstable = "UNSTABLE"
        case hasHooks = "HAS_HOOKS"
        case unknown = "UNKNOWN"
        case draft = "DRAFT"
    }

    public enum StatusRollupGitHub: String, Sendable {
        case success = "SUCCESS"
        case pending = "PENDING"
        case failure = "FAILURE"
        case expected = "EXPECTED"
        case error = "ERROR"
    }

    /// Map status check rollup. `contextCount == 0` with nil/missing state → noChecks when explicit;
    /// unrecognized strings → unknown.
    public static func ciState(
        rollupState: String?,
        contextCount: Int?
    ) -> CIState {
        guard let rollupState else {
            if let contextCount, contextCount == 0 {
                return .noChecks
            }
            // Absent rollup without a clear empty-context signal is unknown, not passing.
            return .unknown
        }

        switch StatusRollupGitHub(rawValue: rollupState.uppercased()) {
        case .success:
            return .passing
        case .pending, .expected:
            return .pending
        case .failure, .error:
            return .failing
        case .none:
            return .unknown
        }
    }

    /// Combine `mergeable` + `mergeStateStatus`.
    /// - `UNKNOWN` mergeable → `.checking` when `isFreshCalculation`, else `.unknown`.
    /// - `BLOCKED` status wins over technical MERGEABLE.
    /// - Dirty/conflicting → `.conflicting` regardless of CI.
    public static func mergeState(
        mergeable: String?,
        mergeStateStatus: String?,
        isFreshCalculation: Bool
    ) -> MergeState {
        let mergeableValue = mergeable.flatMap { MergeableGitHub(rawValue: $0.uppercased()) }
        let statusValue = mergeStateStatus.flatMap { MergeStateStatusGitHub(rawValue: $0.uppercased()) }

        if mergeable == nil && mergeStateStatus == nil {
            return .unknown
        }

        if let mergeable, MergeableGitHub(rawValue: mergeable.uppercased()) == nil {
            return .unknown
        }
        if let mergeStateStatus, MergeStateStatusGitHub(rawValue: mergeStateStatus.uppercased()) == nil {
            return .unknown
        }

        if mergeableValue == .conflicting || statusValue == .dirty {
            return .conflicting
        }

        if statusValue == .blocked {
            return .blocked
        }

        if mergeableValue == .unknown {
            return isFreshCalculation ? .checking : .unknown
        }

        if mergeableValue == .mergeable {
            switch statusValue {
            case .clean, .unstable, .hasHooks, .draft, .none:
                // UNSTABLE often means non-required checks failed; MVP keeps mergeability
                // independent of CI, so treat as mergeable when not blocked/dirty.
                return .mergeable
            case .blocked:
                return .blocked
            case .dirty:
                return .conflicting
            case .unknown:
                return isFreshCalculation ? .checking : .unknown
            }
        }

        return .unknown
    }

    public static func lifecycleState(state: String?, merged: Bool?) -> PullRequestLifecycleState {
        if merged == true { return .merged }
        guard let state else { return .unknown }
        switch state.uppercased() {
        case "OPEN":
            return .open
        case "CLOSED":
            return .closed
        case "MERGED":
            return .merged
        default:
            return .unknown
        }
    }
}
