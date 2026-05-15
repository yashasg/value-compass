import ComposableArchitecture
import Foundation

/// Top-level reducer that owns the route currently driven by `RootView`:
/// `forcedUpdate` (sticky once the backend says the running app is below the
/// supported version), `onboarding` (until the user accepts the disclaimer),
/// or `main`.
///
/// Phase 2 (#158): the `Store` is wired at app entry (`VCAApp`), `RootView`
/// scopes into the `Destination` reducer enum, and the legacy `AppState` /
/// `MinAppVersionMonitor.shared` / `PushNotificationManager.shared`
/// singletons are deleted. The `destination` is modeled as an optional
/// `Destination.State?` where `nil` represents the brief launching window
/// before the first `task` reduction completes.
@Reducer
struct AppFeature {
  @Reducer
  enum Destination {
    case forcedUpdate(ForcedUpdateFeature)
    case onboarding(OnboardingFeature)
    case main(MainFeature)
  }

  @ObservableState
  struct State: Equatable {
    var destination: Destination.State?
    var minimumAppVersion: String?
    var requiresAppUpdate: Bool = false
  }

  /// `Action` is intentionally non-`Equatable` because `MainFeature.Action`
  /// (reachable via `.destination(.main(...))`) wraps `StackAction`, which TCA
  /// 1.x does not declare `Equatable`. State remains `Equatable`, so the
  /// reducer is still testable with `TestStore`.
  enum Action {
    case task
    case minVersionEvent(MinAppVersionEvent)
    case disclaimerSeenChanged(Bool)
    case destination(Destination.Action)
  }

  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.minAppVersion) var minAppVersion

  /// Identifies the long-lived `minAppVersion.events()` subscription so it
  /// can be cancelled and replaced if `RootView`'s `.task` modifier fires
  /// more than once (multiple windows, scene reactivation, hosting in
  /// previews/tests, etc.). Without `cancelInFlight: true`, every extra
  /// `.task` send would spawn a duplicate observer that re-handles every
  /// `MinAppVersionEvent`.
  enum CancelID: Hashable { case minVersionEvents }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        let migratedDisclaimer =
          userDefaults.bool(forKey: AppPreferenceKeys.disclaimer)
          || userDefaults.bool(forKey: AppPreferenceKeys.legacyOnboarding)
        if migratedDisclaimer {
          userDefaults.setBool(value: true, forKey: AppPreferenceKeys.disclaimer)
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
        .cancellable(id: CancelID.minVersionEvents, cancelInFlight: true)

      case .minVersionEvent(let event):
        state.minimumAppVersion = event.minimumVersion
        guard event.requiresUpdate else { return .none }
        if !state.requiresAppUpdate {
          state.requiresAppUpdate = true
          state.destination = .forcedUpdate(
            ForcedUpdateFeature.State(minimumVersion: event.minimumVersion))
        }
        return .none

      case .disclaimerSeenChanged(let value):
        userDefaults.setBool(value: value, forKey: AppPreferenceKeys.disclaimer)
        if value, !state.requiresAppUpdate {
          state.destination = .main(MainFeature.State())
        }
        return .none

      case .destination(.onboarding(.delegate(.completed))):
        userDefaults.setBool(value: true, forKey: AppPreferenceKeys.disclaimer)
        if !state.requiresAppUpdate {
          state.destination = .main(MainFeature.State())
        }
        return .none

      case .destination(.main(.settings(.delegate(.dataErased)))):
        // Settings → Erase All My Data pipeline finished. Swap
        // `destination` back to onboarding programmatically so the
        // user sees the freshly reset disclaimer/welcome screen
        // without being asked to force-quit the app (HIG → Launching
        // → Quitting forbids quit/relaunch instructions). Issue #471.
        //
        // `SettingsFeature` already cleared the persisted onboarding-
        // gate user defaults (`AppPreferenceKeys.disclaimer` /
        // `legacyOnboarding`) inside the erase pipeline, so the
        // disclaimer flag does not need to be re-touched here — a
        // fresh `OnboardingFeature.State()` mirrors the cold-launch
        // post-erase posture exactly.
        if !state.requiresAppUpdate {
          state.destination = .onboarding(OnboardingFeature.State())
        }
        return .none

      case .destination:
        return .none
      }
    }
    .ifLet(\.destination, action: \.destination) {
      Destination.body
    }
  }
}

/// Equatable conformance is added via an extension so the `@Reducer` macro
/// can synthesize `Destination.State` without the deprecated
/// `@Reducer(state: .equatable)` form.
extension AppFeature.Destination.State: Equatable {}
