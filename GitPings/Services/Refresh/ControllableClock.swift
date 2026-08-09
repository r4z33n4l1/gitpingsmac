import Foundation

/// Mutable test clock. Advance explicitly — never sleep on the wall clock.
public final class ControllableClock: ClockProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var instant: Date

    public init(_ instant: Date = GitPingsFixtures.fixedNow) {
        self.instant = instant
    }

    public func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return instant
    }

    public func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        instant = instant.addingTimeInterval(interval)
    }

    public func set(_ date: Date) {
        lock.lock()
        defer { lock.unlock() }
        instant = date
    }
}
