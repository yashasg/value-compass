import ComposableArchitecture
import Foundation
import SwiftData

/// Reducer that drives `PortfolioDetailView` — the per-portfolio summary,
/// holdings preview, and Calculate flow. Replaces the Phase 0 placeholder.
///
/// State is decoupled from SwiftData by projecting the `Portfolio` into a
/// `PortfolioDetailSnapshot` value type so the reducer is `Equatable` and
/// safe to pass across actor boundaries. Persistence lookups happen through
/// `@Dependency(\.modelContainer)`; the contribution calculation runs through
/// `@Dependency(\.contributionCalculator)` so tests can stub the math.
///
/// Phase 2 (#159) wires `MainFeature.path` to handle the `Delegate` cases.
/// Until then the legacy bridge in `PortfolioDetailView.swift` observes a
/// `legacyNavigation` latch to mirror those delegates onto the existing
/// `NavigationStack` / `NavigationSplitView`.
@Reducer
struct PortfolioDetailFeature {
  @ObservableState
  struct State: Equatable {
    let portfolioID: UUID
    var snapshot: PortfolioDetailSnapshot
    var calculationOutput: ContributionOutput?
    var lastError: String?
    /// Phase 1 only: legacy bridge consumes this latch to push the
    /// corresponding view onto the surrounding `NavigationStack`. Phase 2
    /// (#159) deletes this and `MainFeature` reads `delegate(.*)` directly.
    var legacyNavigation: LegacyNavigation?

    init(
      portfolioID: UUID,
      snapshot: PortfolioDetailSnapshot,
      calculationOutput: ContributionOutput? = nil,
      lastError: String? = nil,
      legacyNavigation: LegacyNavigation? = nil
    ) {
      self.portfolioID = portfolioID
      self.snapshot = snapshot
      self.calculationOutput = calculationOutput
      self.lastError = lastError
      self.legacyNavigation = legacyNavigation
    }
  }

  /// Phase-1 navigation latch consumed by `PortfolioDetailLegacyBridge`.
  /// Mirrors the `Action.Delegate` cases.
  @CasePathable
  enum LegacyNavigation: Equatable {
    case holdingsEditor(portfolioID: UUID)
    case calculationResult(ContributionOutput)
    case history(portfolioID: UUID)
  }

  enum Action: Equatable {
    case task
    case snapshotChanged(PortfolioDetailSnapshot)
    case editHoldingsTapped
    case calculateTapped
    case calculationCompleted(ContributionOutput)
    case viewResultTapped
    case openHistoryTapped
    case legacyNavigationConsumed
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable {
      case openHoldingsEditor(portfolioID: UUID)
      case openCalculationResult(ContributionOutput)
      case openHistory(portfolioID: UUID)
    }
  }

  @Dependency(\.modelContainer) var modelContainer
  @Dependency(\.contributionCalculator) var contributionCalculator

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        let id = state.portfolioID
        return .run { [modelContainer] send in
          if let snapshot = try await Self.loadSnapshot(modelContainer: modelContainer, id: id) {
            await send(.snapshotChanged(snapshot))
          }
        } catch: { _, _ in
          // Snapshot reload is best-effort. UI keeps the last-known snapshot.
        }

      case .snapshotChanged(let snapshot):
        state.snapshot = snapshot
        return .none

      case .editHoldingsTapped:
        let id = state.portfolioID
        state.legacyNavigation = .holdingsEditor(portfolioID: id)
        return .send(.delegate(.openHoldingsEditor(portfolioID: id)))

      case .calculateTapped:
        guard state.snapshot.canCalculate else { return .none }
        let id = state.portfolioID
        return .run { [modelContainer, contributionCalculator] send in
          let output = await MainActor.run { () -> ContributionOutput in
            do {
              let context = try modelContainer.mainContext()
              let descriptor = FetchDescriptor<Portfolio>(
                predicate: #Predicate { $0.id == id }
              )
              let portfolio = try context.fetch(descriptor).first
              return contributionCalculator.calculate(portfolio)
            } catch {
              return ContributionOutput.failure(
                ContributionCalculationError.missingPortfolio
              )
            }
          }
          await send(.calculationCompleted(output))
        }

