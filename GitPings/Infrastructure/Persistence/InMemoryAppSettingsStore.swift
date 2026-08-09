import Foundation

/// Local settings sketch (notification/channel toggles + refresh interval).
/// Domain `PreferencesStore` covers repos/filters only; this complements it.
public actor InMemoryAppSettingsStore {
    private var settings: AppSettingsDraft

    public init(settings: AppSettingsDraft? = nil, clock: any ClockProviding = FixedClock(GitPingsFixtures.fixedNow)) {
        self.settings = settings ?? .mvpDefaults(at: clock.now())
    }

    public func load() -> AppSettingsDraft { settings }

    public func save(_ draft: AppSettingsDraft) {
        settings = draft
    }

    public func resetToMVPDefaults(at date: Date) {
        settings = .mvpDefaults(at: date)
    }
}
