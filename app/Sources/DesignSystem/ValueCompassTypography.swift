import SwiftUI
import UIKit

enum ValueCompassTextStyle: String, CaseIterable {
  case displayLarge
  case headlineMedium
  case bodyLarge
  case bodySmall
  case data
  case labelCaps

  var fontFamily: String {
    switch self {
    case .displayLarge, .headlineMedium:
      return "Manrope"
    case .bodyLarge, .bodySmall:
      return "Work Sans"
    case .data, .labelCaps:
      return "IBM Plex Sans"
    }
  }

  var fontSize: CGFloat {
    switch self {
    case .displayLarge:
      return 34
    case .headlineMedium:
      return 24
    case .bodyLarge:
      return 17
    case .bodySmall:
      return 15
    case .data:
      return 16
    case .labelCaps:
      return 12
    }
  }

  var lineHeight: CGFloat {
    switch self {
    case .displayLarge:
      return 41
    case .headlineMedium:
      return 30
    case .bodyLarge:
      return 24
    case .bodySmall, .data:
      return 20
    case .labelCaps:
      return 16
    }
  }

  var letterSpacing: CGFloat {
    switch self {
    case .displayLarge:
      return -0.5
    case .headlineMedium:
      return -0.3
    case .bodyLarge:
      return -0.2
    case .bodySmall:
      return 0
    case .data:
      return 0.2
    case .labelCaps:
      return 0.5
    }
  }

  var weight: Font.Weight {
    switch self {
    case .displayLarge:
      return .bold
    case .headlineMedium, .labelCaps:
      return .semibold
    case .bodyLarge, .bodySmall:
      return .regular
    case .data:
      return .medium
    }
  }

  var relativeTextStyle: Font.TextStyle {
    switch self {
    case .displayLarge:
      return .largeTitle
    case .headlineMedium:
      return .title2
    case .bodyLarge:
      return .body
    case .bodySmall:
      return .subheadline
    case .data:
      return .body
    case .labelCaps:
      return .caption
    }
  }

  var usesTabularFigures: Bool {
    switch self {
    case .data:
      return true
    case .displayLarge, .headlineMedium, .bodyLarge, .bodySmall, .labelCaps:
      return false
    }
  }

  var customFontName: String? {
    let name: String
    switch self {
    case .displayLarge:
      name = "Manrope-Bold"
    case .headlineMedium:
      name = "Manrope-SemiBold"
    case .bodyLarge, .bodySmall:
      name = "WorkSans-Regular"
    case .data:
      name = "IBMPlexSans-Medium"
    case .labelCaps:
      name = "IBMPlexSans-SemiBold"
    }

    return UIFont(name: name, size: fontSize) == nil ? nil : name
  }

  var font: Font {
    if let customFontName {
      return .custom(customFontName, size: fontSize, relativeTo: relativeTextStyle)
    }

    return .system(relativeTextStyle, design: .default, weight: weight)
  }
}

struct ValueCompassTextStyleModifier: ViewModifier {
  let style: ValueCompassTextStyle

  @ViewBuilder
  func body(content: Content) -> some View {
    let lineSpacing = max(0, style.lineHeight - style.fontSize)
    let styledContent =
      content
      .font(style.font)
      .tracking(style.letterSpacing)
      .lineSpacing(lineSpacing)
      .fontWeight(style.weight)

    if style.usesTabularFigures {
      styledContent.monospacedDigit()
    } else {
      styledContent
    }
  }
}

extension View {
  func valueCompassTextStyle(_ style: ValueCompassTextStyle) -> some View {
    modifier(ValueCompassTextStyleModifier(style: style))
  }
}
