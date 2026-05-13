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
  case input = "AppInput"
  case divider = "AppDivider"
  case contentPrimary = "AppContentPrimary"
  case contentSecondary = "AppContentSecondary"
  case contentTertiary = "AppContentTertiary"

  var assetName: String { rawValue }
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
  static let appInput = Color(AppColorToken.input.assetName)
  static let appDivider = Color(AppColorToken.divider.assetName)
  static let appContentPrimary = Color(AppColorToken.contentPrimary.assetName)
  static let appContentSecondary = Color(AppColorToken.contentSecondary.assetName)
  static let appContentTertiary = Color(AppColorToken.contentTertiary.assetName)
}
