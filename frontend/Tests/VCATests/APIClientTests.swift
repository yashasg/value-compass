import XCTest
@testable import VCA

final class APIClientTests: XCTestCase {
    func testConfiguredBaseURLUsesInfoDictionaryValue() {
        let url = APIClient.configuredBaseURL(infoDictionary: [
            "VCAAPIBaseURL": "https://services.example.com"
        ])

        XCTAssertEqual(url.absoluteString, "https://services.example.com")
    }

    func testConfiguredBaseURLFallsBackWhenInfoDictionaryValueIsEmpty() {
        let url = APIClient.configuredBaseURL(infoDictionary: [
            "VCAAPIBaseURL": "  "
        ])

        XCTAssertEqual(url.absoluteString, "https://api.valuecompass.app")
    }
}
