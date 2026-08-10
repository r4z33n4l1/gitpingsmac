import Foundation

/// In-memory, process-local queue for notch notifications. Events for the same
/// PR are coalesced into one presentation while distinct PRs remain ordered.
struct NotchEventQueue: Sendable {
    private(set) var groups: [[TransitionEvent]] = []

    var count: Int { groups.count }
    var isEmpty: Bool { groups.isEmpty }

    mutating func enqueue(
        _ events: [TransitionEvent],
        excluding visibleEvents: [TransitionEvent] = []
    ) {
        var signatures = Set(visibleEvents.map(EventSignature.init))
        signatures.formUnion(groups.flatMap { $0 }.map(EventSignature.init))

        for event in events {
            guard signatures.insert(EventSignature(event)).inserted else { continue }
            if let index = groups.firstIndex(where: { $0.first?.pullRequestID == event.pullRequestID }) {
                groups[index].append(event)
            } else {
                groups.append([event])
            }
        }
    }

    mutating func popFirst() -> [TransitionEvent]? {
        guard !groups.isEmpty else { return nil }
        return groups.removeFirst()
    }

    mutating func removeAll() {
        groups.removeAll(keepingCapacity: false)
    }
}

private struct EventSignature: Hashable, Sendable {
    let pullRequestID: GitHubNodeID
    let kind: TransitionEventKind
    let newValue: String

    init(_ event: TransitionEvent) {
        pullRequestID = event.pullRequestID
        kind = event.kind
        newValue = event.newValue
    }
}
