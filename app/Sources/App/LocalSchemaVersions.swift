import Foundation
import SwiftData

/// Frozen baseline for the v1 SwiftData on-disk schema.
///
/// `docs/db-tech-spec.md` §4.1 requires v1 to ship with an explicit model
/// version and a `SchemaMigrationPlan` even when the initial migration is
/// trivial. Without that baseline, SwiftData falls back to silent automatic
/// migration on every `@Model` change — and `ContributionRecord` history
/// (the append-only audit trail described in §2.4) has no other source of
/// truth to recover from a botched migration. See issue #235.
///
/// **Frozen-snapshot invariant (issue #337).** The `models` list resolves to
/// the *nested* `@Model` types declared on ``LocalSchemaV1`` itself (see
/// `LocalSchemaV1Models.swift`), not to the live app-facing classes. That
/// means edits to the live `@Model` declarations (which back ``LocalSchemaV2``
/// and the module-level typealiases below) cannot retroactively mutate the v1
/// on-disk shape. Each schema version is a hermetic snapshot of the on-disk
/// shape it shipped with.
///
/// Adding a new schema version means: introduce a new `LocalSchemaVN` enum
/// with its own nested `@Model` types declared as `extension LocalSchemaVN`,
/// append it to ``LocalSchemaMigrationPlan/schemas``, and register the
/// corresponding `MigrationStage.lightweight(...)` or `.custom(...)` entry.
/// Do not mutate any prior `LocalSchemaVN` namespace.
enum LocalSchemaV1: VersionedSchema {
  static let versionIdentifier = Schema.Version(1, 0, 0)

  static var models: [any PersistentModel.Type] {
    [
      // Legacy contribution-history models — frozen as of v1.
      LocalSchemaV1.Portfolio.self,
      LocalSchemaV1.Category.self,
      LocalSchemaV1.Ticker.self,
      LocalSchemaV1.ContributionRecord.self,
      LocalSchemaV1.CategoryContribution.self,
      LocalSchemaV1.TickerAllocation.self,
      // Additive MVP models (issue #219 foundation for #123 / #128 / #131 / #133).
      LocalSchemaV1.Holding.self,
      LocalSchemaV1.TickerMetadata.self,
      LocalSchemaV1.MarketDataBar.self,
      LocalSchemaV1.InvestSnapshot.self,
      LocalSchemaV1.AppSettings.self,
    ]
  }
}

/// Frozen baseline for the v2 SwiftData on-disk schema — the version the app
/// currently runs against. v2 adds `@Attribute(.unique) var id: UUID` to
/// ``LocalSchemaV2/CategoryContribution`` and ``LocalSchemaV2/TickerAllocation``
/// so every contribution breakdown row carries a stable business key (issues
/// #249, #298). Every other entity is bit-identical to ``LocalSchemaV1``.
///
/// **Frozen-snapshot invariant (issue #337).** Like ``LocalSchemaV1``, this
/// enum owns its own nested `@Model` types (declared as `extension
/// LocalSchemaV2` across `DomainModels.swift` and `MVPModels.swift`). The
/// app-facing module-level names (`Portfolio`, `Category`, …) are
/// `typealias` declarations resolving here, so future schema bumps must
/// introduce a new `LocalSchemaV3` namespace rather than editing the types
/// inside this one. Doing so freezes the v2 on-disk shape against drift the
/// same way V1 is frozen against the live shape today.
enum LocalSchemaV2: VersionedSchema {
  static let versionIdentifier = Schema.Version(2, 0, 0)

  static var models: [any PersistentModel.Type] {
    [
      LocalSchemaV2.Portfolio.self,
      LocalSchemaV2.Category.self,
      LocalSchemaV2.Ticker.self,
      LocalSchemaV2.ContributionRecord.self,
      LocalSchemaV2.CategoryContribution.self,
      LocalSchemaV2.TickerAllocation.self,
      LocalSchemaV2.Holding.self,
      LocalSchemaV2.TickerMetadata.self,
      LocalSchemaV2.MarketDataBar.self,
      LocalSchemaV2.InvestSnapshot.self,
      LocalSchemaV2.AppSettings.self,
    ]
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
  /// ``LocalSchemaV2/CategoryContribution`` and ``LocalSchemaV2/TickerAllocation``
  /// row.
  ///
  /// Step one is provided by SwiftData's lightweight schema bridge: the new
  /// `id: UUID` column carries an inline `= UUID()` default on its
  /// declaration (see ``LocalSchemaV2/CategoryContribution`` and
  /// ``LocalSchemaV2/TickerAllocation``), which SwiftData uses to populate
  /// the column for every pre-existing row before this stage's `didMigrate`
  /// block ever runs. Without the inline default the bridge would fail on a
  /// non-optional required column, and `didMigrate` would never get a
  /// chance to fix it (issue #298 — the reviewer note that was missed when
  /// #249 landed).
  ///
  /// Step two — `didMigrate` — then walks every row in the v2 context and
  /// reassigns a fresh `UUID()`. That belt-and-suspenders pass makes the
  /// per-row uniqueness invariant independent of how SwiftData evaluates the
  /// default expression during the lightweight pass: even if the bridge
  /// seeded the column with a single shared UUID across rows, the explicit
  /// reassignment guarantees the `@Attribute(.unique)` constraint holds for
  /// every row before the migrated store is handed back to the app. The
  /// `FetchDescriptor` types resolve via the module-level typealiases to
  /// ``LocalSchemaV2/CategoryContribution`` and
  /// ``LocalSchemaV2/TickerAllocation`` — the v2 context only knows about
  /// the v2 types, not the v1 frozen baseline.
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

// MARK: - App-facing aliases
//
// The app, tests, and feature reducers reference the live `@Model` types by
// their bare names (e.g. `Portfolio`, `Holding`). Each alias resolves to the
// matching nested type on ``LocalSchemaV2`` — the version the running app
// stores against. When the next schema bump lands, freeze the current
// `LocalSchemaV2` namespace as-is, declare ``LocalSchemaV3`` with the new
// nested types, and re-target these aliases at `LocalSchemaV3.X`. The bump
// must not edit the nested types on prior versions.

typealias Portfolio = LocalSchemaV2.Portfolio
typealias Category = LocalSchemaV2.Category
typealias Ticker = LocalSchemaV2.Ticker
typealias ContributionRecord = LocalSchemaV2.ContributionRecord
typealias CategoryContribution = LocalSchemaV2.CategoryContribution
typealias TickerAllocation = LocalSchemaV2.TickerAllocation
typealias Holding = LocalSchemaV2.Holding
typealias TickerMetadata = LocalSchemaV2.TickerMetadata
typealias MarketDataBar = LocalSchemaV2.MarketDataBar
typealias InvestSnapshot = LocalSchemaV2.InvestSnapshot
typealias AppSettings = LocalSchemaV2.AppSettings
