import ComposableArchitecture
import SwiftUI

/// Adaptive root for post-onboarding usage. Compact widths render a
/// `NavigationStack` driven by `MainFeature.path`; regular widths render an
/// iPad-native `NavigationSplitView` whose sidebar / content / detail columns
/// are all scoped from the same `MainFeature` store.
///
/// Phase 2 (#159) replaces the legacy SwiftData-fetch + `@State` shell with a pure
/// store-driven shell. The only SwiftUI-side state retained here is
/// `@Environment(\.horizontalSizeClass)`, which is required to choose between
/// the two shells; the choice is mirrored into `MainFeature.State.shellKind`
/// via `.shellKindChanged(_:)` so the reducer routes child delegates to the
/// correct surface (push onto `path` for compact, set `detailPortfolio` for
/// regular).
///
/// Accessibility (#343): the iPad split-view sidebar→content / content→detail
/// column transitions are otherwise silent for VoiceOver, Switch Control, and
/// Full Keyboard Access — SwiftUI does not auto-move AT focus when a sibling
/// column repopulates. We satisfy WCAG 2.2 SC 4.1.3 (Status Messages), SC
/// 3.2.2 (On Input), and SC 2.4.3 (Focus Order) by (1) routing one-shot
/// announcements through the central `AccessibilityAnnouncer` seam, and (2)
/// using `@AccessibilityFocusState` plus invisible header anchors at the top
/// of each column to move AT focus onto the column that just populated. The
/// composer is `MainAccessibility`; the compact `.stack` shell is unaffected
/// because `NavigationStack` push already moves AT focus natively.
struct MainView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Bindable var store: StoreOf<MainFeature>

  /// VoiceOver / Switch-Control / Full-Keyboard-Access focus anchor for
  /// the iPad split-view column transitions (#343). Bound to one
  /// invisible header anchor per column destination so cross-column
  /// content swaps move AT focus into the newly populated column. Only
  /// driven when `store.shellKind == .splitView`; the compact stack
  /// path inherits free focus motion from `NavigationStack`'s push.
  @AccessibilityFocusState private var splitFocus: MainAccessibility.SplitFocusTarget?

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
    // #343: move AT focus into the destination column on each
    // user-initiated transition. The two onChange handlers are
    // orthogonal so the v1 column-handoff matrix is covered:
    //
    //   * sidebar tap (Portfolios / Settings) → focus lands on the
    //     content column's header anchor. For the Portfolios tab,
    //     this is the portfolio-list anchor; for Settings, the
    //     settings anchor in the content column (the duplicated
    //     detail-column copy is left silent — see #320 + the AC of
    //     #343 — so logical reading order matches sighted users).
    //
    //   * portfolio row tap in the content column →
    //     `state.portfolios.selectedPortfolioID` changes from `nil`
    //     (or the prior id) to the tapped id, and focus lands on
    //     the detail column's portfolio anchor. Re-selecting the
    //     same row is a no-op (the binding doesn't change), which
    //     matches `MainFeature.selectPortfolioDetail`'s reducer-side
    //     identity guard (AC item #4 of #343).
    //
    // We deliberately do NOT key focus motion off
    // `state.detailPortfolio?.portfolioID` because the same
    // detail-column repopulation also happens on sidebar→Portfolios
    // with a prior selection, where focus should stay in the
    // content column (AC item #3 of #343). The sidebar onChange
    // covers that path on its own.
    .onChange(of: store.sidebar) { _, newSidebar in
      guard store.shellKind == .splitView else { return }
      splitFocus = MainAccessibility.focusTarget(forSidebar: newSidebar)
    }
    .onChange(of: store.portfolios.selectedPortfolioID) { _, newID in
      guard store.shellKind == .splitView, newID != nil else { return }
      splitFocus = MainAccessibility.focusTargetForPortfolioOpen
    }
    // Mirror the focus motion as an `accessibilityAnnouncement` so
    // VoiceOver users who have focus-moves disabled (rare, but
    // documented) still perceive the transition; the focus motion
    // above remains the primary signal. The portfolio-open path
    // returns `nil` because the detail column's portfolio-name
    // header is read out when AT focus lands on it and a leading
    // announcement would double-read the title.
    .appAnnounceOnChange(of: store.sidebar) { newSidebar in
      guard store.shellKind == .splitView else { return nil }
      return MainAccessibility.transitionAnnouncement(forSidebar: newSidebar)
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
          max: AppLayoutMetrics.sidebarMaxWidth
        )
        .overlay(alignment: .topLeading) {
          splitFocusAnchor(target: .contentPortfolioList, label: "Portfolios")
        }
    case .settings:
      SettingsView(store: store.scope(state: \.settings, action: \.settings))
        .overlay(alignment: .topLeading) {
          splitFocusAnchor(target: .contentSettings, label: "Settings")
        }
    }
  }

  @ViewBuilder
  private var detailRoot: some View {
    if let detailStore = store.scope(state: \.detailPortfolio, action: \.detailPortfolio) {
      PortfolioDetailView(store: detailStore)
        .overlay(alignment: .topLeading) {
          splitFocusAnchor(
            target: .detailPortfolio,
            label: store.detailPortfolio?.snapshot.name ?? "Portfolio")
        }
    } else {
      switch store.detail {
      case .settings:
        SettingsView(store: store.scope(state: \.settings, action: \.settings))
          .overlay(alignment: .topLeading) {
            splitFocusAnchor(target: .detailSettings, label: "Settings")
          }
      case .portfolio, .emptyPortfolioSelection:
        emptyPortfolioSelectionView
          .overlay(alignment: .topLeading) {
            splitFocusAnchor(target: .detailEmpty, label: "No portfolio selected")
          }
      }
    }
  }

  /// Invisible AT focus anchor for an iPad split-view column (#343).
  /// Rendered as a zero-size, hit-test-disabled SwiftUI element whose
  /// `accessibilityLabel` reads as the destination column's heading
  /// when AT focus lands on it. We use an anchor rather than
  /// `.accessibilityFocused` on each column's existing visible heading
  /// so the focus-binding remains owned by `MainView` (the column
  /// root) without having to thread it through `PortfolioListView` /
  /// `SettingsView` / `PortfolioDetailView`. The `.isHeader` trait
  /// makes the anchor a natural reading-order top for VoiceOver. The
  /// anchor is also visually invisible (`Color.clear`) so it does not
  /// shift sighted layout — only AT users perceive it.
  @ViewBuilder
  private func splitFocusAnchor(
    target: MainAccessibility.SplitFocusTarget,
    label: String
  ) -> some View {
    Color.clear
      .frame(width: 1, height: 1)
      .accessibilityElement()
      .accessibilityLabel(label)
      .accessibilityAddTraits(.isHeader)
      .accessibilityFocused($splitFocus, equals: target)
      .allowsHitTesting(false)
  }

  // MARK: - Shared destination switch

  @ViewBuilder
  private func pathDestination(
    for pathStore: StoreOf<MainFeature.Path>
  ) -> some View {
    switch pathStore.case {
    case .portfolioDetail(let scoped):
      PortfolioDetailView(store: scoped)
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
