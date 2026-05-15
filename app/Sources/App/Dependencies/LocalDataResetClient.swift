import ComposableArchitecture
import Foundation
import SwiftData

/// `@DependencyClient` wrapper around the SwiftData wipe that the
/// "Erase All My Data" Settings flow (issue #329) runs after the backend
/// `DELETE /portfolio` succeeds.
///
/// The wipe removes every personal-data row the app persists on disk —
/// portfolios, holdings, snapshots, contribution history, and per-device
/// app settings — while intentionally leaving the shared market-data cache
/// (`MarketDataBar`, `TickerMetadata`) untouched. Market-data rows are
/// keyed by ticker, not by `X-Device-UUID`, so they are not personal data
/// of the caller (matches the backend's `StockCache` carve-out documented
/// in `docs/legal/data-subject-rights.md` "Erasure — full account").
///
/// Reducers consume this via `@Dependency(\.localDataReset)`; the
/// macro-synthesized `testValue` fails any unstubbed call so reducer tests
/// must inject the behavior they want.
@DependencyClient
struct LocalDataResetClient: Sendable {
  /// Erases every personal-data row the app persists. Throws on the first
  /// SwiftData failure so the caller can surface the error and STOP the
  /// erasure flow before clobbering the Keychain (which would leave the
  /// user in a state with no key but unresolved local data).
  var eraseAllPersonalData: @Sendable () async throws -> Void
}

extension LocalDataResetClient: DependencyKey {
  static let liveValue: LocalDataResetClient = {
    LocalDataResetClient(
      eraseAllPersonalData: {
        @Dependency(\.modelContainer) var modelContainer
        try await modelContainer.task { actor in
          try await actor.eraseAllPersonalData()
        }
      }
    )
  }()

  /// Preview stub — `#Preview` of `SettingsView` does not actually wipe a
  /// SwiftData store. The synchronous no-op keeps the macro-synthesized
  /// `testValue`'s unimplemented-call reporter from firing.
  static let previewValue: LocalDataResetClient = LocalDataResetClient(
    eraseAllPersonalData: {}
  )
}

extension DependencyValues {
  var localDataReset: LocalDataResetClient {
    get { self[LocalDataResetClient.self] }
    set { self[LocalDataResetClient.self] = newValue }
  }
}

extension BackgroundModelActor {
  /// Deletes every personal-data row from the live SwiftData store. Runs
  /// inside the actor's isolation so the writes are off the main thread,
  /// then saves the context once so the operation is one logical
  /// transaction.
  ///
  /// **What is wiped.** `Portfolio` (which cascades to `Category`, `Ticker`,
  /// and the legacy `ContributionRecord` graph via the schema's
  /// `@Relationship(deleteRule: .cascade)` declarations), plus the MVP-only
  /// `Holding`, `InvestSnapshot`, and `AppSettings` rows that reference the
  /// portfolio by `portfolioId` UUID instead of by `@Relationship`.
  ///
  /// **What survives.** `MarketDataBar` and `TickerMetadata` — both shared
  /// market data, neither keyed to the caller. Same carve-out the backend
  /// makes for `StockCache` on `DELETE /portfolio`. Keeping the cache lets
  /// the next install reuse already-fetched bars instead of re-downloading
  /// them and burning a Massive quota.
  func eraseAllPersonalData() throws {
    for portfolio in try modelContext.fetch(FetchDescriptor<Portfolio>()) {
      try PortfolioCascadeDeleter(context: modelContext).delete(portfolioID: portfolio.id)
    }

    for holding in try modelContext.fetch(FetchDescriptor<Holding>()) {
      modelContext.delete(holding)
    }

    for snapshot in try modelContext.fetch(FetchDescriptor<InvestSnapshot>()) {
      modelContext.delete(snapshot)
    }

    for settings in try modelContext.fetch(FetchDescriptor<AppSettings>()) {
      modelContext.delete(settings)
    }

    try modelContext.save()
  }
}
