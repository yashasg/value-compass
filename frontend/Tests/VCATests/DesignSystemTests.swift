import UIKit
import XCTest
@testable import VCA

final class DesignSystemTests: XCTestCase {
  func testSemanticColorTokenCatalogMatchesDesignContract() {
    XCTAssertEqual(
      Set(AppColorToken.allCases.map(\.assetName)),
      [
        "AppBackground",
        "AppSurface",
        "AppSurfaceElevated",
        "AppPrimary",
        "AppSecondary",
        "AppTertiary",
        "AppPositive",
        "AppNegative",
        "AppNeutral",
        "AppError",
        "AppInput",
        "AppDivider",
        "AppContentPrimary",
        "AppContentSecondary",
        "AppContentTertiary",
      ])
  }

  func testTextTokensMeetWCAGAAContrastInLightAndDarkMode() {
    let textTokens: [AppColorToken] = [.contentPrimary, .contentSecondary, .contentTertiary]
    let surfaceTokens: [AppColorToken] = [.background, .surface, .surfaceElevated]

    for token in textTokens {
      for surface in surfaceTokens {
        let lightText = resolvedRGB(token, style: .light)
        let lightSurface = resolvedRGB(surface, style: .light)
        let darkText = resolvedRGB(token, style: .dark)
        let darkSurface = resolvedRGB(surface, style: .dark)

        XCTAssertGreaterThanOrEqual(
          lightText.contrastRatio(against: lightSurface),
          4.5,
          "\(token.assetName) must meet small-text contrast against \(surface.assetName) in light mode"
        )
        XCTAssertGreaterThanOrEqual(
          darkText.contrastRatio(against: darkSurface),
          4.5,
          "\(token.assetName) must meet small-text contrast against \(surface.assetName) in dark mode"
        )
      }
    }
  }

  func testInputTokensHaveReadableTextAndDisabledContrast() {
    XCTAssertGreaterThanOrEqual(
      resolvedRGB(.contentPrimary, style: .light).contrastRatio(
        against: resolvedRGB(.input, style: .light)),
      4.5
    )
    XCTAssertGreaterThanOrEqual(
      resolvedRGB(.contentPrimary, style: .dark).contrastRatio(
        against: resolvedRGB(.input, style: .dark)),
      4.5
    )
    XCTAssertGreaterThanOrEqual(
      resolvedRGB(.input, style: .light).contrastRatio(
        against: resolvedRGB(.surfaceElevated, style: .light)),
      1.1
    )
    XCTAssertGreaterThanOrEqual(
      resolvedRGB(.input, style: .dark).contrastRatio(
        against: resolvedRGB(.surface, style: .dark)),
      1.1
    )
  }

  func testSemanticColorAssetsResolveInLightAndDarkAppearances() {
    for token in AppColorToken.allCases {
      _ = resolvedRGB(token, style: .light)
      _ = resolvedRGB(token, style: .dark)
    }
  }

  private func resolvedRGB(_ token: AppColorToken, style: UIUserInterfaceStyle) -> AppRGB {
    let traits = UITraitCollection(userInterfaceStyle: style)
    guard
      let color = UIColor(named: token.assetName, in: Bundle.main, compatibleWith: traits)
    else {
      XCTFail("Missing color asset \(token.assetName)")
      return AppRGB(red: 0, green: 0, blue: 0)
    }

    let resolved = color.resolvedColor(with: traits)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
      XCTFail("Could not resolve RGB components for \(token.assetName)")
      return AppRGB(red: 0, green: 0, blue: 0)
    }

    return AppRGB(red: Double(red), green: Double(green), blue: Double(blue))
  }
}

private struct AppRGB: Equatable {
  let red: Double
  let green: Double
  let blue: Double

  func contrastRatio(against other: AppRGB) -> Double {
    let lighter = max(relativeLuminance, other.relativeLuminance)
    let darker = min(relativeLuminance, other.relativeLuminance)
    return (lighter + 0.05) / (darker + 0.05)
  }

  private var relativeLuminance: Double {
    func channel(_ value: Double) -> Double {
      value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
  }
}
