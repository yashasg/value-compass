import ComposableArchitecture
import SwiftUI

/// Top-level switch between launching, forced-update, onboarding, and the
/// main UI.
///
/// Phase 2 (#158): scopes into `AppFeature.Destination` so each routed
/// feature is driven by the single root `Store` constructed in `VCAApp`.
/// `MinAppVersionMonitor.requiresUpdate` is no longer observed directly —
/// `AppFeature` collapses min-version events into a sticky
/// `.forcedUpdate(...)` destination. `nil` destination is the brief
/// launching window before the first `task` reduction completes.
struct RootView: View {
  @Bindable var store: StoreOf<AppFeature>

  init(store: StoreOf<AppFeature>) {
    self.store = store
  }

  var body: some View {
    Group {
      if let destinationStore = store.scope(
        state: \.destination, action: \.destination)
      {
        switch destinationStore.case {
        case .forcedUpdate(let scoped):
          ForcedUpdateView(store: scoped)
        case .onboarding(let scoped):
          OnboardingView(store: scoped)
        case .main(let scoped):
          MainView(store: scoped)
        }
      } else {
        ProgressView()
          .progressViewStyle(.circular)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.appBackground)
      }
    }
    .tint(Color.appPrimary)
    .foregroundStyle(Color.appContentPrimary)
    .background(Color.appBackground)
    .task { await store.send(.task).finish() }
  }
}
