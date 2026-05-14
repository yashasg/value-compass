import ComposableArchitecture
import Foundation
import SwiftData

/// Reducer that drives the post-calculation history list + per-record detail
/// surface today rendered by `ContributionHistoryListView` /
/// `ContributionHistoryDetailView`. Replaces the Phase 0 placeholder.
///
/// State holds a value-typed projection of the persisted
/// `ContributionRecord` rows so the reducer never owns a SwiftData
/// `@Model` instance (which is `MainActor`-isolated and not `Sendable`).
/// Reads/writes go through `@Dependency(\.modelContainer)` on a
/// `BackgroundModelActor` so the SwiftData I/O happens off the main
/// thread.
///
/// `MainFeature.path` consumes the `Delegate.openCalculate` action to push
/// the calculate flow onto the surrounding navigation; the reducer no
/// longer carries a Phase-1 navigation latch.
@Reducer
struct ContributionHistoryFeature {
  @ObservableState
  struct State: Equatable {
    let portfolioID: UUID
    var sections: [ContributionHistoryMonthSection] = []
    var pendingDeletion: ContributionRecordSnapshot?
    var deleteError: String?

    init(
      portfolioID: UUID,
      sections: [ContributionHistoryMonthSection] = [],
      pendingDeletion: ContributionRecordSnapshot? = nil,
      deleteError: String? = nil
    ) {
      self.portfolioID = portfolioID
      self.sections = sections
      self.pendingDeletion = pendingDeletion
      self.deleteError = deleteError
    }
  }

  enum Action: Equatable {
    case task
    case sectionsLoaded([ContributionHistoryMonthSection])
    case deleteTapped(record: ContributionRecordSnapshot)
    case confirmDelete
    case cancelDelete
    case deleteFailed(String)
    case deleteErrorDismissed
    case openCalculate
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable {
      case openCalculate(portfolioID: UUID)
    }
  }

  @Dependency(\.modelContainer) var modelContainer

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        let id = state.portfolioID
        return .run { [modelContainer] send in
          do {
            let sections = try await Self.loadSections(
              modelContainer: modelContainer,
              portfolioID: id
            )
            await send(.sectionsLoaded(sections))
          } catch {
            await send(.sectionsLoaded([]))
          }
        }

      case .sectionsLoaded(let sections):
        state.sections = sections
        if let pending = state.pendingDeletion,
          !sections.contains(where: { $0.records.contains { $0.id == pending.id } })
        {
          state.pendingDeletion = nil
        }
        return .none

      case .deleteTapped(let record):
        state.pendingDeletion = record
        return .none

      case .confirmDelete:
        guard let pending = state.pendingDeletion else { return .none }
        state.pendingDeletion = nil
        let id = state.portfolioID
        return .run { [modelContainer] send in
          do {
            try await Self.deleteRecord(
              modelContainer: modelContainer,
              recordID: pending.id
            )
            let sections = try await Self.loadSections(
              modelContainer: modelContainer,
              portfolioID: id
            )
            await send(.sectionsLoaded(sections))
          } catch {
            await send(.deleteFailed(error.localizedDescription))
          }
        }

      case .cancelDelete:
        state.pendingDeletion = nil
        return .none

      case .deleteFailed(let message):
        state.deleteError = message
        return .none

      case .deleteErrorDismissed:
        state.deleteError = nil
        return .none

      case .openCalculate:
        let id = state.portfolioID
        return .send(.delegate(.openCalculate(portfolioID: id)))

