import ComposableArchitecture
import SwiftUI

/// Per-portfolio contribution-history surface (list + per-record detail).
/// Renders on top of `ContributionHistoryFeature`. Replaces the MVVM
/// definitions that previously lived in `MainView.swift`
/// (`ContributionHistoryListView`, `ContributionHistoryRowView`,
/// `ContributionHistoryDetailView`). Pure TCA: scope a
/// `StoreOf<ContributionHistoryFeature>` from the parent and pass it in.
struct ContributionHistoryView: View {
  let store: StoreOf<ContributionHistoryFeature>

  init(store: StoreOf<ContributionHistoryFeature>) {
    self.store = store
  }

  var body: some View {
    ContributionHistoryContent(store: store)
  }
}

/// TCA renderer for `ContributionHistoryFeature`. Used by the production
/// app via `MainFeature.path` (wired in #159) and by previews / tests.
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
              // Mirror every `.swipeActions` button as a semantic
              // `.accessibilityAction(named:)` so the destructive Delete
              // is also reachable to Voice Control ("Tap Delete"),
              // Switch Control (action menu), and Full Keyboard Access
              // (action shortcut) — none of which can synthesize the
              // trailing-swipe gesture today. VoiceOver users gain a
              // labeled entry in the Actions rotor alongside the
              // existing swipe-mirror. WCAG 2.5.1 (Pointer Gestures):
              // any single-point gesture-only path must have an
              // equivalent non-gesture alternative (#285).
              .accessibilityAction(named: Text("Delete")) {
                store.send(.deleteTapped(record: record))
              }
              .accessibilityIdentifier("contribution.history.record")
            }
          } header: {
            HStack {
              Text(section.title)
              Spacer()
              Text(section.totalAmount.appCurrencyFormatted())
            }
          }
        }
        // #233: render `Disclaimer.text` so every saved per-record
        // dollar total in the list above is contemporaneous with the
        // canonical informational-only disclaimer.
        Section {
          CalculationOutputDisclaimerFooter()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
      }
    }
    .navigationTitle("History")
    .task { store.send(.task) }
    .confirmationDialog(
      Self.deletionDialogTitle(for: store.pendingDeletion),
      isPresented: Binding(
        get: { store.pendingDeletion != nil },
        set: { isPresented in
          if !isPresented { store.send(.cancelDelete) }
        }
      ),
      titleVisibility: .visible,
      presenting: store.pendingDeletion
    ) { _ in
      Button("Delete", role: .destructive) { store.send(.confirmDelete) }
        .accessibilityIdentifier("contribution.history.delete.confirm")
      Button("Cancel", role: .cancel) { store.send(.cancelDelete) }
        .accessibilityIdentifier("contribution.history.delete.cancel")
    } message: { record in
      Text("This removes the saved result from \(Self.dateText(record.date)).")
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

  private static func dateText(_ date: Date) -> String {
    ContributionHistoryDateFormatters.day.string(from: date)
  }

  /// Builds the confirmation-dialog title from the staged record so the
  /// destructive action is unambiguous about *which* saved result is being
  /// deleted (HIG → *Patterns → Confirming an action*: "Make sure the
  /// destructive choice is clearly identified"). Falls back to a generic
  /// title only as a safety net for the brief window when SwiftUI evaluates
  /// the title while `pendingDeletion` is being cleared.
  private static func deletionDialogTitle(for record: ContributionRecordSnapshot?) -> String {
    guard let record else { return "Delete Saved Result?" }
    return "Delete result from \(dateText(record.date))?"
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

      Text(record.totalAmount.appCurrencyFormatted())
        .valueCompassTextStyle(.data)
        .foregroundStyle(Color.appContentPrimary)
    }
    .accessibilityElement(children: .combine)
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
        LabeledContent("Total", value: record.totalAmount.appCurrencyFormatted())
      }

      Section("Category Totals") {
        ForEach(record.categoryBreakdown) { category in
          LabeledContent(category.categoryName, value: category.amount.appCurrencyFormatted())
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
              Text(allocation.amount.appCurrencyFormatted())
                .valueCompassTextStyle(.data)
                .foregroundStyle(Color.appContentPrimary)
            }
            Text(allocation.categoryName)
              .valueCompassTextStyle(.bodySmall)
              .foregroundStyle(Color.appContentSecondary)
          }
          .accessibilityIdentifier("contribution.history.detail.ticker")
          // #227: the saved-result ticker breakdown row pairs a symbol
          // with its dollar amount and a category footer line; without
          // explicit grouping VoiceOver exposes those three texts as
          // independent focus targets. Collapse the whole VStack into
          // one element with label=symbol and value=amount/category
          // (composer pinned in `FinancialRowAccessibilityTests`).
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(FinancialRowAccessibility.label(forHistoryAllocation: allocation))
          .accessibilityValue(FinancialRowAccessibility.value(forHistoryAllocation: allocation))
        }
      }

      // #233: render `Disclaimer.text` alongside the per-record total
      // and per-ticker dollar amounts above. Mirrors the list surface
      // so a saved-result drill-down still ships the disclaimer.
      Section {
        CalculationOutputDisclaimerFooter()
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
      }
    }
    .navigationTitle("Saved Result")
    .accessibilityIdentifier("contribution.history.detail")
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
