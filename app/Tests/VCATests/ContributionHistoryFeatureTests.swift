import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import SwiftData
import XCTest

@testable import VCA

/// `TestStore` coverage for `ContributionHistoryFeature` (issue #195, last
/// child of #185).
///
/// Pins the saved-snapshot list reducer:
///
/// - `.task` empty / two-month happy path / throwing container failure.
/// - `.sectionsLoaded(_)` writes `state.sections` and clears `pendingDeletion`
///   only when the pending record disappears from the new payload.
/// - `.deleteTapped`, `.cancelDelete`, `.deleteErrorDismissed` mutations.
/// - `.confirmDelete` no-op guard, happy path through
///   `BackgroundModelActor.deleteContributionRecord` + reload, and the
///   throwing-container failure that emits `.deleteFailed(message)`.
/// - `.openCalculate` → `.delegate(.openCalculate(portfolioID:))`.
/// - Pure helper coverage for
///   `ContributionHistoryMonthSection.group(records:calendar:)`.
@MainActor
final class ContributionHistoryFeatureTests: XCTestCase {
  // MARK: - .task

  func testTaskEmptyContainerLoadsEmptySections() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let portfolioID = UUID()

    let store = TestStore(
      initialState: ContributionHistoryFeature.State(portfolioID: portfolioID)
    ) {
      ContributionHistoryFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
    }

