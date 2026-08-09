import Foundation

/// Pure transition detection (ADR-003 / CHANGE-*).
///
/// Rules:
/// - `baselineMode == true` → no events (initial sync / new repo / new filter).
/// - Absence from `current` never emits closed/merged (CHANGE-3A). Callers must
///   run targeted lookup and include verified terminal rows in `current` first.
/// - Same normalized CI/merge values → no event (CHANGE-4/5).
/// - Same-cycle duplicate (kind + newValue) for one PR is coalesced to one event.
/// - Unknown is a first-class state and never rewritten to passing/mergeable.
public struct TransitionDetector: TransitionDetecting, Sendable {
    public init() {}

    public func detectTransitions(
        previous: [GitHubNodeID: PullRequestSummary],
        current: [PullRequestSummary],
        baselineMode: Bool,
        observedAt: Date
    ) -> [TransitionEvent] {
        if baselineMode { return [] }

        var emitted: [TransitionEvent] = []
        var seenKeys = Set<DedupeKey>()

        for pr in current {
            guard let prior = previous[pr.id] else {
                // Newly appeared PR after baseline already established: treat as
                // silent include (new filter match) — no historical burst.
                continue
            }

            if prior.ciState != pr.ciState {
                appendIfNew(
                    TransitionEvent(
                        pullRequestID: pr.id,
                        repositoryNameWithOwner: pr.repositoryNameWithOwner,
                        number: pr.number,
                        title: pr.title,
                        kind: .ciChanged,
                        oldValue: prior.ciState.rawValue,
                        newValue: pr.ciState.rawValue,
                        observedAt: observedAt
                    ),
                    into: &emitted,
                    seen: &seenKeys
                )
            }

            if prior.mergeState != pr.mergeState {
                appendIfNew(
                    TransitionEvent(
                        pullRequestID: pr.id,
                        repositoryNameWithOwner: pr.repositoryNameWithOwner,
                        number: pr.number,
                        title: pr.title,
                        kind: .mergeChanged,
                        oldValue: prior.mergeState.rawValue,
                        newValue: pr.mergeState.rawValue,
                        observedAt: observedAt
                    ),
                    into: &emitted,
                    seen: &seenKeys
                )
            }

            if shouldEmitClosedOrMerged(previous: prior.lifecycleState, current: pr.lifecycleState) {
                appendIfNew(
                    TransitionEvent(
                        pullRequestID: pr.id,
                        repositoryNameWithOwner: pr.repositoryNameWithOwner,
                        number: pr.number,
                        title: pr.title,
                        kind: .closedOrMerged,
                        oldValue: prior.lifecycleState.rawValue,
                        newValue: pr.lifecycleState.rawValue,
                        observedAt: observedAt
                    ),
                    into: &emitted,
                    seen: &seenKeys
                )
            }
        }

        // Intentionally ignore IDs present only in `previous`.
        // Search absence is not a terminal transition (CHANGE-3A).
        return emitted
    }

    private func shouldEmitClosedOrMerged(
        previous: PullRequestLifecycleState,
        current: PullRequestLifecycleState
    ) -> Bool {
        guard previous != current else { return false }
        switch current {
        case .closed, .merged:
            return previous == .open || previous == .unknown
        case .open, .unknown:
            return false
        }
    }

    private func appendIfNew(
        _ event: TransitionEvent,
        into events: inout [TransitionEvent],
        seen: inout Set<DedupeKey>
    ) {
        let key = DedupeKey(
            pullRequestID: event.pullRequestID,
            kind: event.kind,
            newValue: event.newValue
        )
        guard seen.insert(key).inserted else { return }
        events.append(event)
    }

    private struct DedupeKey: Hashable {
        var pullRequestID: GitHubNodeID
        var kind: TransitionEventKind
        var newValue: String
    }
}

/// Groups same-cycle events per PR for human-readable notification coalescing.
public enum TransitionCoalescing {
    public static func groupByPullRequest(_ events: [TransitionEvent]) -> [[TransitionEvent]] {
        var order: [GitHubNodeID] = []
        var buckets: [GitHubNodeID: [TransitionEvent]] = [:]
        for event in events {
            if buckets[event.pullRequestID] == nil {
                order.append(event.pullRequestID)
                buckets[event.pullRequestID] = []
            }
            buckets[event.pullRequestID]?.append(event)
        }
        return order.compactMap { buckets[$0] }
    }
}
