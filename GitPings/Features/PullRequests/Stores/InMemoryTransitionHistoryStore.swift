import Foundation

public actor InMemoryTransitionHistoryStore: TransitionHistoryStore {
    private var events: [TransitionEvent] = []

    public init(events: [TransitionEvent] = []) {
        self.events = events
    }

    public func recentEvents(limit: Int) async throws -> [TransitionEvent] {
        let capped = max(0, limit)
        return Array(events.suffix(capped).reversed())
    }

    public func append(_ event: TransitionEvent) async throws {
        events.append(event)
        try await prune(
            retainingNewest: TransitionHistoryRetention.maximumEventCount,
            olderThan: event.observedAt.addingTimeInterval(-TransitionHistoryRetention.maximumAge)
        )
    }

    public func prune(retainingNewest newest: Int, olderThan cutoff: Date) async throws {
        events.removeAll { $0.observedAt < cutoff }
        if newest <= 0 {
            events.removeAll()
            return
        }
        if events.count > newest {
            events = Array(events.suffix(newest))
        }
    }

    /// Test helper: total stored count after pruning.
    public func count() -> Int { events.count }
}
