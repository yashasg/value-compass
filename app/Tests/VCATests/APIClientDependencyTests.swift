import ComposableArchitecture
import Foundation
import XCTest

@testable import VCA

/// Pins the ``APIClientDependency`` `previewValue` seam introduced for
/// issue #282. The DI client previously shipped only `liveValue`, leaving
/// every sibling in `app/Sources/App/Dependencies/` symmetric on
/// `liveValue + previewValue` except this one — which would have routed
/// any `#Preview` consuming `@Dependency(\.apiClient)` to the
/// macro-synthesized `testValue`'s unimplemented-call reporter.
///
/// These tests guard the contract that `previewValue`:
///
/// 1. Resolves through `withDependencies(_:operation:)` and returns a
///    synthesized 200 response without hitting `APIClient.shared`.
/// 2. Echoes the caller's `URLRequest.url` on the synthesized response so
///    previews that branch on the response URL keep working.
/// 3. Is wired as the dependency value the `swift-dependencies` runtime
///    serves under `context = .preview`.
final class APIClientDependencyTests: XCTestCase {
  func testPreviewValueReturnsEmptyDataAndSynthesized200ResponseForRequest() async throws {
    let preview = APIClientDependency.previewValue
    let request = URLRequest(url: URL(string: "https://api.valuecompass.app/schema/version")!)

    let (data, response) = try await preview.send(request)

    XCTAssertEqual(data, Data())
    XCTAssertEqual(response.statusCode, 200)
    XCTAssertEqual(response.url?.absoluteString, "https://api.valuecompass.app/schema/version")
  }

  func testPreviewValueFallsBackToAboutBlankWhenRequestHasNoURL() async throws {
    let preview = APIClientDependency.previewValue
    let request = URLRequest(url: URL(string: "about:blank")!)

    let (data, response) = try await preview.send(request)

    XCTAssertEqual(data, Data())
    XCTAssertEqual(response.statusCode, 200)
    XCTAssertEqual(response.url?.absoluteString, "about:blank")
  }

  func testPreviewContextResolvesAPIClientToPreviewValue() async throws {
    let request = URLRequest(url: URL(string: "https://api.valuecompass.app/health")!)

    let (data, response) = try await withDependencies {
      $0.context = .preview
    } operation: {
      @Dependency(\.apiClient) var apiClient
      return try await apiClient.send(request)
    }

    XCTAssertEqual(data, Data())
    XCTAssertEqual(response.statusCode, 200)
  }
}
