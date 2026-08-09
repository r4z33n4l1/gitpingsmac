import Foundation

/// Coordinates clearing durable GitHub-derived local state on sign-out.
/// Keychain token deletion is owned by GitHub Platform; call that separately.
public struct SignOutPurgePlan: Sendable {
    public var clearAccountMetadata: Bool
    public var clearSelectedRepositories: Bool
    public var clearPins: Bool
    public var clearPRCache: Bool
    public var clearSnapshots: Bool
    public var clearTransitionHistory: Bool
    public var resetFiltersToMVPDefault: Bool
    public var resetSettingsToMVPDefault: Bool

    public static let mvp = SignOutPurgePlan(
        clearAccountMetadata: true,
        clearSelectedRepositories: true,
        clearPins: true,
        clearPRCache: true,
        clearSnapshots: true,
        clearTransitionHistory: true,
        resetFiltersToMVPDefault: true,
        resetSettingsToMVPDefault: true
    )

    public init(
        clearAccountMetadata: Bool,
        clearSelectedRepositories: Bool,
        clearPins: Bool,
        clearPRCache: Bool,
        clearSnapshots: Bool,
        clearTransitionHistory: Bool,
        resetFiltersToMVPDefault: Bool,
        resetSettingsToMVPDefault: Bool
    ) {
        self.clearAccountMetadata = clearAccountMetadata
        self.clearSelectedRepositories = clearSelectedRepositories
        self.clearPins = clearPins
        self.clearPRCache = clearPRCache
        self.clearSnapshots = clearSnapshots
        self.clearTransitionHistory = clearTransitionHistory
        self.resetFiltersToMVPDefault = resetFiltersToMVPDefault
        self.resetSettingsToMVPDefault = resetSettingsToMVPDefault
    }
}

/// Applies a purge plan against Domain store protocols (in-memory or SwiftData-backed).
public actor LocalDataPurger {
    private let preferences: any PreferencesStore
    private let pins: any PinStore
    private let cache: any PRCacheStore
    private let snapshots: any SnapshotStore
    private let history: any TransitionHistoryStore
    private let settingsStore: InMemoryAppSettingsStore

    public init(
        preferences: any PreferencesStore,
        pins: any PinStore,
        cache: any PRCacheStore,
        snapshots: any SnapshotStore,
        history: any TransitionHistoryStore,
        settingsStore: InMemoryAppSettingsStore
    ) {
        self.preferences = preferences
        self.pins = pins
        self.cache = cache
        self.snapshots = snapshots
        self.history = history
        self.settingsStore = settingsStore
    }

    public func purge(plan: SignOutPurgePlan = .mvp, clock: any ClockProviding) async throws {
        if plan.clearPRCache {
            try await cache.purgePrivateGitHubData()
        }
        if plan.clearSnapshots {
            try await snapshots.saveNormalizedSnapshots([:])
        }
        if plan.clearPins {
            let current = try await pins.pinnedIDs()
            for id in current {
                try await pins.unpin(id)
            }
        }
        if plan.clearSelectedRepositories {
            try await preferences.setSelectedRepositoryIDs([])
        }
        if plan.resetFiltersToMVPDefault {
            try await preferences.setFilterConfiguration(.mvpDefault)
        }
        if plan.clearTransitionHistory {
            try await history.prune(retainingNewest: 0, olderThan: clock.now())
        }
        if plan.resetSettingsToMVPDefault {
            await settingsStore.resetToMVPDefaults(at: clock.now())
        }
        // Account metadata clearing is performed by the SwiftData controller when wired.
        _ = plan.clearAccountMetadata
    }
}
