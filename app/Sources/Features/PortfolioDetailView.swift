import ComposableArchitecture
import SwiftData
import SwiftUI

/// Per-portfolio detail surface. Renders on top of `PortfolioDetailFeature`
/// and pushes `HoldingsEditorView` / `ContributionResultView` /
/// `ContributionHistoryListView` for delegate-driven navigation. Replaces
/// the MVVM definition that previously lived in `MainView.swift`.
///
/// Two entry points exist during the Phase 1 → Phase 2 migration:
///
/// 1. `init(store:)` — the production TCA path used by Phase 2 (#159) once
///    `MainFeature.path` pushes the feature.
/// 2. `init(portfolio:)` — a legacy bridge that `MainView`,
///    `PortfolioListView`, and `ContributionHistoryListView` still use
///    today. The bridge owns a short-lived `Store` (seeded from the
///    `Portfolio` it was given) and observes the reducer's
///    `legacyNavigation` latch to mirror delegate-driven navigation onto
///    the surrounding `NavigationStack` / `NavigationSplitView`.
///
/// The bridge is removed in #159 once `MainFeature.path` owns navigation
/// directly.
struct PortfolioDetailView: View {
  private let mode: Mode

  init(store: StoreOf<PortfolioDetailFeature>) {
    self.mode = .store(store)
  }

  init(portfolio: Portfolio) {
    self.mode = .legacy(portfolio: portfolio)
  }

  var body: some View {
    switch mode {
    case .store(let store):
      PortfolioDetailContent(store: store)
    case .legacy(let portfolio):
      PortfolioDetailLegacyBridge(portfolio: portfolio)
    }
  }

  private enum Mode {
    case store(StoreOf<PortfolioDetailFeature>)
    case legacy(portfolio: Portfolio)
  }
}

