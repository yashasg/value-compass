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

/// Migration plan that pins ``LocalSchemaV1`` as the v1 baseline so the next
/// `@Model` change can be planned as an explicit `MigrationStage` instead of
/// a silent SwiftData auto-migration.
///
/// `stages` is intentionally empty: the v1 schema has no prior version to
/// migrate from, so opening an existing v1 store is a no-op. When a new
/// version lands, append the next versioned schema to `schemas` and add a
/// matching `MigrationStage` to `stages` (lightweight when the change is
/// purely additive; custom when it renames or removes existing properties).
enum LocalSchemaMigrationPlan: SchemaMigrationPlan {
  static let schemas: [any VersionedSchema.Type] = [
    LocalSchemaV1.self
  ]

  static let stages: [MigrationStage] = []
}
