import Foundation
import SwiftData

/// Schema version 1.
///
/// v1 needs no migration plan. The scaffold exists anyway, at a cost of about fifteen
/// minutes, so that v1.1 can ship without a data-loss incident and so the schema is versioned
/// from the first commit rather than retrofitted after there is real user data in it.
public enum CarbonSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            FormTemplate.self,
            FieldDefinition.self,
            CaptureRecord.self,
            FieldValue.self,
            PageAsset.self,
            UsagePeriod.self,
            ExportLog.self,
        ]
    }
}

/// The current schema, and the migration path to it. Empty for now, deliberately.
public enum CarbonMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [CarbonSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

extension Schema {
    /// The schema every container is built from — the app's, the previews', and the tests'.
    public static var carbon: Schema { Schema(CarbonSchemaV1.models, version: CarbonSchemaV1.versionIdentifier) }
}
