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
