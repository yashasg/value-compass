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
/// means edits to the live `@Model` declarations (which back ``LocalSchemaV3``
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

/// Frozen baseline for the v2 SwiftData on-disk schema. v2 adds
/// `@Attribute(.unique) var id: UUID` to ``LocalSchemaV2/CategoryContribution``
/// and ``LocalSchemaV2/TickerAllocation`` so every contribution breakdown
/// row carries a stable business key (issues #249, #298). Every other entity
/// is bit-identical to ``LocalSchemaV1``.
///
/// **Frozen-snapshot invariant (issues #337 and #356).** Like
/// ``LocalSchemaV1``, this enum owns its own nested `@Model` types
/// (declared in `LocalSchemaV2Models.swift`). The live app-facing
/// module-level names (`Portfolio`, `Category`, …) are `typealias`
/// declarations resolving to ``LocalSchemaV3``, so future schema bumps must
/// introduce a new `LocalSchemaV4` namespace rather than editing the types
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

/// Frozen baseline for the v3 SwiftData on-disk schema — the version the app
/// currently runs against. v3 adds eight optional indicator columns to
/// ``LocalSchemaV3/Holding`` so the server-computed indicator fields
/// returned by `Components.Schemas.HoldingOut` (`current_price`, `sma_50`,
/// `sma_200`, `midline`, `atr`, `upper_band`, `lower_band`, `band_position`)
/// have an in-app persistence target (issue #356). Every other entity is
/// bit-identical to ``LocalSchemaV2``.
///
/// **Frozen-snapshot invariant.** This enum owns its own nested `@Model`
/// types declared as `extension LocalSchemaV3` across
/// `Backend/Models/DomainModels.swift` and `Backend/Models/MVPModels.swift`.
/// The app-facing module-level names (`Portfolio`, `Category`, …) are
/// `typealias` declarations resolving here, so future schema bumps must
/// introduce a new `LocalSchemaV4` namespace rather than editing the types
/// inside this one.
enum LocalSchemaV3: VersionedSchema {
  static let versionIdentifier = Schema.Version(3, 0, 0)

  static var models: [any PersistentModel.Type] {
    [
      LocalSchemaV3.Portfolio.self,
      LocalSchemaV3.Category.self,
      LocalSchemaV3.Ticker.self,
      LocalSchemaV3.ContributionRecord.self,
      LocalSchemaV3.CategoryContribution.self,
      LocalSchemaV3.TickerAllocation.self,
      LocalSchemaV3.Holding.self,
      LocalSchemaV3.TickerMetadata.self,
      LocalSchemaV3.MarketDataBar.self,
      LocalSchemaV3.InvestSnapshot.self,
      LocalSchemaV3.AppSettings.self,
    ]
  }
}

/// Migration plan that pins the v1 baseline (``LocalSchemaV1``), the
/// additive v2 schema bump (``LocalSchemaV2``), and the additive v3 schema
/// bump (``LocalSchemaV3``).
///
/// `stages` registers ``migrateV1toV2`` (custom `didMigrate` block that
/// backfills a fresh `UUID()` for every contribution-breakdown row) and
/// ``migrateV2toV3`` (lightweight — the V2 → V3 delta is the eight new
/// optional indicator columns on `Holding`, which SwiftData's lightweight
/// bridge populates with `nil` for every existing row without any custom
/// block).
enum LocalSchemaMigrationPlan: SchemaMigrationPlan {
  static let schemas: [any VersionedSchema.Type] = [
    LocalSchemaV1.self,
    LocalSchemaV2.self,
    LocalSchemaV3.self,
  ]

  static let stages: [MigrationStage] = [
    migrateV1toV2,
    migrateV2toV3,
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
  /// fetches below name the V2 nested types explicitly so the migration
  /// runs against the destination V2 entity graph regardless of where the
  /// module-level typealiases resolve.
  static let migrateV1toV2 = MigrationStage.custom(
    fromVersion: LocalSchemaV1.self,
    toVersion: LocalSchemaV2.self,
    willMigrate: nil,
    didMigrate: { context in
      for row in try context.fetch(FetchDescriptor<LocalSchemaV2.CategoryContribution>()) {
        row.id = UUID()
      }
      for row in try context.fetch(FetchDescriptor<LocalSchemaV2.TickerAllocation>()) {
        row.id = UUID()
      }
      try context.save()
    }
  )

  /// v2 → v3 migration. The V2 → V3 delta (issue #356) is eight optional
  /// `Decimal?` indicator columns on ``LocalSchemaV3/Holding``
  /// (`currentPrice`, `sma50`, `sma200`, `midline`, `atr`, `upperBand`,
  /// `lowerBand`, `bandPosition`). Because every new column is nullable
  /// and has no default expression beyond `nil`, SwiftData's lightweight
  /// schema bridge can populate the column for every pre-existing row
  /// without any custom `willMigrate`/`didMigrate` work — no contribution-
  /// history columns are touched and no V2 row needs rewriting.
  static let migrateV2toV3 = MigrationStage.lightweight(
    fromVersion: LocalSchemaV2.self,
    toVersion: LocalSchemaV3.self
  )
}

// MARK: - App-facing aliases
//
// The app, tests, and feature reducers reference the live `@Model` types by
// their bare names (e.g. `Portfolio`, `Holding`). Each alias resolves to the
// matching nested type on ``LocalSchemaV3`` — the version the running app
// stores against. When the next schema bump lands, freeze the current
// `LocalSchemaV3` namespace as-is, declare ``LocalSchemaV4`` with the new
// nested types, and re-target these aliases at `LocalSchemaV4.X`. The bump
// must not edit the nested types on prior versions.

typealias Portfolio = LocalSchemaV3.Portfolio
typealias Category = LocalSchemaV3.Category
typealias Ticker = LocalSchemaV3.Ticker
typealias ContributionRecord = LocalSchemaV3.ContributionRecord
typealias CategoryContribution = LocalSchemaV3.CategoryContribution
typealias TickerAllocation = LocalSchemaV3.TickerAllocation
typealias Holding = LocalSchemaV3.Holding
typealias TickerMetadata = LocalSchemaV3.TickerMetadata
typealias MarketDataBar = LocalSchemaV3.MarketDataBar
typealias InvestSnapshot = LocalSchemaV3.InvestSnapshot
typealias AppSettings = LocalSchemaV3.AppSettings
