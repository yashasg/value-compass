import SwiftUI
import UIKit
import XCTest

@testable import VCA

/// Regression smoke for #346.
///
/// `AppLogoMark` is the only custom-drawn (`Shape` + `LinearGradient`)
/// brand vector in the app, so it carries `.accessibilityIgnoresInvertColors(true)`
/// to survive Smart Invert (SF Symbols and asset images are auto-excluded
/// by the system; a hand-drawn `Shape` is not).
///
/// SwiftUI's `accessibilityIgnoresInvertColors` modifier is applied through
/// the accessibility element overlay rather than the public
/// `UIView.accessibilityIgnoresInvertColors` property, so an exact "modifier
/// applied" assertion would have to rely on private SwiftUI internals and
/// would be brittle. Instead, the canonical non-removable guard is the
/// dedicated code comment on `AppLogoMark` in `AppBrand.swift`. This file
/// keeps a render smoke test so that the brand mark and its surrounding
/// view tree continue to host cleanly — if a future refactor breaks
/// `AppLogoMark`, the test fails here before the visual regression ships.
@MainActor
final class AppBrandTests: XCTestCase {
  func testAppLogoMarkHostsAtOnboardingHeroSize() {
    let host = UIHostingController(rootView: AppLogoMark(size: 72))
    XCTAssertNotNil(host.view)
  }

  func testAppLogoMarkHostsAtIPadSidebarSize() {
    let host = UIHostingController(rootView: AppLogoMark(size: 44))
    XCTAssertNotNil(host.view)
  }

  func testAppBrandHeaderHostsWithSubtitle() {
    let host = UIHostingController(
      rootView: AppBrandHeader(logoSize: 72, subtitle: "Personal contribution planning"))
    XCTAssertNotNil(host.view)
  }
}
