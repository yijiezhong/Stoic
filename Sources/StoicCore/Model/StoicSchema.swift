import Foundation
import SwiftData

public enum StoicSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [TaskItem.self, Interval.self, DaySummary.self, SettingsRecord.self]
    }
}

public enum StoicMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [StoicSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum StoicStore {
    /// 应用运行时的容器。
    public static func makeContainer(inMemory: Bool = false, storeURL: URL? = nil) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(url: storeURL)
        } else {
            configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        }
        return try ModelContainer(
            for: Schema(versionedSchema: StoicSchemaV1.self),
            migrationPlan: StoicMigrationPlan.self,
            configurations: configuration
        )
    }
}
