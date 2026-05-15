import ComposableArchitecture
import XCTest

@testable import VCA

/// `TestStore` coverage for `OnboardingFeature` (issue #187, part of #185).
///
/// Pins the first-launch onboarding surface: the disclaimer toggle, the
/// "start setup" tap that requests push authorization before signaling the
/// parent, and the inert `.delegate` case the parent reducer owns.
@MainActor
final class OnboardingFeatureTests: XCTestCase {
  func testAcknowledgeDisclaimerTappedFlipsState() async {
    let store = TestStore(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    }

    await store.send(.acknowledgeDisclaimerTapped) {
      $0.hasAcknowledgedDisclaimer = true
    }
  }

  func testStartSetupTappedRequestsAuthorizationThenCompletes() async {
    let calls = LockIsolated(0)
    let store = TestStore(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    } withDependencies: {
      $0.pushNotifications.requestAuthorizationAndRegister = {
        calls.withValue { $0 += 1 }
      }
    }

    await store.send(.startSetupTapped)
    await store.receive(\.delegate.completed)
    XCTAssertEqual(calls.value, 1)
  }

  func testStartSetupTappedDoesNotMutateDisclaimerState() async {
    let store = TestStore(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    } withDependencies: {
      $0.pushNotifications.requestAuthorizationAndRegister = {}
    }

    await store.send(.startSetupTapped)
    await store.receive(\.delegate.completed)
  }

  func testDelegateCompletedIsNoOpOnState() async {
    let store = TestStore(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    }

    await store.send(.delegate(.completed))
  }

  func testDelegateCompletedIsNoOpEvenAfterDisclaimerAcknowledged() async {
    let store = TestStore(
      initialState: OnboardingFeature.State(hasAcknowledgedDisclaimer: true)
    ) {
      OnboardingFeature()
    }

    await store.send(.delegate(.completed))
  }
}
