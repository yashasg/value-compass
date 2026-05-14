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
