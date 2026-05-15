import ComposableArchitecture
import XCTest

@testable import VCA

/// `TestStore` coverage for `AppFeature` (issue #189, part of #185).
///
/// Pins the top-level routing reducer that owns the
/// forced-update / onboarding / main destination, the `disclaimer` /
/// `legacyOnboarding` migration, and the `MinAppVersionEvent` stream
/// subscription started by `.task`.
///
/// `AppFeature.Action` is intentionally non-`Equatable` (it wraps the
/// non-`Equatable` `MainFeature.Action`), so received-action assertions use
/// the macro-synthesized casepath form (`store.receive(\.minVersionEvent)`).
@MainActor
final class AppFeatureTests: XCTestCase {
  // MARK: - .task routing

  func testTaskWithDisclaimerNotSeenRoutesToOnboarding() async {
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.userDefaults.bool = { _ in false }
      $0.userDefaults.setBool = { _, _ in }
      $0.minAppVersion.events = { AsyncStream { $0.finish() } }
    }

    await store.send(.task) {
      $0.destination = .onboarding(OnboardingFeature.State())
    }
    await store.finish()
  }

  func testTaskWithDisclaimerSeenRoutesToMain() async {
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.userDefaults.bool = { key in key == AppPreferenceKeys.disclaimer }
      $0.userDefaults.setBool = { _, _ in }
      $0.minAppVersion.events = { AsyncStream { $0.finish() } }
    }

    await store.send(.task) {
      $0.destination = .main(MainFeature.State())
    }
    await store.finish()
  }

  func testTaskMigratesLegacyOnboardingFlagToDisclaimer() async {
    let writes = LockIsolated<[(value: Bool, key: String)]>([])
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.userDefaults.bool = { key in
        key == AppPreferenceKeys.legacyOnboarding
      }
      $0.userDefaults.setBool = { value, key in
        writes.withValue { $0.append((value, key)) }
      }
      $0.minAppVersion.events = { AsyncStream { $0.finish() } }
    }

    await store.send(.task) {
      $0.destination = .main(MainFeature.State())
    }
    await store.finish()

    XCTAssertEqual(
      writes.value.map { "\($0.key)=\($0.value)" },
      ["\(AppPreferenceKeys.disclaimer)=true"]
    )
  }

  func testTaskDoesNotOverwriteDestinationWhileRequiresAppUpdate() async {
    let initialDestination: AppFeature.Destination.State =
      .forcedUpdate(ForcedUpdateFeature.State(minimumVersion: "9.9.9"))
    let store = TestStore(
      initialState: AppFeature.State(
        destination: initialDestination,
        minimumAppVersion: "9.9.9",
        requiresAppUpdate: true
      )
    ) {
      AppFeature()
    } withDependencies: {
      $0.userDefaults.bool = { _ in true }
      $0.userDefaults.setBool = { _, _ in }
      $0.minAppVersion.events = { AsyncStream { $0.finish() } }
    }

    await store.send(.task)
    await store.finish()
  }

  // MARK: - .minVersionEvent

  func testMinVersionEventRequiresUpdateRoutesToForcedUpdate() async {
    let store = TestStore(
      initialState: AppFeature.State(destination: .main(MainFeature.State()))
    ) {
      AppFeature()
    }

    await store.send(
      .minVersionEvent(MinAppVersionEvent(requiresUpdate: true, minimumVersion: "9.9.9"))
    ) {
      $0.minimumAppVersion = "9.9.9"
      $0.requiresAppUpdate = true
      $0.destination = .forcedUpdate(ForcedUpdateFeature.State(minimumVersion: "9.9.9"))
    }
  }

  func testMinVersionEventRequiresUpdateAfterStickyDoesNotRewriteDestination() async {
    let store = TestStore(
      initialState: AppFeature.State(
        destination: .forcedUpdate(ForcedUpdateFeature.State(minimumVersion: "9.9.9")),
        minimumAppVersion: "9.9.9",
        requiresAppUpdate: true
      )
    ) {
      AppFeature()
    }

    await store.send(
      .minVersionEvent(MinAppVersionEvent(requiresUpdate: true, minimumVersion: "10.0.0"))
    ) {
      $0.minimumAppVersion = "10.0.0"
    }
  }

  func testMinVersionEventDoesNotRequireUpdateIsAlmostNoOp() async {
    let store = TestStore(
      initialState: AppFeature.State(destination: .main(MainFeature.State()))
    ) {
      AppFeature()
    }

    await store.send(
      .minVersionEvent(MinAppVersionEvent(requiresUpdate: false, minimumVersion: "1.0.0"))
    ) {
      $0.minimumAppVersion = "1.0.0"
    }
  }

  // MARK: - .disclaimerSeenChanged

  func testDisclaimerSeenChangedTrueRoutesToMainAndPersists() async {
    let writes = LockIsolated<[(value: Bool, key: String)]>([])
    let store = TestStore(
      initialState: AppFeature.State(
        destination: .onboarding(OnboardingFeature.State())
      )
    ) {
      AppFeature()
    } withDependencies: {
      $0.userDefaults.setBool = { value, key in
        writes.withValue { $0.append((value, key)) }
      }
    }

    await store.send(.disclaimerSeenChanged(true)) {
      $0.destination = .main(MainFeature.State())
    }

    XCTAssertEqual(
      writes.value.map { "\($0.key)=\($0.value)" },
      ["\(AppPreferenceKeys.disclaimer)=true"]
    )
  }

  func testDisclaimerSeenChangedTrueWhileRequiresAppUpdateLeavesDestinationAlone() async {
    let writes = LockIsolated<[(value: Bool, key: String)]>([])
    let store = TestStore(
      initialState: AppFeature.State(
        destination: .forcedUpdate(ForcedUpdateFeature.State(minimumVersion: "9.9.9")),
        minimumAppVersion: "9.9.9",
        requiresAppUpdate: true
      )
    ) {
      AppFeature()
    } withDependencies: {
      $0.userDefaults.setBool = { value, key in
        writes.withValue { $0.append((value, key)) }
      }
    }

    await store.send(.disclaimerSeenChanged(true))

    XCTAssertEqual(
      writes.value.map { "\($0.key)=\($0.value)" },
      ["\(AppPreferenceKeys.disclaimer)=true"]
    )
  }

  // MARK: - .destination(.onboarding(.delegate(.completed)))

  func testOnboardingDelegateCompletedRoutesToMainAndPersists() async {
    let writes = LockIsolated<[(value: Bool, key: String)]>([])
    let store = TestStore(
      initialState: AppFeature.State(
        destination: .onboarding(OnboardingFeature.State())
      )
    ) {
      AppFeature()
    } withDependencies: {
      $0.userDefaults.setBool = { value, key in
        writes.withValue { $0.append((value, key)) }
      }
    }

    await store.send(.destination(.onboarding(.delegate(.completed)))) {
      $0.destination = .main(MainFeature.State())
    }

    XCTAssertEqual(
      writes.value.map { "\($0.key)=\($0.value)" },
      ["\(AppPreferenceKeys.disclaimer)=true"]
    )
  }

  // MARK: - .destination(.main(.settings(.delegate(.dataErased)))) — issue #471

  /// HIG → Launching → Quitting: the post-erase route swap must happen
  /// in-process so the user does not have to force-quit the app to see
  /// the freshly reset onboarding gate. `AppFeature` intercepts the
  /// `SettingsFeature.delegate(.dataErased)` notification and swaps
  /// `destination` to a fresh `OnboardingFeature.State()`.
  func testSettingsDataErasedDelegateRoutesToOnboarding() async {
    let store = TestStore(
      initialState: AppFeature.State(destination: .main(MainFeature.State()))
    ) {
      AppFeature()
    }

    await store.send(.destination(.main(.settings(.delegate(.dataErased))))) {
      $0.destination = .onboarding(OnboardingFeature.State())
    }
  }

  /// While `requiresAppUpdate` is sticky, the post-erase reroute MUST
  /// NOT clobber the forced-update destination. The forced-update gate
  /// stays on screen until the user updates and relaunches naturally.
  func testSettingsDataErasedDelegateWhileRequiresAppUpdateLeavesDestinationAlone() async {
    let store = TestStore(
      initialState: AppFeature.State(
        destination: .forcedUpdate(ForcedUpdateFeature.State(minimumVersion: "1.2.3")),
        requiresAppUpdate: true
      )
    ) {
      AppFeature()
    }

    // No state mutation expected — destination stays on `.forcedUpdate(...)`.
    await store.send(.destination(.main(.settings(.delegate(.dataErased)))))
  }

  // MARK: - .task cancel-in-flight

  func testTaskCancelInFlightDeduplicatesEventSubscription() async {
    let subscriptions = LockIsolated(0)
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.userDefaults.bool = { key in key == AppPreferenceKeys.disclaimer }
      $0.userDefaults.setBool = { _, _ in }
      $0.minAppVersion.events = {
        subscriptions.withValue { $0 += 1 }
        return AsyncStream { continuation in
          continuation.yield(
            MinAppVersionEvent(requiresUpdate: false, minimumVersion: "1.2.3"))
          continuation.finish()
        }
      }
    }
    store.exhaustivity = .off

    await store.send(.task)
    await store.send(.task)
    await store.finish()

    XCTAssertEqual(subscriptions.value, 2)
  }
}
