import ComposableArchitecture
import SwiftUI

/// Adaptive root for post-onboarding usage. Compact widths render a
/// `NavigationStack` driven by `MainFeature.path`; regular widths render an
/// iPad-native `NavigationSplitView` whose sidebar / content / detail columns
/// are all scoped from the same `MainFeature` store.
///
/// Phase 2 (#159) replaces the legacy `@Query` + `@State` shell with a pure
/// store-driven shell. The only SwiftUI-side state retained here is
/// `@Environment(\.horizontalSizeClass)`, which is required to choose between
/// the two shells; the choice is mirrored into `MainFeature.State.shellKind`
/// via `.shellKindChanged(_:)` so the reducer routes child delegates to the
/// correct surface (push onto `path` for compact, set `detailPortfolio` for
/// regular).
struct MainView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Bindable var store: StoreOf<MainFeature>

  init(store: StoreOf<MainFeature>) {
    self.store = store
  }

  var body: some View {
    Group {
      switch MainFeature.shellKind(for: horizontalSizeClass) {
      case .stack:
        stackShell
      case .splitView:
        splitShell
      }
    }
    .onAppear {
      store.send(.shellKindChanged(MainFeature.shellKind(for: horizontalSizeClass)))
    }
    .onChange(of: horizontalSizeClass) { _, newValue in
      store.send(.shellKindChanged(MainFeature.shellKind(for: newValue)))
    }
  }

  // MARK: - Compact stack

  private var stackShell: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      PortfolioListView(store: store.scope(state: \.portfolios, action: \.portfolios))
    } destination: { pathStore in
      pathDestination(for: pathStore)
    }
  }

  // MARK: - iPad split view

  private var splitShell: some View {
    NavigationSplitView {
      sidebar
    } content: {
      content
    } detail: {
      NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
        detailRoot
      } destination: { pathStore in
        pathDestination(for: pathStore)
      }
    }
  }

  private var sidebar: some View {
    let sidebarSelection = Binding<MainFeature.Sidebar?>(
      get: { store.sidebar },
      set: { newValue in
        if let newValue {
          store.send(.sidebarSelected(newValue))
        }
      }
    )
    return List(selection: sidebarSelection) {
      AppBrandSidebarHeader()

      ForEach(MainFeature.Sidebar.allCases) { section in
        NavigationLink(value: section) {
          Label(label(for: section), systemImage: icon(for: section))
        }
      }
    }
    .navigationTitle(AppBrand.displayName)
    .navigationSplitViewColumnWidth(
      min: AppLayoutMetrics.sidebarMinWidth,
      ideal: AppLayoutMetrics.sidebarIdealWidth,
      max: AppLayoutMetrics.sidebarMaxWidth)
  }

  @ViewBuilder
  private var content: some View {
    switch store.sidebar {
    case .portfolios:
      PortfolioListView(store: store.scope(state: \.portfolios, action: \.portfolios))
        .navigationSplitViewColumnWidth(
          min: AppLayoutMetrics.sidebarMinWidth,
          ideal: AppLayoutMetrics.sidebarIdealWidth,
          max: AppLayoutMetrics.sidebarMaxWidth)
    case .settings:
      SettingsView(store: store.scope(state: \.settings, action: \.settings))
    }
  }

  @ViewBuilder
  private var detailRoot: some View {
    if let detailStore = store.scope(state: \.detailPortfolio, action: \.detailPortfolio) {
      PortfolioDetailView(store: detailStore)
    } else {
      switch store.detail {
      case .settings:
        SettingsView(store: store.scope(state: \.settings, action: \.settings))
      case .portfolio, .emptyPortfolioSelection:
        emptyPortfolioSelectionView
      }
    }
  }

  // MARK: - Shared destination switch

  @ViewBuilder
  private func pathDestination(
    for pathStore: StoreOf<MainFeature.Path>
  ) -> some View {
    switch pathStore.case {
    case .portfolioDetail(let scoped):
      PortfolioDetailView(store: scoped)
    case .holdingsEditor(let scoped):
      HoldingsEditorView(store: scoped)
    case .contributionResult(let scoped):
      ContributionResultView(store: scoped)
    case .contributionHistory(let scoped):
      ContributionHistoryView(store: scoped)
    case .settings(let scoped):
      SettingsView(store: scoped)
    }
  }

  // MARK: - Helpers

  private var emptyPortfolioSelectionView: some View {
    ContentUnavailableView {
      Label("Create Your First Portfolio", systemImage: "folder.badge.plus")
    } description: {
      Text("Use the portfolio list to create a local portfolio, then add categories and tickers.")
    }
    .navigationTitle("Portfolio")
  }

  private func icon(for section: MainFeature.Sidebar) -> String {
    switch section {
    case .portfolios: return "chart.line.uptrend.xyaxis"
    case .settings: return "gear"
    }
  }

  private func label(for section: MainFeature.Sidebar) -> String {
    switch section {
    case .portfolios: return "Portfolios"
    case .settings: return "Settings"
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
    PortfolioListView(
      store: Store(initialState: PortfolioListFeature.State()) {
        PortfolioListFeature()
      })
  }
}