    await store.send(.task)
    await store.receive(.sectionsLoaded([]))
  }

  func testTaskWithTwoRecordsSpanningTwoMonthsLoadsNewestFirstSections() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = container.mainContext

    let portfolioID = UUID()
    let portfolio = Portfolio(
      id: portfolioID, name: "Growth",
      monthlyBudget: Decimal(500), maWindow: 50,
      createdAt: Date(timeIntervalSince1970: 1_600_000_000))
    context.insert(portfolio)

    // Two records ~45 days apart so they always land in distinct months
    // regardless of the test machine's timezone.
    let olderRecordID = UUID()
    let newerRecordID = UUID()
    let olderDate = Date(timeIntervalSince1970: 1_700_000_000)  // mid-Nov 2023
    let newerDate = Date(timeIntervalSince1970: 1_704_000_000)  // mid-Dec 2023

    let olderRecord = ContributionRecord(
      id: olderRecordID,
      portfolioId: portfolioID,
      date: olderDate,
      totalAmount: Decimal(100),
      portfolio: portfolio,
      categoryBreakdown: [
        CategoryContribution(categoryName: "Equity", amount: Decimal(100), allocatedWeight: 1)
      ],
      tickerAllocations: [])
    let newerRecord = ContributionRecord(
      id: newerRecordID,
      portfolioId: portfolioID,
      date: newerDate,
      totalAmount: Decimal(250),
      portfolio: portfolio,
      categoryBreakdown: [
        CategoryContribution(categoryName: "Equity", amount: Decimal(250), allocatedWeight: 1)
      ],
      tickerAllocations: [])
    portfolio.contributionRecords = [olderRecord, newerRecord]
    try context.save()

    let store = TestStore(
      initialState: ContributionHistoryFeature.State(portfolioID: portfolioID)
    ) {
      ContributionHistoryFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
    }
    // The grouping helper formats month titles with `calendar: .current`,
    // which is timezone-dependent and would make a strict `.sectionsLoaded`
    // payload comparison flaky across hosts. Drain the received action with
    // exhaustivity off and assert the structural invariants (count,
    // ordering, IDs, totals) explicitly. The dedicated
    // `group(records:calendar:)` tests below pin title formatting under a
    // fixed UTC calendar.
    store.exhaustivity = .off

    await store.send(.task)
    await store.skipReceivedActions()

    XCTAssertEqual(store.state.sections.count, 2)
    // Sections are sorted month-start descending (newest month first).
    XCTAssertGreaterThan(store.state.sections[0].monthStart, store.state.sections[1].monthStart)
    XCTAssertEqual(store.state.sections[0].records.map(\.id), [newerRecordID])
    XCTAssertEqual(store.state.sections[1].records.map(\.id), [olderRecordID])
    XCTAssertEqual(store.state.sections[0].totalAmount, Decimal(250))
    XCTAssertEqual(store.state.sections[1].totalAmount, Decimal(100))
  }

  func testTaskWithThrowingContainerLoadsEmptySections() async {
    struct StubError: LocalizedError, Equatable {
      var errorDescription: String? { "boom" }
    }

    let portfolioID = UUID()
    let store = TestStore(
      initialState: ContributionHistoryFeature.State(portfolioID: portfolioID)
    ) {
      ContributionHistoryFeature()
    } withDependencies: {
      $0.modelContainer.container = { throw StubError() }
    }

    await store.send(.task)
    // The `.task` effect swallows the error and emits an empty payload so
    // the list view renders the empty state instead of crashing.
    await store.receive(.sectionsLoaded([]))
  }

  // MARK: - .sectionsLoaded

  func testSectionsLoadedClearsPendingDeletionWhenRecordRemoved() async {
    let portfolioID = UUID()
    let pendingRecord = Self.makeSnapshot(id: UUID(), totalAmount: 50)
    var state = ContributionHistoryFeature.State(portfolioID: portfolioID)
    state.pendingDeletion = pendingRecord

    let store = TestStore(initialState: state) {
      ContributionHistoryFeature()
    }

    await store.send(.sectionsLoaded([])) {
      $0.sections = []
      $0.pendingDeletion = nil
    }
  }

  func testSectionsLoadedKeepsPendingDeletionWhenRecordStillPresent() async {
    let portfolioID = UUID()
    let pendingRecord = Self.makeSnapshot(id: UUID(), totalAmount: 75)
    var state = ContributionHistoryFeature.State(portfolioID: portfolioID)
    state.pendingDeletion = pendingRecord

    let stillPresentSection = ContributionHistoryMonthSection(
      monthStart: Date(timeIntervalSince1970: 1_700_000_000),
      title: "November 2023",
      records: [pendingRecord])

    let store = TestStore(initialState: state) {
      ContributionHistoryFeature()
    }

    await store.send(.sectionsLoaded([stillPresentSection])) {
      $0.sections = [stillPresentSection]
      // `pendingDeletion` is untouched because the matching record is in the
      // new payload.
    }
  }

  // MARK: - delete-confirmation latch

  func testDeleteTappedSetsPendingDeletion() async {
    let portfolioID = UUID()
    let record = Self.makeSnapshot(id: UUID(), totalAmount: 60)

    let store = TestStore(
      initialState: ContributionHistoryFeature.State(portfolioID: portfolioID)
    ) {
      ContributionHistoryFeature()
    }

    await store.send(.deleteTapped(record: record)) {
      $0.pendingDeletion = record
    }
  }

  func testCancelDeleteClearsPendingDeletion() async {
    let portfolioID = UUID()
    let record = Self.makeSnapshot(id: UUID(), totalAmount: 80)
    var state = ContributionHistoryFeature.State(portfolioID: portfolioID)
    state.pendingDeletion = record

    let store = TestStore(initialState: state) {
      ContributionHistoryFeature()
    }

    await store.send(.cancelDelete) {
      $0.pendingDeletion = nil
    }
  }

  // MARK: - .confirmDelete

  func testConfirmDeleteIsNoOpWhenNothingPending() async {
    let portfolioID = UUID()
    let store = TestStore(
      initialState: ContributionHistoryFeature.State(portfolioID: portfolioID)
    ) {
      ContributionHistoryFeature()
    }
    // No `withDependencies` block: the guard returns `.none` before the
    // model container is touched, so any call would crash the unimplemented
    // `@DependencyClient` stub.

    await store.send(.confirmDelete)
  }

  func testConfirmDeleteHappyPathDeletesRecordAndReloads() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = container.mainContext

    let portfolioID = UUID()
    let recordID = UUID()
    let portfolio = Portfolio(
      id: portfolioID, name: "Growth",
      monthlyBudget: Decimal(500), maWindow: 50,
      createdAt: Date(timeIntervalSince1970: 1_600_000_000))
    context.insert(portfolio)

    let record = ContributionRecord(
      id: recordID,
      portfolioId: portfolioID,
      date: Date(timeIntervalSince1970: 1_700_000_000),
      totalAmount: Decimal(125),
      portfolio: portfolio,
      categoryBreakdown: [
        CategoryContribution(categoryName: "Equity", amount: Decimal(125), allocatedWeight: 1)
      ],
      tickerAllocations: [])
    portfolio.contributionRecords = [record]
    try context.save()

    let pendingSnapshot = ContributionRecordSnapshot(
      id: recordID,
      date: record.date,
      totalAmount: record.totalAmount,
      categoryBreakdown: [
        CategoryContributionSnapshot(
          categoryName: "Equity", amount: Decimal(125), allocatedWeight: 1)
      ],
      tickerAllocations: [])

    var state = ContributionHistoryFeature.State(portfolioID: portfolioID)
    state.pendingDeletion = pendingSnapshot

    let store = TestStore(initialState: state) {
      ContributionHistoryFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
    }

    await store.send(.confirmDelete) {
      $0.pendingDeletion = nil
    }
    await store.receive(.sectionsLoaded([]))

    // Container side-effect verification: the row is gone.
    let remaining = try context.fetch(FetchDescriptor<ContributionRecord>())
    XCTAssertTrue(remaining.isEmpty)
  }

  func testConfirmDeleteFailurePathWritesDeleteError() async {
    struct StubError: LocalizedError, Equatable {
      var errorDescription: String? { "delete kaboom" }
    }

    let portfolioID = UUID()
    let pendingSnapshot = Self.makeSnapshot(id: UUID(), totalAmount: 90)
    var state = ContributionHistoryFeature.State(portfolioID: portfolioID)
    state.pendingDeletion = pendingSnapshot

    let store = TestStore(initialState: state) {
      ContributionHistoryFeature()
    } withDependencies: {
      $0.modelContainer.container = { throw StubError() }
    }

    await store.send(.confirmDelete) {
      $0.pendingDeletion = nil
    }
    await store.receive(.deleteFailed("delete kaboom")) {
      $0.deleteError = "delete kaboom"
    }
  }

  // MARK: - error-banner mutations

  func testDeleteFailedWritesDeleteError() async {
    let portfolioID = UUID()
    let store = TestStore(
      initialState: ContributionHistoryFeature.State(portfolioID: portfolioID)
    ) {
      ContributionHistoryFeature()
    }

    await store.send(.deleteFailed("explicit message")) {
      $0.deleteError = "explicit message"
    }
  }

  func testDeleteErrorDismissedClearsDeleteError() async {
    let portfolioID = UUID()
    var state = ContributionHistoryFeature.State(portfolioID: portfolioID)
    state.deleteError = "stale"

    let store = TestStore(initialState: state) {
      ContributionHistoryFeature()
    }

    await store.send(.deleteErrorDismissed) {
      $0.deleteError = nil
    }
  }

  // MARK: - .openCalculate delegate

  func testOpenCalculateEmitsDelegate() async {
    let portfolioID = UUID()
    let store = TestStore(
      initialState: ContributionHistoryFeature.State(portfolioID: portfolioID)
    ) {
      ContributionHistoryFeature()
    }

    await store.send(.openCalculate)
    await store.receive(.delegate(.openCalculate(portfolioID: portfolioID)))
  }

  func testDelegateActionIsTerminator() async {
    let portfolioID = UUID()
    let store = TestStore(
      initialState: ContributionHistoryFeature.State(portfolioID: portfolioID)
    ) {
      ContributionHistoryFeature()
    }

    await store.send(.delegate(.openCalculate(portfolioID: portfolioID)))
  }

  // MARK: - ContributionHistoryMonthSection.group(records:calendar:)

  func testGroupReturnsEmptyForEmptyInput() {
    let calendar = Self.utcGregorianCalendar()
    XCTAssertEqual(
      ContributionHistoryMonthSection.group(records: [], calendar: calendar),
      [])
  }

  func testGroupCollapsesSameMonthRecordsIntoOneSectionNewestFirst() {
    let calendar = Self.utcGregorianCalendar()
    let earlyDate = Self.date(year: 2023, month: 11, day: 5, calendar: calendar)
    let lateDate = Self.date(year: 2023, month: 11, day: 25, calendar: calendar)
    let earlyRecord = Self.makeSnapshot(id: UUID(), date: earlyDate, totalAmount: 50)
    let lateRecord = Self.makeSnapshot(id: UUID(), date: lateDate, totalAmount: 75)

    let sections = ContributionHistoryMonthSection.group(
      records: [earlyRecord, lateRecord], calendar: calendar)

    XCTAssertEqual(sections.count, 1)
    XCTAssertEqual(sections[0].records.map(\.id), [lateRecord.id, earlyRecord.id])
    XCTAssertEqual(sections[0].title, "November 2023")
    XCTAssertEqual(
      sections[0].monthStart,
      calendar.dateInterval(of: .month, for: lateDate)?.start)
    XCTAssertEqual(sections[0].totalAmount, Decimal(125))
  }

  func testGroupSplitsRecordsAcrossMonthsNewestMonthFirst() {
    let calendar = Self.utcGregorianCalendar()
    let novDate = Self.date(year: 2023, month: 11, day: 15, calendar: calendar)
    let decDate = Self.date(year: 2023, month: 12, day: 15, calendar: calendar)
    let novRecord = Self.makeSnapshot(id: UUID(), date: novDate, totalAmount: 100)
    let decRecord = Self.makeSnapshot(id: UUID(), date: decDate, totalAmount: 200)

    let sections = ContributionHistoryMonthSection.group(
      records: [novRecord, decRecord], calendar: calendar)

    XCTAssertEqual(sections.count, 2)
    XCTAssertEqual(sections.map(\.title), ["December 2023", "November 2023"])
    XCTAssertEqual(sections[0].records.map(\.id), [decRecord.id])
    XCTAssertEqual(sections[1].records.map(\.id), [novRecord.id])
  }

  // MARK: - Helpers

  private static func makeSnapshot(
    id: UUID,
    date: Date = Date(timeIntervalSince1970: 1_700_000_000),
    totalAmount: Decimal
  ) -> ContributionRecordSnapshot {
    ContributionRecordSnapshot(
      id: id,
      date: date,
      totalAmount: totalAmount,
      categoryBreakdown: [],
      tickerAllocations: [])
  }

  private static func utcGregorianCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }

  private static func date(
    year: Int, month: Int, day: Int, calendar: Calendar
  ) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return calendar.date(from: components)!
  }
}
