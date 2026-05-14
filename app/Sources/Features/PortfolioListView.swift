import ComposableArchitecture
import SwiftData
import SwiftUI

/// Post-onboarding portfolio inventory. Renders on top of
/// `PortfolioListFeature` (and the sibling `PortfolioEditorFeature` for the
/// create/edit sheet). Replaces the MVVM definition that previously lived
/// in `MainView.swift`.
///
/// Two entry points exist during the Phase 1 → Phase 2 migration:
///
/// 1. `init(store:)` — the production TCA path used by Phase 2 (#159).
/// 2. `init(selectedPortfolioID:showsSettingsLink:)` — a legacy bridge that
///    `MainView` still uses today. The bridge owns a short-lived `Store`
///    and mirrors `selected(id:)` and `delegate(.portfolioOpened(id))` back
///    into the existing `MainView` selection binding (iPad split view) or
///    pushes `PortfolioDetailView` via `navigationDestination(item:)`
///    (compact stack), so the surrounding `NavigationStack` /
///    `NavigationSplitView` keeps behaving exactly as it does today.
///
/// The bridge is removed in #158 once the real `Store` is wired at app
/// entry, and #159 wires `MainFeature.path` to handle navigation directly.
struct PortfolioListView: View {
  private let mode: Mode

  init(store: StoreOf<PortfolioListFeature>) {
    self.mode = .store(store)
  }

  init(selectedPortfolioID: Binding<UUID?>? = nil, showsSettingsLink: Bool = true) {
    self.mode = .legacy(
      selectedPortfolioID: selectedPortfolioID,
      showsSettingsLink: showsSettingsLink
    )
  }

  var body: some View {
    switch mode {
    case .store(let store):
      PortfolioListContent(store: store)
    case .legacy(let selection, let showsSettings):
      PortfolioListLegacyBridge(
        selectedPortfolioID: selection,
        showsSettingsLink: showsSettings
      )
    }
  }

  private enum Mode {
    case store(StoreOf<PortfolioListFeature>)
    case legacy(selectedPortfolioID: Binding<UUID?>?, showsSettingsLink: Bool)
  }
}

/// Pure TCA renderer for `PortfolioListFeature`. Used by the production
/// app once Phase 2 (#159) wires `MainFeature.path`. Until then it is
/// reachable only through the legacy bridge / previews / tests.
private struct PortfolioListContent: View {
  @Bindable var store: StoreOf<PortfolioListFeature>

