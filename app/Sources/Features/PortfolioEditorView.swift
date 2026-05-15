import ComposableArchitecture
import SwiftUI
import UIKit

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
      // WCAG 2.2 SC 4.1.3 (Status Messages) / #293: when Save validation
      // fails, the reducer inserts an inline `Text` below the Form. SwiftUI
      // does not post an AT notification when an `if let` adds a view to
      // the hierarchy, so VoiceOver focus stays on the Save toolbar button
      // and the error is silent — to the AT user, Save just does nothing.
      // Post the validation message imperatively so the outcome reaches
      // VoiceOver without forcing a focus change. Sighted interaction is
      // unchanged. Reducer behavior pins the trigger: `.binding` clears
      // `validationError` to nil, `.validationFailed(_)` sets it again
      // — so every failed Save tap traverses nil → value here and fires
      // even when the same case repeats.
      .onChange(of: store.validationError) { _, newValue in
        guard let newValue else { return }
        let message = PortfolioEditorAccessibility.announcement(for: newValue)
        UIAccessibility.post(notification: .announcement, argument: message)
      }
    }
    .task { store.send(.task) }
  }
}

/// Composes the VoiceOver announcement posted by `PortfolioEditorView` when
/// `PortfolioEditorFeature.State.validationError` transitions from nil to a
/// value (`#293`). Mirrors the on-screen inline error text so screen-reader
/// users hear what sighted users see. Exposed at file scope (not nested
/// inside the view) so unit tests can pin every branch without spinning up
/// a SwiftUI host.
enum PortfolioEditorAccessibility {
  static func announcement(for error: PortfolioEditorValidationError) -> String {
    error.localizedDescription
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
