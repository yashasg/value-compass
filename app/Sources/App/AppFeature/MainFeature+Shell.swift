import SwiftUI

extension MainFeature {
  /// Adaptive shell rendered around `MainFeature` by the Phase 2 view layer
  /// (#159). Mirrors `MainView.NavigationShellKind` so the Phase 2 view does
  /// not duplicate the size-class rule.
  enum NavigationShellKind {
    case stack
    case splitView
  }

  /// Compact horizontal size classes use a `NavigationStack`; regular and
  /// `nil` size classes use an iPad-native `NavigationSplitView`. Mirrors
  /// `MainView.navigationShellKind(for:)`.
  static func shellKind(for horizontalSizeClass: UserInterfaceSizeClass?)
    -> NavigationShellKind
  {
    horizontalSizeClass == .compact ? .stack : .splitView
  }
}
