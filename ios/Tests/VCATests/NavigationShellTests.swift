import SwiftUI
import XCTest
@testable import VCA

final class NavigationShellTests: XCTestCase {
    func testCompactWidthUsesNavigationStack() {
        XCTAssertEqual(MainView.navigationShellKind(for: .compact), .stack)
    }

    func testRegularWidthUsesNavigationSplitView() {
        XCTAssertEqual(MainView.navigationShellKind(for: .regular), .splitView)
    }
}
