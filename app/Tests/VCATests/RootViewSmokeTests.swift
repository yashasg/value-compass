import ComposableArchitecture
import SwiftData
import SwiftUI
import XCTest

@testable import VCA

@MainActor
final class RootViewSmokeTests: XCTestCase {
  func testRootViewCanBeHostedWithRequiredDependencies() throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let store = Store(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.minAppVersion.events = {
        AsyncStream { continuation in continuation.finish() }
      }
    }
    let view = RootView(store: store)
      .modelContainer(container)
    let host = UIHostingController(rootView: view)

    XCTAssertNotNil(host.view)
  }
}