  var body: some View {
    Group {
      if store.portfolios.isEmpty {
        ContentUnavailableView {
          Label("No Portfolios Yet", systemImage: "folder.badge.plus")
        } description: {
          Text(
            "Create a local portfolio to start planning offline with your own budget and holdings."
          )
        } actions: {
          Button("Create Your First Portfolio") {
            store.send(.createTapped)
          }
          .buttonStyle(.borderedProminent)
          .appMinimumTouchTarget()
          .accessibilityIdentifier("portfolio.empty.create")
        }
      } else {
        List {
          ForEach(store.portfolios) { portfolio in
            row(for: portfolio)
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Delete", role: .destructive) {
                  store.send(.deleteTapped(id: portfolio.id))
                }
                Button("Edit") {
                  store.send(.editTapped(id: portfolio.id))
                }
                .tint(.blue)
              }
          }
          .onDelete { offsets in
            for index in offsets {
              store.send(.deleteTapped(id: store.portfolios[index].id))
            }
          }
        }
        .accessibilityIdentifier("portfolio.list")
      }
    }
    .navigationTitle("Portfolios")
    .toolbar { toolbarContent }
    .sheet(item: $store.scope(state: \.editor, action: \.editor)) { editorStore in
      PortfolioEditorView(store: editorStore)
    }
    .alert(
      "Could Not Save Portfolio",
      isPresented: Binding(
        get: { store.saveError != nil },
        set: { newValue in
          if !newValue { store.send(.saveErrorDismissed) }
        }
      ),
      presenting: store.saveError
    ) { _ in
      Button("OK", role: .cancel) {}
    } message: { message in
      Text(message)
    }
    .task { store.send(.task) }
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      Button {
        store.send(.createTapped)
      } label: {
        Label("Create Portfolio", systemImage: "plus")
      }
      .accessibilityIdentifier("portfolio.create")
    }

    if store.showsSettingsLink {
      ToolbarItem(placement: .secondaryAction) {
        NavigationLink {
          SettingsView()
        } label: {
          Label("Settings", systemImage: "gear")
        }
        .accessibilityIdentifier("portfolio.settings")
      }
    }
  }

  @ViewBuilder
  private func row(for portfolio: PortfolioSnapshot) -> some View {
    Button {
      store.send(.selected(id: portfolio.id))
    } label: {
      HStack {
        PortfolioRowView(snapshot: portfolio)
        Spacer()
        if store.selectedPortfolioID == portfolio.id {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.appPrimary)
            .accessibilityHidden(true)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("portfolio.list.selection")
    .accessibilityAddTraits(store.selectedPortfolioID == portfolio.id ? .isSelected : [])
  }
}

/// Phase 1 bridge between the legacy `MainView` (which still passes a
/// `selectedPortfolioID` binding for the iPad split view and renders the
/// list inside its own `NavigationStack` for compact widths) and the new
/// `PortfolioListFeature`. Owns a short-lived `Store` and translates the
/// reducer's selection / delegate output back into the surrounding
/// SwiftUI navigation.
///
/// Removed in #159 once `MainFeature.path` owns navigation directly.
private struct PortfolioListLegacyBridge: View {
  let selectedPortfolioID: Binding<UUID?>?
  let showsSettingsLink: Bool

  @Environment(\.modelContext) private var modelContext
  @StateObject private var holder = PortfolioListLegacyStoreHolder()
  @State private var pushedPortfolio: Portfolio?

  var body: some View {
    let store = holder.store(showsSettingsLink: showsSettingsLink)
    PortfolioListContent(store: store)
      .navigationDestination(
        isPresented: Binding(
          get: { pushedPortfolio != nil },
          set: { newValue in
            if !newValue { pushedPortfolio = nil }
          }
        )
      ) {
        if let pushedPortfolio {
          PortfolioDetailView(portfolio: pushedPortfolio)
        }
      }
      .onChange(of: store.selectedPortfolioID) { _, newID in
        handleSelection(newID, store: store)
      }
  }

  private func handleSelection(_ newID: UUID?, store: StoreOf<PortfolioListFeature>) {
    if let binding = selectedPortfolioID {
      binding.wrappedValue = newID
      return
    }

    guard let newID else {
      pushedPortfolio = nil
      return
    }

    let descriptor = FetchDescriptor<Portfolio>(
      predicate: #Predicate { $0.id == newID }
    )
    if let portfolio = try? modelContext.fetch(descriptor).first {
      pushedPortfolio = portfolio
    }
    store.send(.selected(id: nil))
  }
}

/// Holds the short-lived `Store` used by `PortfolioListLegacyBridge` so the
/// store survives view re-creations triggered by SwiftUI re-renders.
@MainActor
private final class PortfolioListLegacyStoreHolder: ObservableObject {
  private var cachedStore: StoreOf<PortfolioListFeature>?

  func store(showsSettingsLink: Bool) -> StoreOf<PortfolioListFeature> {
    if let cachedStore {
      return cachedStore
    }
    let initial = PortfolioListFeature.State(showsSettingsLink: showsSettingsLink)
    let store = Store(initialState: initial) {
      PortfolioListFeature()
    }
    cachedStore = store
    return store
  }
}

/// Static row label rendered for every entry in the portfolio list. Reads
/// from `PortfolioSnapshot` so the row stays decoupled from SwiftData.
struct PortfolioRowView: View {
  let snapshot: PortfolioSnapshot

  init(snapshot: PortfolioSnapshot) {
    self.snapshot = snapshot
  }

  init(portfolio: Portfolio) {
    self.snapshot = PortfolioSnapshot(
      id: portfolio.id,
      name: portfolio.name,
      monthlyBudget: portfolio.monthlyBudget,
      maWindow: portfolio.maWindow,
      createdAt: portfolio.createdAt,
      categoryCount: portfolio.categories.count
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(snapshot.name)
        .valueCompassTextStyle(.headlineMedium)

      HStack {
        Label(
          "$\(PortfolioFormDraft.displayText(for: snapshot.monthlyBudget))/mo",
          systemImage: "dollarsign.circle")
        Label("\(snapshot.maWindow)-day MA", systemImage: "chart.line.uptrend.xyaxis")
      }
      .valueCompassTextStyle(.labelCaps)
      .foregroundStyle(Color.appContentSecondary)
    }
    .accessibilityElement(children: .combine)
  }
}

/// Adaptive shared alert payloads used by `PortfolioListView`,
/// `PortfolioDetailView`, `ContributionResultView`, `ContributionHistoryListView`,
/// and `HoldingsEditorView`. Moved out of `MainView.swift` as part of the
/// `PortfolioListView` TCA migration (issue #153) so that file shrinks
/// alongside the view definitions it used to host. The remaining MVVM views
/// keep using these helpers verbatim until their own Phase 1 issues land.
struct SaveError: Identifiable {
  let id = UUID()
  let message: String
}

struct SaveConfirmation: Identifiable {
  let id = UUID()
  let message: String
}

#Preview("Empty") {
  NavigationStack {
    PortfolioListView(
      store: Store(initialState: PortfolioListFeature.State()) {
        PortfolioListFeature()
      }
    )
  }
}

#Preview("Populated") {
  NavigationStack {
    PortfolioListView(
      store: Store(
        initialState: PortfolioListFeature.State(
          portfolios: [
            PortfolioSnapshot(
              id: UUID(),
              name: "Core",
              monthlyBudget: 1_000,
              maWindow: 50,
              createdAt: .now,
              categoryCount: 3
            ),
            PortfolioSnapshot(
              id: UUID(),
              name: "Income",
              monthlyBudget: 500,
              maWindow: 200,
              createdAt: .now,
              categoryCount: 2
            ),
          ]
        )
      ) {
        PortfolioListFeature()
      }
    )
  }
}
