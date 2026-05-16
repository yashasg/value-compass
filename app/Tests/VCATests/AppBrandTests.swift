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

  // MARK: - Spoken-text contract (#326)
  //
  // `AppBrandHeader` historically combined the displayName and subtitle
  // Texts via `.accessibilityElement(children: .combine)` and then
  // overrode the label with `displayName` alone — which silently dropped
  // the visible subtitle from VoiceOver on the first-launch onboarding
  // surface (#326). The view now exposes a pure value-level composer so
  // the spoken contract is unit-testable without hosting the SwiftUI
  // view; these tests pin that contract for the two real call sites
  // (`OnboardingView` with a subtitle, `MainView` iPad sidebar without)
  // and the two boundary inputs (empty string, whitespace-only string).

  func testAppBrandHeaderAccessibilityLabelOmitsSubtitleWhenNil() {
    XCTAssertEqual(
      AppBrandHeader.accessibilityLabel(subtitle: nil),
      "Investrum"
    )
  }

  func testAppBrandHeaderAccessibilityLabelIncludesSubtitleWhenPresent() {
    XCTAssertEqual(
      AppBrandHeader.accessibilityLabel(subtitle: "Personal contribution planning"),
      "Investrum. Personal contribution planning"
    )
  }

  func testAppBrandHeaderAccessibilityLabelTreatsEmptySubtitleAsAbsent() {
    XCTAssertEqual(
      AppBrandHeader.accessibilityLabel(subtitle: ""),
      "Investrum"
    )
  }

  func testAppBrandHeaderAccessibilityLabelTreatsWhitespaceOnlySubtitleAsAbsent() {
    XCTAssertEqual(
      AppBrandHeader.accessibilityLabel(subtitle: "   \n\t  "),
      "Investrum"
    )
  }
}
