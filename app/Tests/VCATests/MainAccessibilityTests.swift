import XCTest

@testable import VCA

/// Pins the `MainAccessibility` seam that powers the iPad
/// `NavigationSplitView` column-handoff focus motion and status
/// announcements (#343). The view modifiers themselves are SwiftUI
/// view-tree decorations not introspectable without a UI host, but the
/// underlying composer is a pure value-level contract:
///
/// * which `SplitFocusTarget` AT focus must land on for each sidebar /
///   portfolio-tap transition, and
/// * what string (if any) is announced through the central
///   `AccessibilityAnnouncer` env-seam on each transition.
///
/// These two surfaces are what AT users perceive when an iPad column
/// repopulates, so they are the contract that must not regress.
@MainActor
final class MainAccessibilityTests: XCTestCase {
  // MARK: - Focus target: sidebar transitions

  func testSidebarPortfoliosFocusesContentPortfolioListAnchor() {
    XCTAssertEqual(
      MainAccessibility.focusTarget(forSidebar: .portfolios),
      .contentPortfolioList
    )
  }

  func testSidebarSettingsFocusesContentSettingsAnchor() {
    // #343 AC item #2: focus lands in the *content* column's settings
    // instance (not the duplicated detail-column copy from #320) so
    // logical reading order matches sighted users' tap-into-content
    // expectation.
    XCTAssertEqual(
      MainAccessibility.focusTarget(forSidebar: .settings),
      .contentSettings
    )
  }

  func testSidebarFocusTargetsAreContentColumnAnchors() {
    // Defensive: every sidebar destination must land focus on a
    // content-column anchor (never a detail anchor) so the user's tap
    // "into" the sidebar is answered by focus in the next column over.
    let contentTargets: Set<MainAccessibility.SplitFocusTarget> = [
      .contentPortfolioList, .contentSettings,
    ]
    for sidebar in MainFeature.Sidebar.allCases {
      let target = MainAccessibility.focusTarget(forSidebar: sidebar)
      XCTAssertTrue(
        contentTargets.contains(target),
        "Sidebar \(sidebar) routed focus to \(target), expected a content-column anchor."
      )
    }
  }

  // MARK: - Focus target: portfolio open

  func testPortfolioOpenFocusesDetailPortfolioAnchor() {
    // #343 AC item #1: tapping a portfolio row in the content column
    // moves AT focus into the detail column so the AT user perceives
    // their tap populated the next pane over.
    XCTAssertEqual(
      MainAccessibility.focusTargetForPortfolioOpen,
      .detailPortfolio
    )
  }

  // MARK: - Focus target identity

  func testAllSplitFocusTargetsAreDistinct() {
    // Each anchor must be Hashable-distinct so
    // `.accessibilityFocused(_:, equals: ...)` bindings don't collide
    // across columns (e.g. focus motion intended for the content
    // column also activating the detail column's anchor).
    let allTargets: [MainAccessibility.SplitFocusTarget] = [
      .contentPortfolioList,
      .contentSettings,
      .detailPortfolio,
      .detailSettings,
      .detailEmpty,
    ]
    XCTAssertEqual(Set(allTargets).count, allTargets.count)
  }

  // MARK: - Transition announcement: sidebar

  func testSidebarPortfoliosAnnouncesPortfolios() {
    // Echoes the sidebar row label so a VoiceOver user who arrives
    // mid-announcement gets the same heading text the focused anchor
    // will read.
    XCTAssertEqual(
      MainAccessibility.transitionAnnouncement(forSidebar: .portfolios),
      "Portfolios"
    )
  }

  func testSidebarSettingsAnnouncesSettings() {
    XCTAssertEqual(
      MainAccessibility.transitionAnnouncement(forSidebar: .settings),
      "Settings"
    )
  }

  func testEverySidebarHasANonEmptyAnnouncement() {
    // A nil / empty announcement here would mean a sidebar tap on a
    // VoiceOver client with focus-moves disabled is fully silent. We
    // never want that for a primary navigation surface.
    for sidebar in MainFeature.Sidebar.allCases {
      let announcement = MainAccessibility.transitionAnnouncement(forSidebar: sidebar)
      XCTAssertNotNil(announcement, "Sidebar \(sidebar) has no announcement.")
      XCTAssertFalse(
        announcement?.isEmpty ?? true,
        "Sidebar \(sidebar) announcement is empty."
      )
    }
  }

  // MARK: - Transition announcement: portfolio open

  func testPortfolioOpenAnnouncementIsSilent() {
    // The detail column's portfolio-name header is read out when AT
    // focus lands on it (the focus move IS the announcement); a
    // leading custom announcement would double-read the title. Pin
    // this explicitly so a future "always announce" refactor cannot
    // silently regress to chatter.
    XCTAssertNil(MainAccessibility.transitionAnnouncementForPortfolioOpen)
  }
}
