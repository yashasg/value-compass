import SwiftData
import SwiftUI

/// Adaptive root for post-onboarding usage. Compact widths use a
/// `NavigationStack`; regular widths use an iPad-native `NavigationSplitView`.
struct MainView: View {
  enum NavigationShellKind {
    case stack
    case splitView
  }

  enum SidebarSelection: String, Hashable, CaseIterable, Identifiable {
    case portfolios = "Portfolios"
    case settings = "Settings"
    var id: String { rawValue }
  }

  enum DetailSelection: Equatable {
    case portfolio(UUID)
    case settings
    case emptyPortfolioSelection
  }

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Query(sort: \Portfolio.createdAt, order: .reverse) private var portfolios: [Portfolio]
  @State private var sidebarSelection: SidebarSelection? = .portfolios
  @State private var selectedPortfolioID: UUID?

  var body: some View {
    switch Self.navigationShellKind(for: horizontalSizeClass) {
    case .stack:
      NavigationStack {
        PortfolioListView(showsSettingsLink: true)
      }
    case .splitView:
      splitView
    }
  }

  static func navigationShellKind(for horizontalSizeClass: UserInterfaceSizeClass?)
    -> NavigationShellKind
  {
    horizontalSizeClass == .compact ? .stack : .splitView
  }

  private var splitView: some View {
    NavigationSplitView {
      List(selection: $sidebarSelection) {
        AppBrandSidebarHeader()

        ForEach(SidebarSelection.allCases) { section in
          NavigationLink(value: section) {
            Label(section.rawValue, systemImage: icon(for: section))
          }
        }
      }
      .navigationTitle(AppBrand.displayName)
      .navigationSplitViewColumnWidth(
        min: AppLayoutMetrics.sidebarMinWidth,
        ideal: AppLayoutMetrics.sidebarIdealWidth,
        max: AppLayoutMetrics.sidebarMaxWidth)
    } content: {
      switch sidebarSelection ?? .portfolios {
      case .portfolios:
        PortfolioListView(selectedPortfolioID: $selectedPortfolioID, showsSettingsLink: false)
          .navigationSplitViewColumnWidth(
            min: AppLayoutMetrics.sidebarMinWidth,
            ideal: AppLayoutMetrics.sidebarIdealWidth,
            max: AppLayoutMetrics.sidebarMaxWidth)
      case .settings:
        SettingsView()
      }
    } detail: {
      detailView(
        for: Self.detailSelection(
          sidebarSelection: sidebarSelection,
          selectedPortfolioID: selectedPortfolioID,
          firstPortfolioID: portfolios.first?.id))
    }
  }

  @ViewBuilder
  private func detailView(for detailSelection: DetailSelection) -> some View {
    switch detailSelection {
    case .portfolio(let id):
      if let portfolio = portfolios.first(where: { $0.id == id }) {
        PortfolioDetailView(portfolio: portfolio)
      } else {
        emptyPortfolioSelectionView
      }
    case .settings:
      SettingsView()
    case .emptyPortfolioSelection:
      emptyPortfolioSelectionView
    }
  }

  private var emptyPortfolioSelectionView: some View {
    ContentUnavailableView {
      Label("Create Your First Portfolio", systemImage: "folder.badge.plus")
    } description: {
      Text("Use the portfolio list to create a local portfolio, then add categories and tickers.")
    }
    .navigationTitle("Portfolio")
  }

  static func detailSelection(
    sidebarSelection: SidebarSelection?,
    selectedPortfolioID: UUID?,
    firstPortfolioID: UUID?
  ) -> DetailSelection {
    if sidebarSelection == .settings {
      return .settings
    }

    if let selectedPortfolioID {
      return .portfolio(selectedPortfolioID)
    }

    if let firstPortfolioID {
      return .portfolio(firstPortfolioID)
    }

    return .emptyPortfolioSelection
  }

  private func icon(for section: SidebarSelection) -> String {
    switch section {
    case .portfolios: return "chart.line.uptrend.xyaxis"
    case .settings: return "gear"
    }
  }
}

private struct AppBrandSidebarHeader: View {
  var body: some View {
    AppBrandHeader(logoSize: 44, subtitle: nil)
      .padding(.vertical, 8)
      .listRowSeparator(.hidden)
      .accessibilityIdentifier("app.brand.header")
  }
}

