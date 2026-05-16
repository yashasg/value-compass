import Foundation

/// Pure catalog for the spoken contract of every bare `ProgressView()` in
/// the app (#371). Same composer family as ``OnboardingAccessibility``
/// (#330), ``MainAccessibility`` (#343), and ``SettingsAccessibility``
/// (#473): the SwiftUI modifier surface (`.accessibilityLabel(_:)`,
/// `.accessibilityHidden(_:)`, `.accessibilityElement(children:)`) is a
/// view-tree decoration not introspectable without a UI host, but the
/// labels it consumes — "what does VoiceOver / Switch Control / Voice
/// Control hear when it lands on this spinner?" — are pure value-level
/// contracts this enum pins.
///
/// Two patterns are sanctioned, and ``ProgressViewAccessibility`` covers
/// both:
/// 1. **Labeled spinner** — a `ProgressView()` that is on screen alone
///    (no adjacent text) carries an explicit `.accessibilityLabel(_:)`
///    so assistive technologies announce *what* is loading instead of
///    the localized SwiftUI default ("In progress") with no context.
///    Today's only such surface is ``RootView``'s launching window
///    (`RootView.swift`), which renders before `AppFeature.task`
///    resolves the first destination — see ``launchingLabel``.
/// 2. **Decorative spinner** — a `ProgressView()` inside an
///    ``HStack`` paired with a `Text` row carries
///    `.accessibilityHidden(true)` and the parent ``HStack`` carries
///    `.accessibilityElement(children: .combine)` so VoiceOver reads
///    the row as a single AT element labeled by the adjacent text. The
///    spinner is decorative when paired with explanatory copy and must
///    not announce itself as a separate "in progress" element. Today's
///    such surfaces are the Massive API-key validating row and the
///    account-erasure erasing row in ``SettingsView`` — see
///    ``apiKeyValidatingDecorativeSpinnerIsHidden`` and
///    ``accountErasingDecorativeSpinnerIsHidden``.
///
/// WCAG 2.2 SC 1.1.1 (Non-text Content, Level A) and SC 4.1.2 (Name,
/// Role, Value) require every status indicator to have a
/// programmatically determinable text alternative. Apple HIG →
/// Accessibility → *Labels and descriptions* says: "Provide a brief,
/// useful label for every accessibility element." This catalog is the
/// single source of truth so the launching label can never drift from
/// `AppBrand.displayName`, and the "decorative spinner" convention
/// cannot be silently broken when a future surface adds a new spinner.
enum ProgressViewAccessibility {
  /// The `.accessibilityLabel(_:)` string for the bare full-screen
  /// `ProgressView()` rendered by ``RootView`` while
  /// `AppFeature.Destination` is `nil` (the brief launching window
  /// before the first `task` reduction completes).
  ///
  /// The launching surface is the **first thing a first-run VoiceOver
  /// user encounters**: hearing only the localized SwiftUI default
  /// ("In progress") with no app context is contextless if the
  /// launching window stretches (cold start, slow disk, debug build).
  /// The label is composed from ``AppBrand/displayName`` so the
  /// announcement tracks the brand string and cannot drift if the app
  /// is re-skinned. The trailing ", loading" is lowercase and
  /// comma-separated to match Apple's spoken-label convention for
  /// state ("Investrum, loading" reads as "Investrum [pause] loading"
  /// — verb-form state, not a sentence).
  static var launchingLabel: String {
    "\(AppBrand.displayName), loading"
  }

  /// Convention pin: the decorative-spinner pattern requires the
  /// spinner be marked `.accessibilityHidden(true)` so the combined
  /// parent element is labeled solely by the adjacent ``Text``.
  ///
  /// This is a value-level mirror of the modifier choice for the two
  /// decorative-spinner surfaces shipped today
  /// (``apiKeyValidatingRowAccessibilityIdentifier``,
  /// ``accountErasingRowAccessibilityIdentifier``). If a future
  /// surface flips this to `false` for one of those rows, the test
  /// suite catches the drift — the spinner would otherwise re-appear
  /// as a separate "in progress" AT element when the user swipes
  /// through the row.
  static let decorativeSpinnerIsAccessibilityHidden = true

  /// Accessibility identifier on the Massive API-key validating row in
  /// ``SettingsView`` (`Settings → Massive API Key`).
  ///
  /// Mirrors the existing `.accessibilityIdentifier(_:)` on the
  /// ``HStack`` so the UI-test layer and the spoken-contract layer
  /// reference the same string. The validating row is the
  /// decorative-spinner surface paired with the visible text
  /// "Validating with Massive…".
  static let apiKeyValidatingRowAccessibilityIdentifier =
    "settings.apiKey.request.validating"

  /// Accessibility identifier on the account-erasure erasing row in
  /// ``SettingsView`` (`Settings → Privacy & Data → Erase All My
  /// Data`).
  ///
  /// Mirrors the existing `.accessibilityIdentifier(_:)` on the
  /// ``HStack`` so the UI-test layer and the spoken-contract layer
  /// reference the same string. The erasing row is the
  /// decorative-spinner surface paired with the visible text
  /// "Erasing your data…".
  static let accountErasingRowAccessibilityIdentifier =
    "settings.erase.status.erasing"
}
