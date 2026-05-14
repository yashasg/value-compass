import ComposableArchitecture
import Foundation

/// Top-level reducer that owns the route currently driven by `RootView`:
/// `forcedUpdate` (sticky once the backend says the running app is below the
/// supported version), `onboarding` (until the user accepts the disclaimer),
/// or `main`.
///
/// Phase 0 skeleton (issue #148): the three child destinations reference
/// placeholder reducers (`ForcedUpdateFeature`, `OnboardingFeature`,
/// `MainFeature`) that Phase 1 issues replace one at a time. No `Store` is
/// instantiated in this PR — wiring lands in Phase 2 (#158). `RootView`,
/// `AppState`, and `MinAppVersionMonitor.shared` continue to drive the live
/// app until then.
@Reducer
struct AppFeature {
  @ObservableState
  struct State: Equatable {
    var destination: Destination = .launching
    var minimumAppVersion: String?
    var requiresAppUpdate: Bool = false
  }

  /// Routing state for the top-level UI. `launching` covers the brief window
  /// between `Scene` init and the first `task` reduction; `forcedUpdate` is
  /// sticky for the remainder of the process lifetime once entered.
  @CasePathable
  enum Destination: Equatable {
    case launching
    case forcedUpdate(ForcedUpdateFeature.State)
    case onboarding(OnboardingFeature.State)
    case main(MainFeature.State)
  }

  enum Action: Equatable {
    case task
    case minVersionEvent(MinAppVersionEvent)
    case disclaimerSeenChanged(Bool)
    case destination(Destination)
  }

  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.minAppVersion) var minAppVersion

  /// `UserDefaults` keys mirrored from `AppState` so they can be read from
  /// the (nonisolated) reducer body. `AppState` itself is `@MainActor` and
  /// stays untouched in Phase 0; #158 deletes it once the `Store` is wired.
  private enum DefaultsKey {
    static let disclaimer = "com.valuecompass.hasSeenDisclaimer"
    static let legacyOnboarding = "com.valuecompass.hasCompletedOnboarding"
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        let migratedDisclaimer =
          userDefaults.bool(forKey: DefaultsKey.disclaimer)
          || userDefaults.bool(forKey: DefaultsKey.legacyOnboarding)
        if migratedDisclaimer {
          userDefaults.setBool(value: true, forKey: DefaultsKey.disclaimer)
        }
        if !state.requiresAppUpdate {
          state.destination =
            migratedDisclaimer
            ? .main(MainFeature.State())
            : .onboarding(OnboardingFeature.State())
        }
        return .run { [events = minAppVersion.events] send in
          for await event in events() {
            await send(.minVersionEvent(event))
          }
        }

      case .minVersionEvent(let event):
        state.minimumAppVersion = event.minimumVersion
        guard event.requiresUpdate else { return .none }
        if !state.requiresAppUpdate {
          state.requiresAppUpdate = true
          state.destination = .forcedUpdate(ForcedUpdateFeature.State())
        }
        return .none

      case .disclaimerSeenChanged(let value):
        userDefaults.setBool(value: value, forKey: DefaultsKey.disclaimer)
        if value, !state.requiresAppUpdate {
          state.destination = .main(MainFeature.State())
        }
        return .none

      case .destination(let destination):
        if state.requiresAppUpdate, !destination.is(\.forcedUpdate) {
          return .none
        }
        state.destination = destination
        return .none
      }
    }
  }
}
