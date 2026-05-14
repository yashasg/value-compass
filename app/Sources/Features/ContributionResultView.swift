import ComposableArchitecture
import Foundation
import SwiftData
import SwiftUI

/// Per-portfolio contribution-result surface. Renders on top of
/// `ContributionResultFeature` and (in Phase 1) keeps the existing
/// "push History" navigation working through a legacy bridge. Replaces
/// the MVVM definition that previously lived in `MainView.swift`.
///
/// Two entry points exist during the Phase 1 → Phase 2 migration:
///
/// 1. `init(store:)` — the production TCA path used by Phase 2 (#159) once
///    `MainFeature.path` pushes the feature.
/// 2. `init(portfolio:initialOutput:recalculate:)` — a legacy bridge that
///    `MainView` and `PortfolioDetailView` still use today. The bridge owns
///    a short-lived `Store` (seeded from the supplied `Portfolio` and
///    `ContributionOutput`) and observes the reducer's `legacyNavigation`
///    latch to mirror delegate-driven navigation onto the surrounding
///    `NavigationStack`. The `recalculate` closure is wired into the store's
///    `\.contributionCalculator` dependency so Retry exercises the same
///    calculator the caller passed in (matches the legacy MVVM behaviour).
///
/// The bridge is removed in #159 once `MainFeature.path` owns navigation
/// directly.
struct ContributionResultView: View {
  private let mode: Mode

  init(store: StoreOf<ContributionResultFeature>) {
    self.mode = .store(store)
  }

  init(
    portfolio: Portfolio,
    initialOutput: ContributionOutput,
    recalculate: @escaping @MainActor () -> ContributionOutput = {
      ContributionOutput(totalAmount: 0)
    }
  ) {
    self.mode = .legacy(
      portfolio: portfolio,
      initialOutput: initialOutput,
      recalculate: recalculate
    )
  }

  var body: some View {
    switch mode {
    case .store(let store):
      ContributionResultContent(store: store)
    case .legacy(let portfolio, let initialOutput, let recalculate):
      ContributionResultLegacyBridge(
        portfolio: portfolio,
        initialOutput: initialOutput,
        recalculate: recalculate
      )
    }
  }

  private enum Mode {
    case store(StoreOf<ContributionResultFeature>)
    case legacy(
      portfolio: Portfolio,
      initialOutput: ContributionOutput,
      recalculate: @MainActor () -> ContributionOutput
    )
  }
}

/// Pure TCA renderer for `ContributionResultFeature`. Used by the production
/// app once Phase 2 (#159) wires `MainFeature.path`. Until then it is also
/// hosted by `ContributionResultLegacyBridge` so the existing
/// `NavigationStack` keeps presenting it.
struct ContributionResultContent: View {
  @Bindable var store: StoreOf<ContributionResultFeature>

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        if let error = store.output.error {
          calculationErrorView(error)
        } else {
          resultSummary
          categoryBreakdown
          actions
        }
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationTitle(store.output.error == nil ? "Contribution Result" : "Calculation Failed")
    .alert(
      "Could Not Save Result",
      isPresented: Binding(
        get: { store.saveError != nil },
        set: { if !$0 { store.send(.saveErrorDismissed) } }
      ),
      presenting: store.saveError
    ) { _ in
      Button("OK", role: .cancel) { store.send(.saveErrorDismissed) }
    } message: { message in
      Text(message)
    }
    .alert(
      "Result Saved",
      isPresented: Binding(
        get: { store.saveConfirmation != nil },
        set: { if !$0 { store.send(.saveConfirmationDismissed) } }
      ),
      presenting: store.saveConfirmation
    ) { _ in
      Button("OK", role: .cancel) { store.send(.saveConfirmationDismissed) }
    } message: { message in
      Text(message)
    }
    .accessibilityIdentifier("contribution.result")
  }

  private var resultSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Total Monthly Contribution")
        .valueCompassTextStyle(.labelCaps)
        .foregroundStyle(Color.appContentSecondary)

      Text("$\(decimalText(store.output.totalAmount))")
        .valueCompassTextStyle(.displayLarge)
        .minimumScaleFactor(0.7)
        .foregroundStyle(Color.appContentPrimary)
        .accessibilityIdentifier("contribution.result.total")
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 16))
  }

  private var categoryBreakdown: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Breakdown")
        .valueCompassTextStyle(.headlineMedium)
        .foregroundStyle(Color.appContentPrimary)

      ForEach(Array(store.output.categoryBreakdown.enumerated()), id: \.offset) { _, category in
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(category.categoryName)
              .valueCompassTextStyle(.bodyLarge)
              .foregroundStyle(Color.appContentPrimary)
            Spacer()
            Text("$\(decimalText(category.amount))")
              .valueCompassTextStyle(.data)
              .foregroundStyle(Color.appContentPrimary)
          }

          ForEach(
            Array(
              store.output.allocations.filter { $0.categoryName == category.categoryName }
                .enumerated()),
            id: \.offset
          ) { _, allocation in
            HStack {
              Text(allocation.tickerSymbol)
                .valueCompassTextStyle(.labelCaps)
                .foregroundStyle(Color.appContentPrimary)
              Spacer()
              Text("$\(decimalText(allocation.amount))")
                .valueCompassTextStyle(.data)
                .foregroundStyle(Color.appContentPrimary)
              Text("\(percentText(allocation.allocatedWeight))%")
                .valueCompassTextStyle(.data)
                .foregroundStyle(Color.appContentSecondary)
            }
            .accessibilityIdentifier("contribution.result.ticker")
          }
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("contribution.result.category")
      }
    }
  }

  private var actions: some View {
    HStack(spacing: 12) {
      Button {
        store.send(.saveTapped)
      } label: {
        Label("Save", systemImage: "tray.and.arrow.down")
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("contribution.result.save")

      Button {
        store.send(.openHistoryTapped)
      } label: {
        Label("History", systemImage: "clock.arrow.circlepath")
      }
      .buttonStyle(.bordered)
      .accessibilityIdentifier("contribution.result.history")
    }
  }

  private func calculationErrorView(_ error: LocalizedError) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
        .valueCompassTextStyle(.bodyLarge)
        .foregroundStyle(Color.appError)
        .accessibilityIdentifier("contribution.result.error")

      Button {
        store.send(.retryTapped)
      } label: {
        Label("Retry", systemImage: "arrow.clockwise")
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("contribution.result.retry")
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 16))
  }

  private func decimalText(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }

  private func percentText(_ value: Decimal) -> String {
    decimalText(value * 100)
  }
}

