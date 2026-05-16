import Foundation

/// Pure catalog of per-row primary actions for the two MVP list surfaces
/// (`PortfolioListView`, `ContributionHistoryView`).
///
/// HIG → Context menus says: *"When you provide a context menu for a list
/// row, use the same actions you offer with swipe gestures so that people
/// who can't perform a swipe gesture — for example, when using a pointer
/// — can still access the actions."* (#341)
///
/// This file is the single source of truth for that action set. The
/// SwiftUI views consume the same catalog to render three input-mode
/// surfaces for the same actions:
///
/// * `.swipeActions(edge: .trailing)` — touch (iPhone, iPad in touch mode)
/// * `.contextMenu { ... }` — pointer (right-click / Control-click on
///   iPad with trackpad / mouse / Magic Keyboard) and long-press on
///   touch devices, HIG #341
/// * `.accessibilityAction(named:)` — Voice Control / Switch Control /
///   Full Keyboard Access / VoiceOver Actions rotor (#285,
///   WCAG 2.5.1 Pointer Gestures)
///
/// `RowContextActionsTests` pins the action set against the visible
/// labels and destructive roles so the three surfaces cannot drift apart
/// silently when copy or icon changes land in one place but not the others.
struct RowContextAction: Equatable, Hashable {
  /// Visible button label. Must match the title shipped on the matching
  /// `.swipeActions` and `.accessibilityAction(named:)` so spoken /
  /// swipe / context-menu paths converge on the same word.
  let title: String

  /// SF Symbol rendered alongside the label in the context-menu entry.
  /// Context-menu items support icons (swipeActions do not); the icon
  /// is purely a context-menu affordance — `.swipeActions` and
  /// `.accessibilityAction(named:)` only consume `title`.
  let systemImage: String

  /// Whether this action should adopt the SwiftUI `.destructive` role so
  /// the context-menu row renders in red (HIG → *Patterns → Confirming
  /// an action*: destructive choices are clearly identified) and so the
  /// matching swipe button shows the same destructive treatment.
  let isDestructive: Bool

  /// Discriminator the view layer switches on to dispatch the right
  /// store action. Kept separate from `title` so renaming the visible
  /// label never silently rewires the store dispatch.
  let kind: Kind

  enum Kind: String, Equatable, Hashable {
    case edit
    case delete
  }
}

/// Per-row actions for `PortfolioListView`. Order matches the visible
/// context-menu order (Edit above Delete) so the destructive option sits
/// at the bottom of the menu where HIG places it.
enum PortfolioRowContextActions {
  static let edit = RowContextAction(
    title: "Edit",
    systemImage: "pencil",
    isDestructive: false,
    kind: .edit
  )

  static let delete = RowContextAction(
    title: "Delete",
    systemImage: "trash",
    isDestructive: true,
    kind: .delete
  )

  /// Full action set in display order. Tests use this to enforce
  /// parity between the swipe-actions block and the context-menu block
  /// on `PortfolioListView`.
  static let all: [RowContextAction] = [edit, delete]
}

/// Per-row actions for `ContributionHistoryView`. Each saved-result row
/// exposes only Delete (the row's primary tap is a navigation push into
/// the detail surface, which is the row's "open" action and does not
/// belong in the per-row destructive menu).
enum ContributionHistoryRowContextActions {
  static let delete = RowContextAction(
    title: "Delete",
    systemImage: "trash",
    isDestructive: true,
    kind: .delete
  )

  /// Full action set in display order. Tests use this to enforce
  /// parity between the swipe-actions block and the context-menu block
  /// on `ContributionHistoryView`.
  static let all: [RowContextAction] = [delete]
}
