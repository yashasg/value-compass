import SwiftUI

/// Pure catalog for the modal-context contract of every `.sheet(item:)`
/// presentation in the app (#260). Same composer family as
/// ``ProgressViewAccessibility`` (#371), ``OnboardingAccessibility``
/// (#330), ``MainAccessibility`` (#343), and ``SettingsAccessibility``
/// (#473): the SwiftUI modifier surface
/// (`.accessibilityAddTraits(_:)` on the sheet's root content) is a
/// view-tree decoration not introspectable without a UI host, but the
/// trait set it consumes — "does VoiceOver / Switch Control recognize
/// this presentation as a modal container?" — is a pure value-level
/// contract this enum pins.
///
/// SwiftUI's `.sheet(item:)` modifier renders modal content visually,
/// but it does not by itself mark the presented view as an
/// `UIAccessibilityTraitIsModal` container. Without that trait,
/// VoiceOver swipe-rotor traversal and Voice Control number-overlay
/// continue to surface elements *behind* the sheet (the underlying
/// list / detail view), and Switch Control single-step scanners
/// silently walk through occluded content. To assistive technologies
/// the sheet then reads as a navigation push, not a modal — a WCAG 2.2
/// SC 4.1.2 (Name, Role, Value) and Apple HIG → Accessibility →
/// *Modality* defect: the role conveyed visually (modal sheet) must
/// match the role exposed programmatically.
///
/// Today's `.sheet(item:)` surfaces are:
/// 1. **Portfolio create/edit editor** — presented from
///    ``PortfolioListView`` over the portfolio inventory column.
/// 2. **Holdings editor** — presented from ``PortfolioDetailView`` over
///    the per-portfolio detail surface.
///
/// Both adopt ``sheetContentTraits`` on the sheet's root content. The
/// trait set is a single value pinned here so a future sheet cannot
/// silently ship without it, and so an accidental rewrite that drops
/// `.isModal` (e.g., merging traits the wrong way) is caught by the
/// test suite before it reaches AT users.
enum SheetAccessibility {
  /// The accessibility trait set added to the root content of every
  /// `.sheet(item:)` presentation so VoiceOver, Voice Control, and
  /// Switch Control treat the sheet as a modal container and stop
  /// surfacing content behind it.
  ///
  /// ``AccessibilityTraits/isModal`` is the SwiftUI surface for the
  /// UIKit `UIAccessibilityTraitIsModal` trait. Apple's accessibility
  /// documentation states the trait "tells assistive technologies that
  /// the element is modal and should not allow them to interact with
  /// the views underneath it." `.sheet(item:)` does not infer this
  /// trait automatically — view-modal presentations must opt in
  /// explicitly on the sheet's content root.
  static var sheetContentTraits: AccessibilityTraits { .isModal }
}
