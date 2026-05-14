import XCTest

@testable import VCA

final class ValueCompassTypographyTests: XCTestCase {
  func testTypographyStylesMatchDesignSystemFamilies() {
    XCTAssertEqual(ValueCompassTextStyle.displayLarge.fontFamily, "Manrope")
    XCTAssertEqual(ValueCompassTextStyle.headlineMedium.fontFamily, "Manrope")
    XCTAssertEqual(ValueCompassTextStyle.bodyLarge.fontFamily, "Work Sans")
    XCTAssertEqual(ValueCompassTextStyle.bodySmall.fontFamily, "Work Sans")
    XCTAssertEqual(ValueCompassTextStyle.data.fontFamily, "IBM Plex Sans")
    XCTAssertEqual(ValueCompassTextStyle.labelCaps.fontFamily, "IBM Plex Sans")
  }

  func testTypographyScaleMatchesStitchBaseline() {
    XCTAssertEqual(ValueCompassTextStyle.displayLarge.fontSize, 34)
    XCTAssertEqual(ValueCompassTextStyle.displayLarge.lineHeight, 41)
    XCTAssertEqual(ValueCompassTextStyle.headlineMedium.fontSize, 24)
    XCTAssertEqual(ValueCompassTextStyle.headlineMedium.lineHeight, 30)
    XCTAssertEqual(ValueCompassTextStyle.bodyLarge.fontSize, 17)
    XCTAssertEqual(ValueCompassTextStyle.bodyLarge.lineHeight, 24)
    XCTAssertEqual(ValueCompassTextStyle.bodySmall.fontSize, 15)
    XCTAssertEqual(ValueCompassTextStyle.bodySmall.lineHeight, 20)
    XCTAssertEqual(ValueCompassTextStyle.data.fontSize, 16)
    XCTAssertEqual(ValueCompassTextStyle.data.lineHeight, 20)
    XCTAssertEqual(ValueCompassTextStyle.labelCaps.fontSize, 12)
    XCTAssertEqual(ValueCompassTextStyle.labelCaps.lineHeight, 16)
  }

  func testOnlyDataStyleRequiresTabularFigures() {
    for style in ValueCompassTextStyle.allCases {
      XCTAssertEqual(style.usesTabularFigures, style == .data)
    }
  }
}
