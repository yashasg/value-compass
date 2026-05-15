import SwiftUI

enum AppBrand {
  static let displayName = "Investrum"
}

struct AppLogoMark: View {
  let size: CGFloat

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
        .fill(Color.appBackground)

      logoShape
        .fill(
          LinearGradient(
            colors: [
              Color.appTertiary,
              Color.appSecondary,
              Color.appPrimary,
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
    // Preserve the brand mark under Smart Invert (Settings → Accessibility →
    // Display & Text Size → Smart Invert). `AppLogoMark` is the app's only
    // custom-drawn (`Shape` + `LinearGradient`) brand vector; without this
    // opt-out, Smart Invert flips both the rounded plate and the gradient
    // because its heuristic only auto-excludes image/media content. Bundled
    // SF Symbols elsewhere are unaffected. Do not remove without
    // co-ordinating with the design system — every brand-color decision is
    // silently overridden for Smart-Invert users on this view.
    .accessibilityIgnoresInvertColors(true)
  }

  private var logoShape: some Shape {
    UnevenInvestrumGlyph()
      .scale(x: 0.78, y: 0.78, anchor: .center)
  }
}

private struct UnevenInvestrumGlyph: Shape {
  func path(in rect: CGRect) -> Path {
    let width = rect.width
    let height = rect.height

    var path = Path()
    path.move(to: CGPoint(x: rect.minX + width * 0.50, y: rect.minY + height * 0.15))
    path.addLine(to: CGPoint(x: rect.minX + width * 0.80, y: rect.minY + height * 0.57))
    path.addLine(to: CGPoint(x: rect.minX + width * 0.20, y: rect.minY + height * 0.57))
    path.closeSubpath()

    path.move(to: CGPoint(x: rect.minX + width * 0.39, y: rect.minY + height * 0.57))
    path.addLine(to: CGPoint(x: rect.minX + width * 0.58, y: rect.minY + height * 0.57))
    path.addLine(to: CGPoint(x: rect.minX + width * 0.29, y: rect.minY + height * 0.88))
    path.addLine(to: CGPoint(x: rect.minX + width * 0.14, y: rect.minY + height * 0.88))
    path.closeSubpath()

    path.move(to: CGPoint(x: rect.minX + width * 0.68, y: rect.minY + height * 0.65))
    path.addLine(to: CGPoint(x: rect.minX + width * 0.88, y: rect.minY + height * 0.88))
    path.addLine(to: CGPoint(x: rect.minX + width * 0.48, y: rect.minY + height * 0.88))
    path.closeSubpath()

    return path
  }
}

struct AppBrandHeader: View {
  let logoSize: CGFloat
  let subtitle: String?

  init(logoSize: CGFloat = 56, subtitle: String? = nil) {
    self.logoSize = logoSize
    self.subtitle = subtitle
  }

  var body: some View {
    HStack(spacing: 14) {
      AppLogoMark(size: logoSize)

      VStack(alignment: .leading, spacing: 4) {
        Text(AppBrand.displayName)
          .valueCompassTextStyle(.headlineMedium)
        if let subtitle {
          Text(subtitle)
            .valueCompassTextStyle(.bodySmall)
            .foregroundStyle(Color.appContentSecondary)
        }
      }
    }
    // `.ignore` plus a composed label keeps the spoken contract under the
    // caller's control: `.combine` with an explicit `.accessibilityLabel`
    // silently replaces the children's text (#326), so a non-nil subtitle
    // would never reach VoiceOver. `.ignore` discards the child Texts and
    // we re-emit both displayName and subtitle through one composed
    // string so the AT user hears the same copy a sighted user reads.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.accessibilityLabel(subtitle: subtitle))
  }

  /// Pure composer for the brand-header spoken contract (#326). Returns
  /// `displayName` alone when no subtitle is rendered (matches the iPad
  /// sidebar call site at `MainView.swift`), and `"<displayName>.
  /// <subtitle>"` when a subtitle is visible (matches the first-launch
  /// onboarding tagline). Empty / whitespace-only subtitles collapse to
  /// the no-subtitle form so a caller that passes `""` does not produce
  /// `"Investrum. "` with a trailing dot. Exposed at the type level so
  /// the contract is unit-testable without hosting the SwiftUI view.
  static func accessibilityLabel(subtitle: String?) -> String {
    let trimmedSubtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let trimmedSubtitle, !trimmedSubtitle.isEmpty else {
      return AppBrand.displayName
    }
    return "\(AppBrand.displayName). \(trimmedSubtitle)"
  }
}
