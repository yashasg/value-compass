import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// Routes WCAG 2.2 SC 4.1.3 "Status Messages" announcements (validation
/// errors, calculation outcomes, retry feedback) through a single seam so
/// every status surface stays consistent and tests can capture every
/// announcement without spinning up a UI host.
///
/// Use this through `View.appAnnounceOnChange(of:message:)` /
/// `View.appAnnounceOnSettledChange(of:debounce:message:)` rather than
/// posting `UIAccessibility` notifications directly so future code paths
/// inherit the same conventions (#293, #352).
struct AccessibilityAnnouncer: Sendable {
  /// Posts `message` as a non-focus-moving assistive-technology
  /// announcement. Closures conform to `@MainActor` because
  /// `UIAccessibility.post(notification:argument:)` must be called on the
  /// main thread; the SwiftUI `onChange` callbacks that drive the helper
  /// modifiers already run there.
  var announce: @MainActor (String) -> Void
}

extension AccessibilityAnnouncer {
  /// Production announcer that routes through `UIAccessibility.post`.
  static let live = AccessibilityAnnouncer(
    announce: { message in
      #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
      #endif
    }
  )

  /// No-op announcer suitable for previews and snapshot tests where
  /// announcements are not observable.
  static let noop = AccessibilityAnnouncer(announce: { _ in })
}

private struct AccessibilityAnnouncerKey: EnvironmentKey {
  static let defaultValue: AccessibilityAnnouncer = .live
}

extension EnvironmentValues {
  /// Override-point for tests that want to capture announcements posted
  /// via `View.appAnnounceOnChange` / `View.appAnnounceOnSettledChange`.
  var accessibilityAnnouncer: AccessibilityAnnouncer {
    get { self[AccessibilityAnnouncerKey.self] }
    set { self[AccessibilityAnnouncerKey.self] = newValue }
  }
}

extension View {
  /// Posts a VoiceOver/AT announcement whenever `value` changes to a state
  /// that produces a non-empty `message`. Use for status surfaces where a
  /// SwiftUI insertion/replacement is otherwise silent (inline validation
  /// errors, calculation success/failure, retry feedback) so AT users get
  /// the same feedback sighted users get from the new inline text without
  /// VoiceOver focus being yanked off their current task.
  ///
  /// `message` is invoked for every change; return `nil` (or an empty
  /// string) to skip the announcement for that transition — e.g. when the
  /// error is being cleared and silence is preferable to chatter.
  ///
  /// Aligned with WCAG 2.2 SC 4.1.3 (Status Messages) and Apple HIG →
  /// Accessibility → Notifications and announcements (#293, #352).
  func appAnnounceOnChange<Value: Equatable>(
    of value: Value,
    message: @escaping (Value) -> String?
  ) -> some View {
    modifier(AppAnnounceOnChangeModifier(value: value, message: message))
  }

  /// Same as `appAnnounceOnChange(of:message:)` but coalesces rapid changes
  /// behind a trailing debounce window so per-keystroke state churn (e.g.
  /// weight-validation flipping every digit in `HoldingsEditorView`) does
  /// not stack VoiceOver announcements. The most recent `value` wins; only
  /// the post-`debounce`-of-quiet value is announced.
  func appAnnounceOnSettledChange<Value: Equatable>(
    of value: Value,
    debounce: Duration = .milliseconds(500),
    message: @escaping (Value) -> String?
  ) -> some View {
    modifier(
      AppAnnounceOnSettledChangeModifier(
        value: value, debounce: debounce, message: message
      )
    )
  }
}

private struct AppAnnounceOnChangeModifier<Value: Equatable>: ViewModifier {
  let value: Value
  let message: (Value) -> String?
  @Environment(\.accessibilityAnnouncer) private var announcer

  func body(content: Content) -> some View {
    content.onChange(of: value) { _, newValue in
      guard let text = message(newValue), !text.isEmpty else { return }
      announcer.announce(text)
    }
  }
}

private struct AppAnnounceOnSettledChangeModifier<Value: Equatable>: ViewModifier {
  let value: Value
  let debounce: Duration
  let message: (Value) -> String?
  @Environment(\.accessibilityAnnouncer) private var announcer
  @State private var pending: Task<Void, Never>?

  func body(content: Content) -> some View {
    content.onChange(of: value) { _, newValue in
      pending?.cancel()
      pending = Task { @MainActor in
        try? await Task.sleep(for: debounce)
        guard !Task.isCancelled else { return }
        guard let text = message(newValue), !text.isEmpty else { return }
        announcer.announce(text)
      }
    }
    .onDisappear { pending?.cancel() }
  }
}
