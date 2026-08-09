import Foundation

/// SwiftData schema versioning for durable non-secret state (ADR-001).
public enum PersistenceSchemaVersion: Int, Sendable {
    /// Wave 1 spike / Gate 0 candidate schema.
    case v1 = 1

    public static let current: PersistenceSchemaVersion = .v1
}

/// Retention policy for local transition history (Wave 0 baseline decisions).
public enum TransitionHistoryRetention: Sendable {
    public static let maximumEventCount = 100
    public static let maximumAge: TimeInterval = 7 * 24 * 60 * 60
}
