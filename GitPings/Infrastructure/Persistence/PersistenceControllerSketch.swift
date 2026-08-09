import Foundation

#if canImport(SwiftData)
import SwiftData
#endif

/// Documents the intended ModelContainer wiring for Gate 0 integration.
/// Not runtime-verified on Linux Cloud Agents.
public enum PersistenceControllerSketch {
    public static let schemaVersion = PersistenceSchemaVersion.current

    /// Entity types that belong in schema v1.
    public static let v1EntityNames: [String] = [
        "AccountMetadataRecord",
        "SelectedRepositoryRecord",
        "FilterConfigurationRecord",
        "PinRecord",
        "CachedPullRequestRecord",
        "NormalizedSnapshotRecord",
        "AppSettingsRecord",
        "TransitionHistoryRecord",
    ]

#if canImport(SwiftData)
    @MainActor
    public static func makeV1Container(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            AccountMetadataRecord.self,
            SelectedRepositoryRecord.self,
            FilterConfigurationRecord.self,
            PinRecord.self,
            CachedPullRequestRecord.self,
            NormalizedSnapshotRecord.self,
            AppSettingsRecord.self,
            TransitionHistoryRecord.self,
        ])
        let configuration = ModelConfiguration(
            "GitPingsLocalStore",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
#endif
}
