import SwiftUI
import UIKit
import XCTest

@testable import VCA

/// Pins the centralized `AccessibilityAnnouncer` + `appAnnounceOnChange`
/// surface used by every inline status surface (PortfolioEditor,
/// HoldingsEditor, ContributionResult) to satisfy WCAG 2.2 SC 4.1.3 —
/// Status Messages without yanking VoiceOver focus off the user's current
/// task (#293).
@MainActor
final class AccessibilityAnnouncementsTests: XCTestCase {
  func testLiveAnnouncerPostsWithoutCrashingOnAnyMessage() {
    // `UIAccessibility.post` is a no-op when AT is off, but exercising the
    // call path still pins the closure signature and prevents a future
    // refactor from accidentally dropping the live announcer.
    AccessibilityAnnouncer.live.announce("hello")
    AccessibilityAnnouncer.live.announce("")
  }

  func testNoopAnnouncerSwallowsEveryMessage() {
    AccessibilityAnnouncer.noop.announce("ignored")
    AccessibilityAnnouncer.noop.announce("")
  }

  func testCustomAnnouncerForwardsMessagesInOrder() {
    let recorder = AnnouncementRecorder()
    let announcer = AccessibilityAnnouncer(announce: { message in
      recorder.record(message)
    })

    announcer.announce("first")
    announcer.announce("second")
    announcer.announce("third")

    XCTAssertEqual(recorder.recorded, ["first", "second", "third"])
  }

  func testHoldingsAnnouncementMessageReturnsNilWhenNoIssues() {
    XCTAssertNil(HoldingsEditorView.holdingsAnnouncementMessage(for: []))
  }

  func testHoldingsAnnouncementMessageReturnsLeadMessageForSingleIssue() {
    let issue = HoldingsDraftIssue.categoryWeightsDoNotSumTo100
    XCTAssertEqual(
      HoldingsEditorView.holdingsAnnouncementMessage(for: [issue]),
      issue.message
    )
  }

  func testHoldingsAnnouncementMessagePrefixesCountForMultipleIssues() {
    let lead = HoldingsDraftIssue.categoryWeightsDoNotSumTo100
    let follow = HoldingsDraftIssue.emptyCategoryName

    let summary = HoldingsEditorView.holdingsAnnouncementMessage(for: [lead, follow])

    XCTAssertEqual(summary, "2 validation warnings. \(lead.message)")
  }

  func testEnvironmentOverrideReplacesLiveAnnouncer() {
    let recorder = AnnouncementRecorder()
    let announcer = AccessibilityAnnouncer(announce: { message in
      recorder.record(message)
    })

    // Attach a host view to a key window so SwiftUI's appearance lifecycle
    // fires `onAppear`. Without a window the controller never reaches the
    // "in-hierarchy" phase that drives `Environment` reads on appear.
    let host = UIHostingController(
      rootView: AnnouncerProbe()
        .environment(\.accessibilityAnnouncer, announcer)
    )
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
    window.rootViewController = host
    window.makeKeyAndVisible()
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    XCTAssertEqual(recorder.recorded, ["probe"])
  }
}

private final class AnnouncementRecorder {
  private(set) var recorded: [String] = []

  func record(_ message: String) {
    recorded.append(message)
  }
}

private struct AnnouncerProbe: View {
  @Environment(\.accessibilityAnnouncer) private var announcer

  var body: some View {
    Color.clear
      .onAppear { announcer.announce("probe") }
  }
}