      case .calculationCompleted(let output):
        state.calculationOutput = output
        state.lastError = output.error?.localizedDescription
        return .none

      case .viewResultTapped:
        guard let output = state.calculationOutput, output.error == nil else {
          return .none
        }
        state.legacyNavigation = .calculationResult(output)
        return .send(.delegate(.openCalculationResult(output)))

      case .openHistoryTapped:
        let id = state.portfolioID
        state.legacyNavigation = .history(portfolioID: id)
        return .send(.delegate(.openHistory(portfolioID: id)))

      case .legacyNavigationConsumed:
        state.legacyNavigation = nil
        return .none

      case .delegate:
        return .none
      }
    }
  }

  /// Loads the snapshot through a `BackgroundModelActor` so the read happens
  /// off the main actor. Static so the effect closure does not need to
  /// capture `self`. The body is already `async`, so it awaits the actor
  /// task directly and uses `LockIsolated` only to bridge the
  /// `modelContainer.task` `Void` return into a value the call site can
  /// read.
  private static func loadSnapshot(
    modelContainer: ModelContainerClient,
    id: UUID
  ) async throws -> PortfolioDetailSnapshot? {
    let collected = LockIsolated<PortfolioDetailSnapshot?>(nil)
    try await modelContainer.task { actor in
      let snapshot = try await actor.loadPortfolioDetailSnapshot(id: id)
      collected.setValue(snapshot)
    }
    return collected.value
  }
}

// MARK: - Snapshot

/// Sendable, value-typed projection of a `Portfolio` for use in
/// `PortfolioDetailFeature.State`. SwiftData `@Model` classes are
/// `MainActor`-isolated and not `Sendable`, so the reducer mirrors only the
/// fields the detail UI reads.
struct PortfolioDetailSnapshot: Equatable, Sendable {
  let id: UUID
  let name: String
  let monthlyBudget: Decimal
  let maWindow: Int
  let categories: [CategorySnapshot]
  let marketDataCompleteCount: Int
  let marketDataIncompleteCount: Int
  /// Whether the portfolio currently passes the holdings-side validation
  /// rules used to gate the Calculate button. Mirrors
  /// `HoldingsDraft.canCalculate()` so the warning banner stays in sync with
  /// the editor's own checks.
  let canCalculate: Bool

  /// Convenience for the summary section.
  var marketDataCompletionText: String {
    "\(marketDataCompleteCount) complete / \(marketDataIncompleteCount) incomplete"
  }
}

struct CategorySnapshot: Equatable, Identifiable, Sendable {
  let id: UUID
  let displayName: String
  let weight: Decimal
  let weightPercentText: String
  let tickers: [TickerSnapshot]
}

struct TickerSnapshot: Equatable, Identifiable, Sendable {
  let id: UUID
  let normalizedSymbol: String
  let currentPrice: Decimal?
  let movingAverage: Decimal?
  let currentPriceText: String
  let movingAverageText: String
  let hasCompleteMarketData: Bool
}

extension PortfolioDetailSnapshot {
  /// Projects a `Portfolio` (and its categories/tickers) into the value-typed
  /// snapshot used by `PortfolioDetailFeature.State`. Must be called from the
  /// actor that owns the portfolio: `BackgroundModelActor` for the reducer's
  /// reload effect (see `loadPortfolioDetailSnapshot(id:)` below), which is
  /// the only call site after the MVVM legacy bridge was removed in #162.
  init(portfolio: Portfolio) {
    let categories =
      portfolio.categories
      .sorted { $0.sortOrder < $1.sortOrder }
      .map(CategorySnapshot.init(category:))
    let allTickers = categories.flatMap(\.tickers)
    let completeCount = allTickers.filter(\.hasCompleteMarketData).count
    let incompleteCount = allTickers.count - completeCount

    self.init(
      id: portfolio.id,
      name: portfolio.name,
      monthlyBudget: portfolio.monthlyBudget,
      maWindow: portfolio.maWindow,
      categories: categories,
      marketDataCompleteCount: completeCount,
      marketDataIncompleteCount: incompleteCount,
      canCalculate: HoldingsDraft(portfolio: portfolio).canCalculate()
    )
  }
}

