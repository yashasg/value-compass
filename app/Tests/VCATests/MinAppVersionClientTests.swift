import XCTest

@testable import VCA

/// Verifies the `MinAppVersionClient` static helpers that replaced the
/// deleted `MinAppVersionMonitor` singleton in #158/#160. The client is the
/// integration seam the `AppFeature.task` effect subscribes to, so these
/// tests pin the contract that drives the user-visible forced-update screen.
final class MinAppVersionClientTests: XCTestCase {
  override func setUp() {
    super.setUp()
    MinAppVersionClient.resetForTesting()
  }

  override func tearDown() {
    MinAppVersionClient.resetForTesting()
    super.tearDown()
  }

  func testObserveYieldsRequiresUpdateWhenHeaderExceedsBundleVersion() async {
    let response = makeResponse(headerValue: "9999.0.0")

    MinAppVersionClient.observe(response: response, currentVersion: "1.0.0")

    let event = await firstEvent()
    XCTAssertTrue(event.requiresUpdate)
    XCTAssertEqual(event.minimumVersion, "9999.0.0")
  }

  func testObserveDoesNotRequireUpdateWhenBundleAtOrAboveHeader() async {
    let response = makeResponse(headerValue: "1.0.0")

    MinAppVersionClient.observe(response: response, currentVersion: "1.0.0")

    let event = await firstEvent()
    XCTAssertFalse(event.requiresUpdate)
    XCTAssertEqual(event.minimumVersion, "1.0.0")
  }

  func testRequiresUpdateIsStickyAcrossLaterResponses() async {
    let high = makeResponse(headerValue: "9999.0.0")
    let low = makeResponse(headerValue: "1.0.0")

    MinAppVersionClient.observe(response: high, currentVersion: "1.0.0")
    MinAppVersionClient.observe(response: low, currentVersion: "1.0.0")

    let event = await firstEvent()
    XCTAssertTrue(event.requiresUpdate, "stickiness preserves the upgrade gate once tripped")
    XCTAssertEqual(event.minimumVersion, "1.0.0")
  }

  func testMissingHeaderIsIgnored() async {
    let response = makeResponse(headerValue: nil)

    MinAppVersionClient.observe(response: response, currentVersion: "1.0.0")

    let event = await firstEvent()
    XCTAssertFalse(event.requiresUpdate)
    XCTAssertNil(event.minimumVersion)
  }

  // MARK: - Helpers

  private func makeResponse(headerValue: String?) -> HTTPURLResponse {
    let url = URL(string: "https://example.com/")!
    var headers: [String: String] = [:]
    if let headerValue {
      headers["X-Min-App-Version"] = headerValue
    }
    return HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: "HTTP/1.1",
      headerFields: headers
    )!
  }

  /// Subscribes to `liveValue.events()` and returns the first emitted value.
  /// `events()` replays the latest broadcast value to new subscribers, so
  /// observing once is enough to verify the post-`observe(_:)` state.
  private func firstEvent() async -> MinAppVersionEvent {
    var iterator = MinAppVersionClient.liveValue.events().makeAsyncIterator()
    guard let event = await iterator.next() else {
      XCTFail("Expected MinAppVersionClient.events() to yield at least one event")
      return MinAppVersionEvent(requiresUpdate: false, minimumVersion: nil)
    }
    return event
  }
}