      case .delegate:
        return .none
      }
    }
  }

  private static func loadSections(
    modelContainer: ModelContainerClient,
    portfolioID: UUID
  ) async throws -> [ContributionHistoryMonthSection] {
    try await withCheckedThrowingContinuation { continuation in
      Task {
        do {
          let collected = LockIsolated<[ContributionRecordSnapshot]>([])
          try await modelContainer.task { actor in
            let snapshots = try await actor.loadContributionRecordSnapshots(
              portfolioID: portfolioID
            )
            collected.setValue(snapshots)
          }
          continuation.resume(
            returning: ContributionHistoryMonthSection.group(records: collected.value)
          )
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private static func deleteRecord(
    modelContainer: ModelContainerClient,
    recordID: UUID
  ) async throws {
    try await modelContainer.task { actor in
      try await actor.deleteContributionRecord(id: recordID)
    }
  }
}

/// Sendable projection of `ContributionRecord` for use in
/// `ContributionHistoryFeature` state. SwiftData `@Model` classes are
/// `MainActor`-isolated and not `Sendable`, so the reducer mirrors the
/// fields the list row + detail view need.
struct ContributionRecordSnapshot: Equatable, Identifiable, Sendable {
  let id: UUID
  let date: Date
  let totalAmount: Decimal
  let categoryBreakdown: [CategoryContributionSnapshot]
  let tickerAllocations: [TickerAllocationSnapshot]
}

/// Sendable projection of `CategoryContribution` for the detail view's
/// "Category Totals" section.
struct CategoryContributionSnapshot: Equatable, Identifiable, Sendable {
  var id: String { categoryName }
  let categoryName: String
  let amount: Decimal
  let allocatedWeight: Decimal
}

/// Sendable projection of `TickerAllocation` for the detail view's
/// "Ticker Breakdown" section.
struct TickerAllocationSnapshot: Equatable, Identifiable, Sendable {
  let id: UUID
  let tickerSymbol: String
  let categoryName: String
  let amount: Decimal
  let allocatedWeight: Decimal
}

/// Month-grouped slice of `ContributionRecordSnapshot` rows. Lives in the
/// reducer file because `ContributionHistoryFeature.State` owns it and the
/// grouping helper is a pure value-typed transformation.
struct ContributionHistoryMonthSection: Equatable, Identifiable, Sendable {
  let monthStart: Date
  let title: String
  let records: [ContributionRecordSnapshot]

  var id: Date { monthStart }

  var totalAmount: Decimal {
    records.reduce(Decimal(0)) { $0 + $1.totalAmount }
  }

  static func group(
    records: [ContributionRecordSnapshot],
    calendar: Calendar = .current
  ) -> [ContributionHistoryMonthSection] {
    let sortedRecords = records.sorted { $0.date > $1.date }
    let groupedRecords = Dictionary(grouping: sortedRecords) { record in
      calendar.dateInterval(of: .month, for: record.date)?.start ?? record.date
    }

    return groupedRecords.keys.sorted(by: >).map { monthStart in
      ContributionHistoryMonthSection(
        monthStart: monthStart,
        title: ContributionHistoryDateFormatters.monthString(from: monthStart, calendar: calendar),
        records: groupedRecords[monthStart] ?? []
      )
    }
  }
}

/// Date formatters shared by the history list and detail views. Lives in
/// the reducer file because the formatter strings are derived from
/// reducer-owned state (`monthStart`, `record.date`) — the views just
/// render the resulting string.
enum ContributionHistoryDateFormatters {
  static let day: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
  }()

  static func monthString(from date: Date, calendar: Calendar) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    return formatter.string(from: date)
  }
}

extension BackgroundModelActor {
  /// Fetches contribution records for a portfolio sorted newest-first and
  /// projects them to `ContributionRecordSnapshot` values inside the
  /// actor's isolation so the call site can return the result across
  /// actor boundaries.
  func loadContributionRecordSnapshots(
    portfolioID: UUID
  ) throws -> [ContributionRecordSnapshot] {
    let descriptor = FetchDescriptor<ContributionRecord>(
      predicate: #Predicate { $0.portfolioId == portfolioID },
      sortBy: [SortDescriptor(\ContributionRecord.date, order: .reverse)]
    )
    let records = try modelContext.fetch(descriptor)
    return records.map { record in
      ContributionRecordSnapshot(
        id: record.id,
        date: record.date,
        totalAmount: record.totalAmount,
        categoryBreakdown: record.categoryBreakdown
          .sorted { lhs, rhs in
            if lhs.categoryName == rhs.categoryName {
              return lhs.amount > rhs.amount
            }
            return lhs.categoryName < rhs.categoryName
          }
          .map { contribution in
            CategoryContributionSnapshot(
              categoryName: contribution.categoryName,
              amount: contribution.amount,
              allocatedWeight: contribution.allocatedWeight
            )
          },
        tickerAllocations: record.tickerAllocations
          .sorted { lhs, rhs in
            if lhs.categoryName == rhs.categoryName {
              return lhs.tickerSymbol < rhs.tickerSymbol
            }
            return lhs.categoryName < rhs.categoryName
          }
          .map { allocation in
            TickerAllocationSnapshot(
              id: UUID(),
              tickerSymbol: allocation.tickerSymbol,
              categoryName: allocation.categoryName,
              amount: allocation.amount,
              allocatedWeight: allocation.allocatedWeight
            )
          }
      )
    }
  }

  /// Deletes the contribution record with the given identifier and saves.
  /// No-op when the record is not present (e.g. already deleted from
  /// another context).
  func deleteContributionRecord(id: UUID) throws {
    let descriptor = FetchDescriptor<ContributionRecord>(
      predicate: #Predicate { $0.id == id }
    )
    guard let record = try modelContext.fetch(descriptor).first else { return }
    modelContext.delete(record)
    try modelContext.save()
  }
}
