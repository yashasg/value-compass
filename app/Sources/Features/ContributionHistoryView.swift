import ComposableArchitecture
import SwiftData
import SwiftUI

/// Per-portfolio contribution-history surface (list + per-record detail).
/// Renders on top of `ContributionHistoryFeature`. Replaces the MVVM
/// definitions that previously lived in `MainView.swift`
/// (`ContributionHistoryListView`, `ContributionHistoryRowView`,
/// `ContributionHistoryDetailView`).
///
/// Two entry points exist during the Phase 1 → Phase 2 migration:
///
/// 1. `init(store:)` — the production TCA path used by Phase 2 (#159) once
///    `MainFeature.path` pushes the feature.
/// 2. `init(portfolio:)` — a legacy bridge that `MainView` and (post-#156)
///    `ContributionResultView` still use today. The bridge owns a
///    short-lived `Store` (seeded from the supplied `Portfolio`) and
///    renders the list. The bridge also pushes `ContributionHistoryDetailView`
///    via `NavigationLink` so the surrounding `NavigationStack` keeps
///    behaving as it does today.
///
/// The bridge is removed in #159 once `MainFeature.path` owns navigation.
struct ContributionHistoryView: View {
  private let mode: Mode

  init(store: StoreOf<ContributionHistoryFeature>) {
    self.mode = .store(store)
  }

  init(portfolio: Portfolio) {
    self.mode = .legacy(portfolioID: portfolio.id)
  }

  var body: some View {
    switch mode {
    case .store(let store):
      ContributionHistoryContent(store: store)
    case .legacy(let portfolioID):
      ContributionHistoryLegacyBridge(portfolioID: portfolioID)
    }
  }

  private enum Mode {
    case store(StoreOf<ContributionHistoryFeature>)
    case legacy(portfolioID: UUID)
  }
}

/// Pure TCA renderer for `ContributionHistoryFeature`. Used by the
/// production app once Phase 2 (#159) wires `MainFeature.path`. Until
/// then it is also hosted by `ContributionHistoryLegacyBridge`.
private struct ContributionHistoryContent: View {
  @Bindable var store: StoreOf<ContributionHistoryFeature>

  var body: some View {
    List {
      if store.sections.isEmpty {
        ContentUnavailableView {
          Label("No Saved Results", systemImage: "clock")
        } description: {
          Text("Run Calculate and save the result to build local contribution history.")
        } actions: {
          Button {
            store.send(.openCalculate)
          } label: {
            Label("Calculate", systemImage: "function")
          }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("contribution.history.calculate")
        }
      } else {
        ForEach(store.sections) { section in
          Section {
            ForEach(section.records) { record in
              NavigationLink {
                ContributionHistoryDetailContent(record: record)
              } label: {
                ContributionHistoryRow(record: record)
              }
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Delete", role: .destructive) {
                  store.send(.deleteTapped(record: record))
                }
              }
              .accessibilityIdentifier("contribution.history.record")
            }
            .onDelete { offsets in
              if let firstOffset = offsets.first {
                store.send(.deleteTapped(record: section.records[firstOffset]))
              }
            }
          } header: {
            HStack {
              Text(section.title)
              Spacer()
              Text("$\(decimalText(section.totalAmount))")
            }
          }
        }
      }
    }
    .navigationTitle("History")
    .task { store.send(.task) }
    .alert(
      "Delete Saved Result?",
      isPresented: Binding(
        get: { store.pendingDeletion != nil },
        set: { if !$0 { store.send(.cancelDelete) } }
      ),
      presenting: store.pendingDeletion
    ) { _ in
      Button("Delete", role: .destructive) { store.send(.confirmDelete) }
      Button("Cancel", role: .cancel) { store.send(.cancelDelete) }
    } message: { record in
      Text("This removes the saved result from \(dateText(record.date)).")
    }
    .alert(
      "Could Not Delete Result",
      isPresented: Binding(
        get: { store.deleteError != nil },
        set: { if !$0 { store.send(.deleteErrorDismissed) } }
      ),
      presenting: store.deleteError
    ) { _ in
      Button("OK", role: .cancel) { store.send(.deleteErrorDismissed) }
    } message: { message in
      Text(message)
    }
    .accessibilityIdentifier("contribution.history")
  }

  private func decimalText(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }

  private func dateText(_ date: Date) -> String {
    ContributionHistoryDateFormatters.day.string(from: date)
  }
}

/// Single row rendering for a `ContributionRecordSnapshot`. Mirrors the
/// MVVM `ContributionHistoryRowView` it replaces verbatim.
private struct ContributionHistoryRow: View {
  let record: ContributionRecordSnapshot

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(ContributionHistoryDateFormatters.day.string(from: record.date))
          .valueCompassTextStyle(.bodyLarge)
          .foregroundStyle(Color.appContentPrimary)
        Text("\(record.tickerAllocations.count) ticker allocations")
          .valueCompassTextStyle(.bodySmall)
          .foregroundStyle(Color.appContentSecondary)
      }

      Spacer()

      Text("$\(decimalText(record.totalAmount))")
        .valueCompassTextStyle(.data)
        .foregroundStyle(Color.appContentPrimary)
    }
    .accessibilityElement(children: .combine)
  }

  private func decimalText(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }
}