/// Phase-1 bridge that owns a short-lived `Store` for non-TCA call sites
/// (`MainView`, `PortfolioDetailView`). Observes the reducer's
/// `legacyNavigation` latch to push `ContributionHistoryListView` onto the
/// surrounding `NavigationStack`. Removed in #159 once `MainFeature.path`
/// owns navigation.
private struct ContributionResultLegacyBridge: View {
  let portfolio: Portfolio
  let initialOutput: ContributionOutput
  let recalculate: @MainActor () -> ContributionOutput

  @Environment(\.modelContext) private var modelContext
  @StateObject private var holder = ContributionResultLegacyStoreHolder()
  @State private var presentedHistory = false

  var body: some View {
    let store = holder.store(
      portfolioID: portfolio.id,
      initialOutput: initialOutput,
      modelContainer: modelContext.container,
      recalculate: recalculate
    )
    ContributionResultContent(store: store)
      .navigationDestination(isPresented: $presentedHistory) {
        ContributionHistoryView(portfolio: portfolio)
      }
      .onChange(of: store.legacyNavigation) { _, newValue in
        handle(intent: newValue, store: store)
      }
  }

  private func handle(
    intent: ContributionResultFeature.LegacyNavigation?,
    store: StoreOf<ContributionResultFeature>
  ) {
    guard let intent else { return }
    switch intent {
    case .history:
      presentedHistory = true
    }
    store.send(.legacyNavigationConsumed)
  }
}

/// Holds a single `Store` for the lifetime of a
/// `ContributionResultLegacyBridge` so SwiftUI re-renders do not rebuild
/// the reducer state. The store is built with the surrounding SwiftData
/// `ModelContainer` and the caller-supplied `recalculate` closure overridden
/// onto the reducer's dependencies so Save/Retry hit the same persistence
/// + calculator the legacy MVVM view used.
@MainActor
private final class ContributionResultLegacyStoreHolder: ObservableObject {
  private var cachedStore: StoreOf<ContributionResultFeature>?

  func store(
    portfolioID: UUID,
    initialOutput: ContributionOutput,
    modelContainer: ModelContainer,
    recalculate: @escaping @MainActor () -> ContributionOutput
  ) -> StoreOf<ContributionResultFeature> {
    if let cachedStore { return cachedStore }
    let containerClient = ModelContainerClient(container: { modelContainer })
    let calculatorClient = ContributionCalculatorClient(
      calculate: { _ in recalculate() }
    )
    let made = withDependencies {
      $0.modelContainer = containerClient
      $0.contributionCalculator = calculatorClient
    } operation: {
      Store(
        initialState: ContributionResultFeature.State(
          portfolioID: portfolioID,
          output: initialOutput
        )
      ) {
        ContributionResultFeature()
      }
    }
    cachedStore = made
    return made
  }
}
