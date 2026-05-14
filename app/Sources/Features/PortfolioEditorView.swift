import ComposableArchitecture
import SwiftUI

/// Sheet presented from `PortfolioListView` for the create/edit portfolio
/// flow. Routes form bindings, validation, and persistence through
/// `PortfolioEditorFeature`.
struct PortfolioEditorView: View {
  @Bindable var store: StoreOf<PortfolioEditorFeature>

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
