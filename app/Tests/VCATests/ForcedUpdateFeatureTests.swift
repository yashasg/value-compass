import ComposableArchitecture
import XCTest

@testable import VCA

/// `TestStore` coverage for `ForcedUpdateFeature` (issue #186, part of #185).
///
/// Pins the user-visible "update required" surface: the App Store URL
/// resolution rules and the single `.openAppStoreTapped` action. Because
/// `Action.openAppStoreTapped` only emits an effect (no state mutation), the
/// tests assert the URL handed to `\.openURL` instead of state diffs.
@MainActor
final class ForcedUpdateFeatureTests: XCTestCase {
  func testOpenAppStoreTappedUsesAppStoreIDWhenConfigured() async {
    let captured = LockIsolated<URL?>(nil)
    let store = TestStore(
      initialState: ForcedUpdateFeature.State(minimumVersion: "9.9.9")
    ) {
      ForcedUpdateFeature()
    } withDependencies: {
      $0.bundleInfo.info = {
        BundleInfo(
          shortVersionString: "1.0.0",
          bundleVersion: "1",
          appStoreID: "12345",
          apiBaseURLString: nil
        )
      }
      $0.openURL = OpenURLEffect { url in
        captured.setValue(url)
        return true
      }
    }

    await store.send(.openAppStoreTapped).finish()
    XCTAssertEqual(
      captured.value,
      URL(string: "itms-apps://itunes.apple.com/app/id12345")
    )
  }

  func testOpenAppStoreTappedFallsBackToSearchWhenAppStoreIDMissing() async {
    let captured = LockIsolated<URL?>(nil)
    let store = TestStore(initialState: ForcedUpdateFeature.State()) {
      ForcedUpdateFeature()
    } withDependencies: {
      $0.bundleInfo.info = {
        BundleInfo(
          shortVersionString: "1.0.0",
          bundleVersion: "1",
          appStoreID: nil,
          apiBaseURLString: nil
        )
      }
      $0.openURL = OpenURLEffect { url in
        captured.setValue(url)
        return true
      }
    }

    await store.send(.openAppStoreTapped).finish()
    XCTAssertEqual(
      captured.value,
      URL(string: "https://apps.apple.com/search?term=Investrum")
    )
  }

  func testOpenAppStoreTappedFallsBackToSearchWhenAppStoreIDEmpty() async {
    let captured = LockIsolated<URL?>(nil)
    let store = TestStore(initialState: ForcedUpdateFeature.State()) {
      ForcedUpdateFeature()
    } withDependencies: {
      $0.bundleInfo.info = {
        BundleInfo(
          shortVersionString: "1.0.0",
          bundleVersion: "1",
          appStoreID: "",
          apiBaseURLString: nil
        )
      }
      $0.openURL = OpenURLEffect { url in
        captured.setValue(url)
        return true
      }
    }

    await store.send(.openAppStoreTapped).finish()
    XCTAssertEqual(
      captured.value,
      URL(string: "https://apps.apple.com/search?term=Investrum")
    )
  }

  func testAppStoreURLPureHelperReturnsAppStoreSchemeWhenIDProvided() {
    XCTAssertEqual(
      ForcedUpdateFeature.appStoreURL(appStoreID: "67890"),
      URL(string: "itms-apps://itunes.apple.com/app/id67890")
    )
  }

  func testAppStoreURLPureHelperFallsBackWhenIDMissing() {
    XCTAssertEqual(
      ForcedUpdateFeature.appStoreURL(appStoreID: nil),
      URL(string: "https://apps.apple.com/search?term=Investrum")
    )
  }

  func testAppStoreURLPureHelperFallsBackWhenIDEmpty() {
    XCTAssertEqual(
      ForcedUpdateFeature.appStoreURL(appStoreID: ""),
      URL(string: "https://apps.apple.com/search?term=Investrum")
    )
  }
}
