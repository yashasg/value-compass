import Foundation

/// Pure composer for the iPad `NavigationSplitView` column-handoff
/// accessibility seam (#343). The SwiftUI focus / announcement
/// modifiers themselves are view-tree decorations not introspectable
/// without a UI host, but the underlying composer is a pure value-level
/// contract:
///
/// * which `SplitFocusTarget` AT focus must land on for each
///   sidebar / detail / portfolio-tap transition, and
/// * what string (if any) is announced through the central
///   `AccessibilityAnnouncer` env-seam on each transition.
///
/// These two surfaces are what AT users perceive when a column
/// repopulates, so they are the contract that must not regress.
/// Same family as `OnboardingAccessibility` (#330) and
/// `AccessibilityAnnouncer` (#293) — once a column flip happens, the
/// view layer routes both a focus move *and* an announcement so users
/// who have focus-moves disabled or interrupted by SwiftUI's column
/// unmount-rebuild still perceive the transition. WCAG 2.2 SC 4.1.3
/// (Status Messages), SC 3.2.2 (On Input), and SC 2.4.3 (Focus Order)
/// require that cross-column content swaps be programmatically
/// perceivable to assistive technologies.
enum MainAccessibility {
  /// VoiceOver / Switch-Control / Full-Keyboard-Access focus anchors
  /// for the iPad `NavigationSplitView` columns. Each value is bound to
  /// the corresponding column's invisible header anchor via
  /// `.accessibilityFocused($splitFocus, equals: ...)` in `MainView`.
  /// The targets are non-interactive headers (not buttons) so Switch
  /// Control single-step scanners do not accidentally activate them on
  /// the focus move.
  enum SplitFocusTarget: Hashable, Sendable {
    /// Header anchor at the top of the content column when the sidebar
    /// shows the portfolio list.
    case contentPortfolioList

    /// Header anchor at the top of the content column when the sidebar
    /// shows settings.
    case contentSettings

    /// Header anchor at the top of the detail column when a portfolio
    /// is selected.
    case detailPortfolio

    /// Header anchor at the top of the detail column when settings is
    /// duplicated in the detail column (#320 documents the duplication
    /// itself; the focus target lives on the content-column instance
    /// per the AC of #343, but the detail-column anchor is kept so the
    /// duplication can be re-routed later without churn).
    case detailSettings

    /// Header anchor at the top of the detail column when no portfolio
    /// is selected and the placeholder `ContentUnavailableView` is
    /// shown.
    case detailEmpty
  }

  /// Returns the focus target to move VoiceOver focus to when the
  /// sidebar selection changes. The destination is always a
  /// content-column anchor — the user's tap "into" the sidebar is
  /// answered by focus landing on the column that repopulated as a
  /// result. For `.portfolios` with a prior selection, the
  /// detail column also repopulates (with the restored portfolio) but
  /// the AC of #343 lands focus on the portfolio-list heading so
  /// logical reading order matches sighted users' eye path
  /// (sidebar → content → detail).
  static func focusTarget(forSidebar sidebar: MainFeature.Sidebar) -> SplitFocusTarget {
    switch sidebar {
    case .portfolios: return .contentPortfolioList
    case .settings: return .contentSettings
    }
  }

  /// Returns the focus target to move VoiceOver focus to when the user
  /// taps a portfolio row in the content column. This is the only
  /// content→detail transition in the v1 surface; sidebar→Portfolios
  /// with a prior selection routes focus through
  /// `focusTarget(forSidebar:)` instead so the destination matches the
  /// user's tap target (the sidebar, which logically reads into the
  /// content column).
  static let focusTargetForPortfolioOpen: SplitFocusTarget = .detailPortfolio

  /// Returns the announcement string for the sidebar selection
  /// transition, or `nil` to skip the announcement when the user is
  /// re-entering a tab and the focus move alone is sufficient. The
  /// strings deliberately echo the sidebar row labels so a VoiceOver
  /// user who arrives mid-announcement gets the same heading text the
  /// focused anchor will read.
  static func transitionAnnouncement(forSidebar sidebar: MainFeature.Sidebar) -> String? {
    switch sidebar {
    case .portfolios: return "Portfolios"
    case .settings: return "Settings"
    }
  }

  /// Returns the announcement string for the detail-column portfolio
  /// open transition. Returns `nil` when the focus move alone is
  /// sufficient — the detail column's portfolio-name header will be
  /// read out automatically when focus lands on it, and a leading
  /// announcement would double-read the title.
  static let transitionAnnouncementForPortfolioOpen: String? = nil
}
