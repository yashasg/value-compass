import ComposableArchitecture
import SwiftUI

/// Sheet presented from `PortfolioListView` for the create/edit portfolio
/// flow. Routes form bindings, validation, and persistence through
/// `PortfolioEditorFeature`.
struct PortfolioEditorView: View {
  @Bindable var store: StoreOf<PortfolioEditorFeature>
  /// Tracks whether the monthly-budget `.decimalPad` field is the
  /// first responder so the keyboard toolbar's Done button can resign it.
  /// `.decimalPad` has no Return key, so HIG Inputs → Virtual Keyboards
  /// requires an input-accessory affordance to dismiss it (issue #283).
  @FocusState private var isBudgetFocused: Bool

  init(store: StoreOf<PortfolioEditorFeature>) {
    self.store = store
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Portfolio") {
          TextField("Name", text: $store.draft.name)
            .textInputAutocapitalization(.words)
            .accessibilityIdentifier("portfolio.editor.name")

          TextField("Monthly budget", text: $store.draft.monthlyBudgetText)
            .keyboardType(.decimalPad)
            .focused($isBudgetFocused)
            .accessibilityIdentifier("portfolio.editor.budget")
        }

        Section("Moving Average") {
          Picker("Window", selection: $store.draft.maWindow) {
            ForEach(Portfolio.allowedMAWindows, id: \.self) { window in
              Text("\(window) days").tag(window)
            }
          }
          .pickerStyle(.segmented)
          .accessibilityIdentifier("portfolio.editor.maWindow")
        }

        if let validationError = store.validationError {
          Text(validationError.localizedDescription)
            .foregroundStyle(Color.appError)
            .accessibilityIdentifier("portfolio.editor.validationError")
        }
      }
      .navigationTitle(store.navigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            store.send(.cancelTapped)
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            store.send(.saveTapped)
          }
          .accessibilityIdentifier("portfolio.editor.save")
        }

        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { isBudgetFocused = false }
            .accessibilityIdentifier("portfolio.editor.budget.doneButton")
        }
      }
      .alert(
        "Could Not Save Portfolio",
        isPresented: Binding(
          get: { store.saveError != nil },
          set: { newValue in
            if !newValue { store.send(.binding(.set(\.saveError, nil))) }
          }
        ),
        presenting: store.saveError
      ) { _ in
        Button("OK", role: .cancel) {}
      } message: { message in
        Text(message)
      }
      .confirmationDialog(
        "Discard Changes?",
        isPresented: Binding(
          get: { store.pendingCancellation },
          set: { newValue in
            // The dialog drives `isPresented = false` on outside-tap or back
            // gesture. Route that through `.keepEditing` so the reducer stays
            // the single source of truth for `pendingCancellation` (#325).
            if !newValue { store.send(.keepEditing) }
          }
        ),
        titleVisibility: .visible
      ) {
        Button("Discard Changes", role: .destructive) {
          store.send(.confirmDiscard)
        }
        .accessibilityIdentifier("portfolio.editor.discardConfirm")
        Button("Keep Editing", role: .cancel) {
          store.send(.keepEditing)
        }
        .accessibilityIdentifier("portfolio.editor.keepEditing")
      } message: {
        Text("Your unsaved edits will be lost.")
      }
      // HIG Sheets: block accidental swipe-down dismissal when there is
      // unsaved content. The explicit Cancel button (above) remains the
      // intentional dismiss path and runs through the same confirmation
      // dialog when dirty (#325).
      .interactiveDismissDisabled(store.hasUnsavedChanges)
      // WCAG 2.2 SC 2.1.1 — Provide a keyboard- and AT-reachable dismiss
      // path. `interactiveDismissDisabled` above absorbs the VoiceOver
      // two-finger Z-scrub (also the Full Keyboard Access Escape key and
      // the Switch Control "Escape" menu item) whenever the draft is
      // dirty, stranding AT users on the sheet with no auditory cue.
      // Routing through `.cancelTapped` keeps the dirty-vs-clean branch
      // from #325: clean drafts fall through to `.delegate(.canceled)` +
      // `await dismiss()` (reducer-driven); dirty drafts flip
      // `pendingCancellation = true` and the discard `.confirmationDialog`
      // (above) takes over (#421).
      .accessibilityAction(.escape) {
        store.send(.cancelTapped)
      }
      // WCAG 2.2 SC 4.1.3 — Status Messages. The inline `Text` above is
      // inserted silently when `validationError` transitions to non-nil,
      // so VoiceOver users tapping Save have no auditory cue that the
      // attempt was rejected. Routing the message through the centralized
      // announcer posts an AT announcement without yanking focus off
      // Save (#293).
      .appAnnounceOnChange(of: store.validationError) { error in
        error?.localizedDescription
      }
    }
    .task { store.send(.task) }
  }
}

#Preview("Create") {
  PortfolioEditorView(
    store: Store(initialState: PortfolioEditorFeature.State(mode: .create)) {
      PortfolioEditorFeature()
    }
  )
}

#Preview("Edit") {
  PortfolioEditorView(
    store: Store(
      initialState: PortfolioEditorFeature.State(
        mode: .edit(UUID()),
        draft: PortfolioFormDraft(name: "Core", monthlyBudget: 1_000, maWindow: 50)
      )
    ) {
      PortfolioEditorFeature()
    }
  )
}
