import Foundation
import SwiftData

enum NemuChartSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SleepRecordEntity.self, UserSettingsEntity.self, SleepGoalEntity.self]
    }
}

enum NemuChartMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [NemuChartSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum ModelContainerFactory {
    static func make(inMemory: Bool = false, storeURL: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: NemuChartSchemaV1.self)
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(
                "NemuChart",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                "NemuChart",
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: NemuChartMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