/// Pure TCA renderer for `PortfolioDetailFeature`. Used by the production
/// app once Phase 2 (#159) wires `MainFeature.path`. Until then it is
/// reachable only through the legacy bridge / previews / tests.
private struct PortfolioDetailContent: View {
  let store: StoreOf<PortfolioDetailFeature>

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        summarySection
        holdingsSection
        calculateSection
      }
      .padding(AppLayoutMetrics.mainMargin)
      .frame(maxWidth: AppLayoutMetrics.readableContentMaxWidth, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .navigationTitle(store.snapshot.name)
    .accessibilityIdentifier("portfolio.detail")
    .task { store.send(.task) }
  }

  private var summarySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Summary")
        .valueCompassTextStyle(.headlineMedium)
        .foregroundStyle(Color.appContentPrimary)

      LabeledContent(
        "Monthly Budget",
        value: "$\(PortfolioFormDraft.displayText(for: store.snapshot.monthlyBudget))"
      )
      .valueCompassTextStyle(.data)
      LabeledContent("Moving Average", value: "\(store.snapshot.maWindow) days")
        .valueCompassTextStyle(.data)
      LabeledContent("Categories", value: "\(store.snapshot.categories.count)")
        .valueCompassTextStyle(.data)
      LabeledContent("Market Data", value: store.snapshot.marketDataCompletionText)
        .valueCompassTextStyle(.data)
    }
    .padding()
    .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 16))
  }

  private var holdingsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Holdings")
          .valueCompassTextStyle(.headlineMedium)
          .foregroundStyle(Color.appContentPrimary)

        Spacer()

        Button {
          store.send(.editHoldingsTapped)
        } label: {
          Label("Edit Holdings", systemImage: "list.bullet.rectangle")
        }
        .buttonStyle(.borderedProminent)
        .appMinimumTouchTarget()
        .accessibilityIdentifier("portfolio.detail.editHoldings")
      }

      if store.snapshot.categories.isEmpty {
        ContentUnavailableView {
          Label("No Categories or Tickers", systemImage: "folder.badge.plus")
        } description: {
          Text("Use Edit Holdings to add your first category and ticker before calculating.")
        }
        .accessibilityIdentifier("portfolio.detail.holdings.empty")
      } else {
        ForEach(store.snapshot.categories) { category in
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(category.displayName)
                .valueCompassTextStyle(.bodyLarge)
                .foregroundStyle(Color.appContentPrimary)
              Spacer()
              Text("\(category.weightPercentText)%")
                .valueCompassTextStyle(.data)
                .foregroundStyle(Color.appContentSecondary)
            }

            if category.tickers.isEmpty {
              Label("Warning: no tickers", systemImage: "exclamationmark.circle")
                .valueCompassTextStyle(.labelCaps)
                .foregroundStyle(Color.appNegative)
                .accessibilityIdentifier("portfolio.detail.holdings.warning")
            } else {
              if horizontalSizeClass == .regular {
                tickerTableHeader
              }

              ForEach(category.tickers) { ticker in
                tickerMarketDataRow(for: ticker)
              }
            }
          }
        }

        if !store.snapshot.canCalculate {
          Label(
            "Warnings must be resolved before calculating.",
            systemImage: "exclamationmark.triangle"
          )
          .foregroundStyle(Color.appNegative)
          .accessibilityIdentifier("portfolio.detail.calculateBlocked")
        }
      }
    }
    .padding()
    .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 16))
  }

  private var tickerTableHeader: some View {
    HStack(spacing: AppLayoutMetrics.gridGutter) {
      Text("Ticker")
        .frame(width: 80, alignment: .leading)
      Text("Current Price")
        .frame(maxWidth: .infinity, alignment: .trailing)
      Text("\(store.snapshot.maWindow)-day MA")
        .frame(maxWidth: .infinity, alignment: .trailing)
      Text("Status")
        .frame(width: 88, alignment: .trailing)
    }
    .valueCompassTextStyle(.labelCaps)
    .foregroundStyle(Color.appContentSecondary)
  }

  @ViewBuilder
  private func tickerMarketDataRow(for ticker: TickerSnapshot) -> some View {
    if horizontalSizeClass == .regular {
      HStack(spacing: AppLayoutMetrics.gridGutter) {
        Text(ticker.normalizedSymbol)
          .valueCompassTextStyle(.labelCaps)
          .foregroundStyle(Color.appContentPrimary)
          .frame(width: 80, alignment: .leading)
        Text(ticker.currentPriceText)
          .valueCompassTextStyle(.data)
          .frame(maxWidth: .infinity, alignment: .trailing)
        Text(ticker.movingAverageText)
          .valueCompassTextStyle(.data)
          .frame(maxWidth: .infinity, alignment: .trailing)
        Text(ticker.hasCompleteMarketData ? "Ready" : "Missing")
          .valueCompassTextStyle(.labelCaps)
          .foregroundStyle(Self.tickerMarketDataStatusColor(for: ticker))
          .frame(width: 88, alignment: .trailing)
      }
      .accessibilityIdentifier("portfolio.detail.tickerMarketData")
    } else {
      HStack {
        Text(ticker.normalizedSymbol)
          .valueCompassTextStyle(.labelCaps)
          .foregroundStyle(Color.appContentPrimary)
        Spacer()
        Text(Self.marketDataSummary(for: ticker))
          .valueCompassTextStyle(.data)
          .foregroundStyle(
            ticker.hasCompleteMarketData ? Color.appContentSecondary : Color.appWarning)
      }
      .accessibilityIdentifier("portfolio.detail.tickerMarketData")
    }
  }

  private static func marketDataSummary(for ticker: TickerSnapshot) -> String {
    guard ticker.hasCompleteMarketData else {
      return "Missing price/MA"
    }
    return "Price \(ticker.currentPriceText) | MA \(ticker.movingAverageText)"
  }

  private static func tickerMarketDataStatusColor(for ticker: TickerSnapshot) -> Color {
    ticker.hasCompleteMarketData ? Color.appContentSecondary : Color.appWarning
  }

  private var calculateSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Calculate", systemImage: "function")
          .valueCompassTextStyle(.headlineMedium)
          .foregroundStyle(Color.appContentPrimary)

        Spacer()

        Button {
          store.send(.openHistoryTapped)
        } label: {
          Label("History", systemImage: "clock.arrow.circlepath")
        }
        .buttonStyle(.bordered)
        .appMinimumTouchTarget()
        .accessibilityIdentifier("portfolio.detail.history")

        Button {
          store.send(.calculateTapped)
        } label: {
          Label("Calculate", systemImage: "play.fill")
        }
        .buttonStyle(.borderedProminent)
        .appMinimumTouchTarget()
        .accessibilityIdentifier("portfolio.detail.calculate")
      }

      if let calculationOutput = store.calculationOutput {
        if let error = calculationOutput.error {
          Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
            .foregroundStyle(Color.appNegative)
            .accessibilityIdentifier("portfolio.detail.calculateError")
        } else {
          VStack(alignment: .leading, spacing: 6) {
            Text(
              "Monthly contribution: $\(PortfolioFormDraft.displayText(for: calculationOutput.totalAmount))"
            )
            .valueCompassTextStyle(.data)
            .foregroundStyle(Color.appContentPrimary)
            Text("\(calculationOutput.allocations.count) ticker allocations ready.")
              .foregroundStyle(Color.appContentSecondary)
            Button("View Result") {
              store.send(.viewResultTapped)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("portfolio.detail.viewResult")
          }
          .accessibilityIdentifier("portfolio.detail.calculateSuccess")
        }
      } else {
        Text(
          "Uses the local moving-average VCA calculator after validating budget, weights, tickers, and market data."
        )
        .foregroundStyle(Color.appContentSecondary)
      }
    }
    .padding()
    .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 16))
  }
}