extension CategorySnapshot {
  init(category: Category) {
    let trimmedName = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let displayName = trimmedName.isEmpty ? "Unnamed Category" : trimmedName
    self.init(
      id: category.id,
      displayName: displayName,
      weight: category.weight,
      weightPercentText: PortfolioDetailSnapshot.percentText(for: category.weight),
      tickers: category.tickers
        .sorted { $0.sortOrder < $1.sortOrder }
        .map(TickerSnapshot.init(ticker:))
    )
  }
}

extension TickerSnapshot {
  init(ticker: Ticker) {
    self.init(
      id: ticker.id,
      normalizedSymbol: ticker.normalizedSymbol,
      currentPrice: ticker.currentPrice,
      movingAverage: ticker.movingAverage,
      currentPriceText: PortfolioDetailSnapshot.decimalText(for: ticker.currentPrice),
      movingAverageText: PortfolioDetailSnapshot.decimalText(for: ticker.movingAverage),
      hasCompleteMarketData: ticker.currentPrice != nil && ticker.movingAverage != nil
    )
  }
}

extension PortfolioDetailSnapshot {
  static func percentText(for storedWeight: Decimal) -> String {
    NSDecimalNumber(decimal: storedWeight * 100).stringValue
  }

  static func decimalText(for value: Decimal?) -> String {
    guard let value else { return "" }
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    return formatter.string(from: NSDecimalNumber(decimal: value))
      ?? NSDecimalNumber(decimal: value).stringValue
  }
}

extension BackgroundModelActor {
  /// Fetches the portfolio with the given identifier and projects it into a
  /// `PortfolioDetailSnapshot` inside the actor's isolation so the call site
  /// can return the result across actor boundaries.
  func loadPortfolioDetailSnapshot(id: UUID) throws -> PortfolioDetailSnapshot? {
    let descriptor = FetchDescriptor<Portfolio>(
      predicate: #Predicate { $0.id == id }
    )
    guard let portfolio = try modelContext.fetch(descriptor).first else {
      return nil
    }
    return PortfolioDetailSnapshot(portfolio: portfolio)
  }
}

// MARK: - ContributionOutput conformances (Phase 1 only)

// `ContributionOutput` does not conform to `Equatable`/`Sendable` in
// `app/Sources/Backend/Services/ContributionCalculator.swift` (out of scope
// per #154's `do_not_touch` list). The TCA reducer needs both:
//
// - `Equatable` so `PortfolioDetailFeature.State` and `Action` (which carry
//   `ContributionOutput`) can synthesise `Equatable`.
// - `Sendable` so the calculation effect can hand the output back to the
//   reducer through `await send(.calculationCompleted(output))`.
//
// `error: LocalizedError?` is the only non-`Equatable`/`Sendable` field. In
// practice the calculators only ever produce `ContributionCalculationError`
// values (which are `Equatable, Sendable`), so the unchecked `Sendable`
// conformance is safe and the manual `Equatable` compares errors by their
// `localizedDescription`.
extension ContributionOutput: @unchecked Sendable {}

extension ContributionOutput: Equatable {
  static func == (lhs: ContributionOutput, rhs: ContributionOutput) -> Bool {
    lhs.totalAmount == rhs.totalAmount
      && lhs.categoryBreakdown == rhs.categoryBreakdown
      && lhs.allocations == rhs.allocations
      && lhs.error?.localizedDescription == rhs.error?.localizedDescription
  }
}
