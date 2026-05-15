import ComposableArchitecture
import SwiftUI
import UIKit

/// Per-portfolio detail surface. Renders on top of `PortfolioDetailFeature`
/// and pushes `HoldingsEditorView` / `ContributionResultView` /
/// `ContributionHistoryView` for delegate-driven navigation. Replaces the
/// MVVM definition that previously lived in `MainView.swift`. Pure TCA:
/// scope a `StoreOf<PortfolioDetailFeature>` from the parent and pass it
/// in.
struct PortfolioDetailView: View {
  @Bindable var store: StoreOf<PortfolioDetailFeature>

  init(store: StoreOf<PortfolioDetailFeature>) {
    self.store = store
  }

  var body: some View {
    PortfolioDetailContent(store: store)
      .sheet(
        item: $store.scope(state: \.holdingsEditor, action: \.holdingsEditor)
      ) { editorStore in
        HoldingsEditorView(store: editorStore)
      }
  }
}

/// TCA renderer for `PortfolioDetailFeature`. Used by the production app
/// via `MainFeature.path` (wired in #159) and by previews / tests.
private struct PortfolioDetailContent: View {
  @Bindable var store: StoreOf<PortfolioDetailFeature>

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        summarySection
        holdingsSection
        calculateSection
        // #233: render `Disclaimer.text` on the surface that prints the
        // calculate-section "Monthly contribution: $X" summary. Placed
        // unconditionally (not gated on `store.calculationOutput`) so
        // it is also present when the user lands on the screen before
        // running Calculate — the calculate button is in view from
        // first paint, and the disclaimer must accompany the action
        // surface, not only the post-success summary.
        CalculationOutputDisclaimerFooter()
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
      // #227: the regular-width 4-column ticker market-data row splits
      // into four unrelated VoiceOver focus targets by default. Collapse
      // it into one element with label=symbol and value=readable
      // price/MA/status sentence (composer pinned in
      // `FinancialRowAccessibilityTests`).
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(FinancialRowAccessibility.label(forTicker: ticker))
      .accessibilityValue(
        FinancialRowAccessibility.value(forTicker: ticker, maWindow: store.snapshot.maWindow))
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
      // #227: the compact (iPhone) two-cell variant pairs symbol with
      // an opaque "Price X | MA Y" summary; collapse to the same
      // spoken contract as the regular-width row so screen-reader
      // users hear identical content regardless of size class.
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(FinancialRowAccessibility.label(forTicker: ticker))
      .accessibilityValue(
        FinancialRowAccessibility.value(forTicker: ticker, maWindow: store.snapshot.maWindow))
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
          Label("Calculate", systemImage: "function")
        }
        .buttonStyle(.borderedProminent)
        .appMinimumTouchTarget()
        .disabled(!store.snapshot.canCalculate)
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
    // WCAG 2.2 SC 4.1.3 (Status Messages) / #352: when the Calculate
    // button completes, VoiceOver focus stays on the button and the
    // inserted result block is silent by default. Post the result
    // summary (or error) imperatively so AT users hear the outcome
    // without having to swipe through the screen to find it.
    .onChange(of: store.calculationOutput) { _, newValue in
      guard let newValue else { return }
      let message = PortfolioDetailAccessibility.announcement(for: newValue)
      UIAccessibility.post(notification: .announcement, argument: message)
    }
  }
}

/// Composes the VoiceOver announcement posted by
/// `PortfolioDetailContent.calculateSection` when
/// `PortfolioDetailFeature.State.calculationOutput` transitions to a new
/// value. Mirrors the on-screen summary so screen-reader users hear what
/// sighted users see. Exposed at file scope (not nested inside the view)
/// so unit tests can pin every branch without spinning up a SwiftUI host.
enum PortfolioDetailAccessibility {
  static func announcement(for output: ContributionOutput) -> String {
    if let error = output.error {
      return error.localizedDescription
    }
    let amount = PortfolioFormDraft.displayText(for: output.totalAmount)
    let count = output.allocations.count
    let allocationWord = count == 1 ? "allocation" : "allocations"
    return
      "Calculation complete. Monthly contribution $\(amount). \(count) ticker \(allocationWord) ready."
  }
}
