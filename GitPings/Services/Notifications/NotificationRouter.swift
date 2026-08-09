import Foundation

/// Routes transition events to enabled channels (ADR-003 / NOTIFY-*).
/// Test notifications never enter transition history.
public actor NotificationRouter: NotificationRouting {
    private var preferences: NotificationPreferences
    private let notch: (any NotchPresenting)?
    private let system: (any SystemNotificationPresenting)?
    private let history: (any TransitionHistoryStore)?

    /// Captured deliveries for deterministic unit tests (no UI required).
    private(set) var delivered: [NotificationDelivery] = []
    private(set) var testDeliveryCount: Int = 0

    public init(
        preferences: NotificationPreferences = .mvpTesting,
        notch: (any NotchPresenting)? = nil,
        system: (any SystemNotificationPresenting)? = nil,
        history: (any TransitionHistoryStore)? = nil
    ) {
        self.preferences = preferences
        self.notch = notch
        self.system = system
        self.history = history
    }

    public func updatePreferences(_ preferences: NotificationPreferences) {
        self.preferences = preferences
    }

    public func currentPreferences() -> NotificationPreferences { preferences }

    public func route(events: [TransitionEvent]) async {
        let filtered = events.filter { preferences.allows(kind: $0.kind) }
        guard !filtered.isEmpty else { return }

        let groups = TransitionCoalescing.groupByPullRequest(filtered)
        let coalesced = groups.compactMap(\.first) // one representative per PR for routing sketch
        // Preserve all filtered events in delivery payload for UI summarization.
        let payload = filtered

        if preferences.allows(channel: .notch) {
            let delivery = NotificationDelivery(channel: .notch, events: payload, isTest: false)
            delivered.append(delivery)
            await notch?.present(events: coalesced)
        }
        if preferences.allows(channel: .system) {
            let authorized = await system?.requestAuthorizationIfNeeded() ?? true
            if authorized {
                for event in coalesced {
                    let delivery = NotificationDelivery(channel: .system, events: [event], isTest: false)
                    delivered.append(delivery)
                    await system?.present(event: event)
                }
            }
        }
        if preferences.allows(channel: .sound) {
            delivered.append(NotificationDelivery(channel: .sound, events: coalesced, isTest: false))
        }
        // History persistence is owned by RefreshCoordinator for real transitions.
        // Router must not append on its own when history is injected for tests.
        _ = history
    }

    public func sendTestNotification(channel: NotificationChannel) async {
        guard preferences.allows(channel: channel) || channel == .notch else { return }

        let testEvent = TransitionEvent(
            pullRequestID: GitHubNodeID("PR_TEST"),
            repositoryNameWithOwner: "octocat-fixture/public-demo",
            number: 0,
            title: "Test notification",
            kind: .ciChanged,
            oldValue: CIState.pending.rawValue,
            newValue: CIState.passing.rawValue,
            observedAt: GitPingsFixtures.fixedNow
        )

        let delivery = NotificationDelivery(channel: channel, events: [testEvent], isTest: true)
        delivered.append(delivery)
        testDeliveryCount += 1

        switch channel {
        case .notch:
            await notch?.present(events: [testEvent])
        case .system:
            _ = await system?.requestAuthorizationIfNeeded()
            await system?.present(event: testEvent)
        case .sound:
            break
        }

        // Explicit: do not write to TransitionHistoryStore for test notifications (NOTIFY-9).
    }

    public func resetDeliveries() {
        delivered = []
        testDeliveryCount = 0
    }
}