/// Phase 1 bridge between the legacy `MainView` / `PortfolioListView` /
/// `ContributionHistoryListView` (which still pass a `Portfolio` and live
/// inside their own `NavigationStack`) and the new `PortfolioDetailFeature`.
/// Owns a short-lived `Store` (seeded from the given `Portfolio`) and
/// translates the reducer's `legacyNavigation` latch into legacy
/// `navigationDestination` pushes.
///
/// Removed in #159 once `MainFeature.path` owns navigation directly.
private struct PortfolioDetailLegacyBridge: View {
  let portfolio: Portfolio

  @Environment(\.modelContext) private var modelContext
  @StateObject private var holder = PortfolioDetailLegacyStoreHolder()

  @State private var presentedHoldingsEditor = false
  @State private var presentedHistory = false
  @State private var presentedResult = false
  @State private var pendingResultOutput: ContributionOutput?

  var body: some View {
    let store = holder.store(for: portfolio)
    PortfolioDetailContent(store: store)
      .navigationDestination(isPresented: $presentedHoldingsEditor) {
        HoldingsEditorView(portfolio: portfolio)
      }
      .navigationDestination(isPresented: $presentedHistory) {
        ContributionHistoryListView(portfolio: portfolio)
      }
      .navigationDestination(isPresented: $presentedResult) {
        if let output = pendingResultOutput {
          ContributionResultView(
            portfolio: portfolio,
            initialOutput: output
          ) {
            ContributionCalculationService.calculate(
              portfolio: portfolio,
              calculator: MovingAverageContributionCalculator()
            )
          }
        }
      }
      .onChange(of: store.legacyNavigation) { _, newValue in
        handle(intent: newValue, store: store)
      }
  }

  private func handle(
    intent: PortfolioDetailFeature.LegacyNavigation?,
    store: StoreOf<PortfolioDetailFeature>
  ) {
    guard let intent else { return }
    switch intent {
    case .holdingsEditor:
      presentedHoldingsEditor = true
    case .calculationResult(let output):
      pendingResultOutput = output
      presentedResult = true
    case .history:
      presentedHistory = true
    }
    store.send(.legacyNavigationConsumed)
  }
}

/// Holds the short-lived `Store` used by `PortfolioDetailLegacyBridge` so the
/// store survives view re-creations triggered by SwiftUI re-renders. Mirrors
/// the same pattern used by `PortfolioListLegacyStoreHolder`.
@MainActor
private final class PortfolioDetailLegacyStoreHolder: ObservableObject {
  private var cachedStore: StoreOf<PortfolioDetailFeature>?

  func store(for portfolio: Portfolio) -> StoreOf<PortfolioDetailFeature> {
    if let cachedStore {
      return cachedStore
    }
    let initial = PortfolioDetailFeature.State(
      portfolioID: portfolio.id,
      snapshot: PortfolioDetailSnapshot(portfolio: portfolio)
    )
    let store = Store(initialState: initial) {
      PortfolioDetailFeature()
    }
    cachedStore = store
    return store
  }
}