/// Placeholder dashboard. Real content lands once the OpenAPI-generated
/// client is wired up to the backend's quote/portfolio endpoints.
struct DashboardView: View {
  var body: some View {
    PortfolioListView()
  }
}

struct ContributionHistoryListView: View {
  let portfolio: Portfolio

  @Environment(\.modelContext) private var modelContext
  @State private var recordPendingDeletion: ContributionRecord?
  @State private var deleteError: SaveError?

  var body: some View {
    List {
      if monthSections.isEmpty {
        ContentUnavailableView {
          Label("No Saved Results", systemImage: "clock")
        } description: {
          Text("Run Calculate and save the result to build local contribution history.")
        } actions: {
          NavigationLink {
            PortfolioDetailView(portfolio: portfolio)
          } label: {
            Label("Calculate", systemImage: "function")
          }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("contribution.history.calculate")
        }
      } else {
        ForEach(monthSections) { section in
          Section {
            ForEach(section.records) { record in
              NavigationLink {
                ContributionHistoryDetailView(record: record)
              } label: {
                ContributionHistoryRowView(record: record)
              }
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Delete", role: .destructive) {
                  recordPendingDeletion = record
                }
              }
              .accessibilityIdentifier("contribution.history.record")
            }
            .onDelete { offsets in
              if let firstOffset = offsets.first {
                recordPendingDeletion = section.records[firstOffset]
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
    .alert(item: $recordPendingDeletion) { record in
      Alert(
        title: Text("Delete Saved Result?"),
        message: Text("This removes the saved result from \(dateText(record.date))."),
        primaryButton: .destructive(Text("Delete")) {
          delete(record)
        },
        secondaryButton: .cancel()
      )
    }
    .alert(item: $deleteError) { error in
      Alert(
        title: Text("Could Not Delete Result"),
        message: Text(error.message),
        dismissButton: .default(Text("OK"))
      )
    }
    .accessibilityIdentifier("contribution.history")
  }

  private var records: [ContributionRecord] {
    portfolio.contributionRecords
      .filter { $0.portfolioId == portfolio.id }
      .sorted { $0.date > $1.date }
  }

  private var monthSections: [ContributionHistoryMonthSection] {
    ContributionHistoryMonthSection.group(records: records)
  }

  private func delete(_ record: ContributionRecord) {
    modelContext.delete(record)
    do {
      try modelContext.save()
    } catch {
      deleteError = SaveError(message: error.localizedDescription)
    }
  }

  private func decimalText(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }

  private func dateText(_ date: Date) -> String {
    ContributionHistoryDateFormatters.day.string(from: date)
  }
}

struct ContributionHistoryRowView: View {
  let record: ContributionRecord

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

struct ContributionHistoryDetailView: View {
  let record: ContributionRecord

  var body: some View {
    List {
      Section("Summary") {
        LabeledContent(
          "Date", value: ContributionHistoryDateFormatters.day.string(from: record.date))
        LabeledContent("Total", value: "$\(decimalText(record.totalAmount))")
      }

      Section("Category Totals") {
        ForEach(categoryBreakdown, id: \.categoryName) { category in
          LabeledContent(category.categoryName, value: "$\(decimalText(category.amount))")
            .accessibilityIdentifier("contribution.history.detail.category")
        }
      }

      Section("Ticker Breakdown") {
        ForEach(tickerAllocations, id: \.id) { allocation in
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

  private var categoryBreakdown: [CategoryContribution] {
    record.categoryBreakdown.sorted { lhs, rhs in
      if lhs.categoryName == rhs.categoryName {
        return lhs.amount > rhs.amount
      }
      return lhs.categoryName < rhs.categoryName
    }
  }

  private var tickerAllocations: [TickerAllocation] {
    record.tickerAllocations.sorted { lhs, rhs in
      if lhs.categoryName == rhs.categoryName {
        return lhs.tickerSymbol < rhs.tickerSymbol
      }
      return lhs.categoryName < rhs.categoryName
    }
  }

  private func decimalText(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }
}

struct ContributionHistoryMonthSection: Identifiable {
  let monthStart: Date
  let title: String
  let records: [ContributionRecord]

  var id: Date { monthStart }

  var totalAmount: Decimal {
    records.reduce(Decimal(0)) { $0 + $1.totalAmount }
  }

  static func group(
    records: [ContributionRecord],
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
