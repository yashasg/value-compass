import SwiftUI

enum AppColorToken: String, CaseIterable {
  case background = "AppBackground"
  case surface = "AppSurface"
  case surfaceElevated = "AppSurfaceElevated"
  case primary = "AppPrimary"
  case secondary = "AppSecondary"
  case tertiary = "AppTertiary"
  case positive = "AppPositive"
  case negative = "AppNegative"
  case neutral = "AppNeutral"
  case error = "AppError"
  case warning = "AppWarning"
  case success = "AppSuccess"
  case info = "AppInfo"
  case input = "AppInput"
  case divider = "AppDivider"
  case contentPrimary = "AppContentPrimary"
  case contentSecondary = "AppContentSecondary"
  case contentTertiary = "AppContentTertiary"

  var assetName: String { rawValue }
}

enum AppLayoutMetrics {
  static let minimumTouchTarget: CGFloat = 44
  static let sidebarMinWidth: CGFloat = 320
  static let sidebarIdealWidth: CGFloat = 360
  static let sidebarMaxWidth: CGFloat = 420
  static let readableContentMaxWidth: CGFloat = 600
  static let wideContentMaxWidth: CGFloat = 760
  static let mainMargin: CGFloat = 24
  static let gridGutter: CGFloat = 16
  static let stackGap: CGFloat = 12
}

extension Color {
  static let appBackground = Color(AppColorToken.background.assetName)
  static let appSurface = Color(AppColorToken.surface.assetName)
  static let appSurfaceElevated = Color(AppColorToken.surfaceElevated.assetName)
  static let appPrimary = Color(AppColorToken.primary.assetName)
  static let appSecondary = Color(AppColorToken.secondary.assetName)
  static let appTertiary = Color(AppColorToken.tertiary.assetName)
  static let appPositive = Color(AppColorToken.positive.assetName)
  static let appNegative = Color(AppColorToken.negative.assetName)
  static let appNeutral = Color(AppColorToken.neutral.assetName)
  static let appError = Color(AppColorToken.error.assetName)
  static let appWarning = Color(AppColorToken.warning.assetName)
  static let appSuccess = Color(AppColorToken.success.assetName)
  static let appInfo = Color(AppColorToken.info.assetName)
  static let appInput = Color(AppColorToken.input.assetName)
  static let appDivider = Color(AppColorToken.divider.assetName)
  static let appContentPrimary = Color(AppColorToken.contentPrimary.assetName)
  static let appContentSecondary = Color(AppColorToken.contentSecondary.assetName)
  static let appContentTertiary = Color(AppColorToken.contentTertiary.assetName)
}

extension View {
  func appMinimumTouchTarget() -> some View {
    frame(
      minWidth: AppLayoutMetrics.minimumTouchTarget,
      minHeight: AppLayoutMetrics.minimumTouchTarget
    )
  }
}

extension Decimal {
  /// USD-currency display string with locale-aware grouping separators
  /// and two fractional digits (e.g. `$1,234.50`). Pinned to `en_US` so
  /// the English-only MVP renders deterministically across simulators
  /// and CI, and so VoiceOver pronounces "dollars" via the currency tag
  /// instead of reading the literal `$` glyph (#257). When multi-currency
  /// support lands post-MVP, replace the locale + currency code with
  /// `Locale.current` + `Locale.current.currency?.identifier`.
  func appCurrencyFormatted() -> String {
    formatted(
      .currency(code: "USD")
        .locale(Locale(identifier: "en_US"))
    )
  }

  /// Percent display string built from a fractional weight (e.g. `0.125`
  /// → `"12.5%"`). VoiceOver pronounces the percent glyph as "percent"
  /// reliably when emitted by `Decimal.formatted(.percent)`; the manual
  /// `"\(value * 100)%"` pattern it replaces did not (#257). Pinned to
  /// `en_US` for the English-only MVP rendering surface.
  func appPercentFormatted() -> String {
    formatted(
      .percent
        .precision(.fractionLength(0...2))
        .locale(Locale(identifier: "en_US"))
    )
  }
}
