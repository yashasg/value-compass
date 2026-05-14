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
    .accessibilityElement(children: .combine)
    .accessibilityLabel(AppBrand.displayName)
  }
}
