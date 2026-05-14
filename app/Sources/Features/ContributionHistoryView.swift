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
