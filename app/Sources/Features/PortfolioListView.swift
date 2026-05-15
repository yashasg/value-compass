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
              // Mirror both `.swipeActions` buttons as semantic
              // `.accessibilityAction(named:)`s so Edit and the
              // destructive Delete reach Voice Control ("Tap Edit" /
              // "Tap Delete"), Switch Control (action menu), and Full
              // Keyboard Access (action shortcut) — none of which can
              // synthesize the trailing-swipe gesture. VoiceOver users
              // also gain consistent labeled entries in the Actions
              // rotor. Edit is otherwise unreachable to those AT paths
              // because the codebase has no `EditButton`/`EditMode` and
              // no toolbar-level entry point for per-row edit (#272
              // intentionally removed the `.onDelete` stub plumbing).
              // WCAG 2.5.1 (Pointer Gestures): any single-point
              // gesture-only path must have an equivalent non-gesture
              // alternative (#285).
              .accessibilityAction(named: Text("Edit")) {
                store.send(.editTapped(id: portfolio.id))
              }
              .accessibilityAction(named: Text("Delete")) {
                store.send(.deleteTapped(id: portfolio.id))
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
        .accessibilityIdentifier("portfolio.delete.confirm")
      Button("Cancel", role: .cancel) { store.send(.cancelDelete) }
        .accessibilityIdentifier("portfolio.delete.cancel")
    } message: { _ in
      Text(
        "This permanently removes the portfolio's categories, tickers, and saved contribution history. This can't be undone."
      )
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

  /// Builds the confirmation-dialog title from the staged portfolio so the
  /// destructive action is unambiguous about *which* portfolio is being
  /// deleted (HIG → *Patterns → Confirming an action*: "Make sure the
  /// destructive choice is clearly identified"). Falls back to a generic
  /// title only as a safety net for the brief window when SwiftUI evaluates
  /// the title while `pendingDeletion` is being cleared.
  private static func deletionDialogTitle(for snapshot: PortfolioSnapshot?) -> String {
    guard let snapshot else { return "Delete Portfolio?" }
    return "Delete \"\(snapshot.name)\"?"
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
        Button {
          store.send(.settingsOpenTapped)
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
