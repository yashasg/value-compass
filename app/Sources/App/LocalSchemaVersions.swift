import Foundation
import SwiftData

/// Versioned baseline for the v1 SwiftData on-disk schema.
///
/// `docs/db-tech-spec.md` §4.1 requires v1 to ship with an explicit model
/// version and a `SchemaMigrationPlan` even when the initial migration is
/// trivial. Without that baseline, SwiftData falls back to silent automatic
/// migration on every `@Model` change — and `ContributionRecord` history
/// (the append-only audit trail described in §2.4) has no other source of
/// truth to recover from a botched migration. See issue #235.
///
/// The `models` list intentionally mirrors the in-memory `Schema` returned
/// by ``LocalPersistence/schema`` exactly. New `@Model` types or schema
/// changes must bump to a `LocalSchemaV2` (etc.), append the new versioned
/// schema to ``LocalSchemaMigrationPlan/schemas``, and add the corresponding
/// `MigrationStage.lightweight(...)` or `.custom(...)` entry to
/// ``LocalSchemaMigrationPlan/stages`` — do not mutate `LocalSchemaV1`.
enum LocalSchemaV1: VersionedSchema {
  static let versionIdentifier = Schema.Version(1, 0, 0)

  static var models: [any PersistentModel.Type] {
    [
      // Legacy contribution-history models.
      Portfolio.self,
      Category.self,
      Ticker.self,
      ContributionRecord.self,
      CategoryContribution.self,
      TickerAllocation.self,
      // Additive MVP models (issue #219 foundation for #123 / #128 / #131 / #133).
      Holding.self,
      TickerMetadata.self,
      MarketDataBar.self,
      InvestSnapshot.self,
      AppSettings.self,
    ]
  }
}

/// Versioned schema bump that adds `@Attribute(.unique) var id: UUID` to
/// ``CategoryContribution`` and ``TickerAllocation`` so every contribution
/// breakdown row carries a stable business key (issue #249).
///
/// The model class identity is shared with ``LocalSchemaV1`` — both versioned
/// schemas list the same global `@Model` types, since the change is purely
/// additive. SwiftData distinguishes the two on-disk schema versions by the
/// `versionIdentifier` declared here, and the migration stage registered in
/// ``LocalSchemaMigrationPlan/stages`` is what actually evolves a v1 store
/// into the v2 shape.
enum LocalSchemaV2: VersionedSchema {
  static let versionIdentifier = Schema.Version(2, 0, 0)

  static var models: [any PersistentModel.Type] {
    LocalSchemaV1.models
  }
}

/// Migration plan that pins the v1 baseline (``LocalSchemaV1``) and the
/// additive v2 schema bump (``LocalSchemaV2``).
///
/// `stages` registers ``migrateV1toV2`` so reopening a v1 store under v2 code
/// runs an explicit, deterministic backfill instead of relying on SwiftData's
/// silent automatic migration.
enum LocalSchemaMigrationPlan: SchemaMigrationPlan {
  static let schemas: [any VersionedSchema.Type] = [
    LocalSchemaV1.self,
    LocalSchemaV2.self,
  ]

  static let stages: [MigrationStage] = [
    migrateV1toV2
  ]

  /// v1 → v2 migration that backfills a fresh `UUID` for every persisted
  /// ``CategoryContribution`` and ``TickerAllocation`` row.
  ///
  /// SwiftData's lightweight pass populates the new `id: UUID` column with
  /// the property's default initializer expression (`UUID()`). The
  /// `didMigrate` block then walks every row in the v2 context and assigns a
  /// fresh `UUID()` regardless, which makes the per-row uniqueness invariant
  /// independent of how SwiftData evaluates the default expression during
  /// the lightweight pass — even if the bridge happened to seed the column
  /// with a single shared UUID, the explicit reassignment guarantees the
  /// `@Attribute(.unique)` constraint is satisfied for every row.
  static let migrateV1toV2 = MigrationStage.custom(
    fromVersion: LocalSchemaV1.self,
    toVersion: LocalSchemaV2.self,
    willMigrate: nil,
    didMigrate: { context in
      for row in try context.fetch(FetchDescriptor<CategoryContribution>()) {
        row.id = UUID()
      }
      for row in try context.fetch(FetchDescriptor<TickerAllocation>()) {
        row.id = UUID()
      }
      try context.save()
    }
  )
}
