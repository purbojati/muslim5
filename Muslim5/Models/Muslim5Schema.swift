import SwiftData

enum Muslim5Store {
    static let iCloudContainerIdentifier = "iCloud.com.muslim5.app"
    static let schema = Schema([PrayerRecord.self, TrackingPause.self])
}

enum Muslim5SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [PrayerRecord.self, TrackingPause.self]
    }
}

enum Muslim5MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [Muslim5SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
