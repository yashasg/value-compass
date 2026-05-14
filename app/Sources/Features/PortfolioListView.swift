import ComposableArchitecture
import SwiftUI

/// Post-onboarding portfolio inventory. Renders on top of
/// `PortfolioListFeature` (and the sibling `PortfolioEditorFeature` for the
/// create/edit sheet). Replaces the MVVM definition that previously lived
/// in `MainView.swift`. Pure TCA: scope a `StoreOf<PortfolioListFeature>`
/// from the parent (`MainFeature.portfolios`) and pass it in.
struct PortfolioListView: View {
  let store: StoreOf<PortfolioListFeature>

  init(store: StoreOf<PortfolioListFeature>) {
    self.store = store
  }

  var body: some View {
    PortfolioListContent(store: store)
  }
}

/// TCA renderer for `PortfolioListFeature`. Used by the production app via
/// `MainFeature.path` (wired in #159) and by previews / tests.
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

/// Static row label rendered for every entry in the portfolio list. Reads
/// from `PortfolioSnapshot` so the row stays decoupled from SwiftData.
struct PortfolioRowView: View {
  let snapshot: PortfolioSnapshot

  init(snapshot: PortfolioSnapshot) {
    self.snapshot = snapshot
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