/// Detail surface for a single `ContributionRecordSnapshot`. Mirrors the
/// MVVM `ContributionHistoryDetailView` it replaces verbatim — the
/// snapshot's `categoryBreakdown` and `tickerAllocations` are pre-sorted
/// inside `BackgroundModelActor.loadContributionRecordSnapshots(...)`.
private struct ContributionHistoryDetailContent: View {
  let record: ContributionRecordSnapshot

  var body: some View {
    List {
      Section("Summary") {
        LabeledContent(
          "Date", value: ContributionHistoryDateFormatters.day.string(from: record.date))
        LabeledContent("Total", value: "$\(decimalText(record.totalAmount))")
      }

      Section("Category Totals") {
        ForEach(record.categoryBreakdown) { category in
          LabeledContent(category.categoryName, value: "$\(decimalText(category.amount))")
            .accessibilityIdentifier("contribution.history.detail.category")
        }
      }

      Section("Ticker Breakdown") {
        ForEach(record.tickerAllocations) { allocation in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(allocation.tickerSymbol)
                .valueCompassTextStyle(.labelCaps)
                .foregroundStyle(Color.appContentPrimary)
              Spacer()
              Text("$\(decimalText(allocation.amount))")
                .valueCompassTextStyle(.data)
                .foregroundStyle(Color.appContentPrimary)
            }
            Text(allocation.categoryName)
              .valueCompassTextStyle(.bodySmall)
              .foregroundStyle(Color.appContentSecondary)
          }
          .accessibilityIdentifier("contribution.history.detail.ticker")
        }
      }
    }
    .navigationTitle("Saved Result")
    .accessibilityIdentifier("contribution.history.detail")
  }

  private func decimalText(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }
}

/// Phase-1 bridge that owns a short-lived `Store` for non-TCA call sites
/// (`MainView`, post-#156 `ContributionResultView`). Observes the
/// reducer's `legacyNavigation` latch to push `PortfolioDetailView` onto
/// the surrounding `NavigationStack` whenever the empty-state
/// `Calculate` CTA fires. Removed in #159 once `MainFeature.path` owns
/// navigation.
private struct ContributionHistoryLegacyBridge: View {
  let portfolioID: UUID

  @Environment(\.modelContext) private var modelContext
  @StateObject private var holder = ContributionHistoryLegacyStoreHolder()
  @State private var presentedCalculatePortfolio: Portfolio?

  var body: some View {
    let store = holder.store(portfolioID: portfolioID)
    ContributionHistoryContent(store: store)
      .navigationDestination(item: $presentedCalculatePortfolio) { portfolio in
        PortfolioDetailView(portfolio: portfolio)
      }
      .onChange(of: store.legacyNavigation) { _, newValue in
        handle(intent: newValue, store: store)
      }
      .onChange(of: presentedCalculatePortfolio) { previous, current in
        // Reload after the pushed Calculate destination is dismissed so newly
        // saved ContributionRecords appear when the user pops back. Removed
        // alongside this bridge in #159.
        if previous != nil, current == nil {
          store.send(.task)
        }
      }
  }

  private func handle(
    intent: ContributionHistoryFeature.LegacyNavigation?,
    store: StoreOf<ContributionHistoryFeature>
  ) {
    guard let intent else { return }
    switch intent {
    case .calculate(let id):
      let descriptor = FetchDescriptor<Portfolio>(
        predicate: #Predicate { $0.id == id }
      )
      if let portfolio = try? modelContext.fetch(descriptor).first {
        presentedCalculatePortfolio = portfolio
      }
    }
    store.send(.legacyNavigationConsumed)
  }
}

/// Holds a single `Store` for the lifetime of a
/// `ContributionHistoryLegacyBridge` so SwiftUI re-renders do not rebuild
/// the reducer state.
@MainActor
private final class ContributionHistoryLegacyStoreHolder: ObservableObject {
  private var store: StoreOf<ContributionHistoryFeature>?

  func store(portfolioID: UUID) -> StoreOf<ContributionHistoryFeature> {
    if let store { return store }
    let made = Store(
      initialState: ContributionHistoryFeature.State(portfolioID: portfolioID)
    ) {
      ContributionHistoryFeature()
    }
    store = made
    return made
  }
}

#Preview("Empty") {
  NavigationStack {
    ContributionHistoryView(
      store: Store(
        initialState: ContributionHistoryFeature.State(portfolioID: UUID())
      ) {
        ContributionHistoryFeature()
      }
    )
  }
}

#Preview("Populated") {
  NavigationStack {
    ContributionHistoryView(
      store: Store(
        initialState: ContributionHistoryFeature.State(
          portfolioID: UUID(),
          sections: [
            ContributionHistoryMonthSection(
              monthStart: Date(),
              title: "May 2026",
              records: [
                ContributionRecordSnapshot(
                  id: UUID(),
                  date: Date(),
                  totalAmount: 1_500,
                  categoryBreakdown: [
                    CategoryContributionSnapshot(
                      categoryName: "Core",
                      amount: 1_500,
                      allocatedWeight: 1
                    )
                  ],
                  tickerAllocations: [
                    TickerAllocationSnapshot(
                      id: UUID(),
                      tickerSymbol: "VTI",
                      categoryName: "Core",
                      amount: 1_500,
                      allocatedWeight: 1
                    )
                  ]
                )
              ]
            )
          ]
        )
      ) {
        ContributionHistoryFeature()
      }
    )
  }
}
