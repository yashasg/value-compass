import Foundation

/// Single source of truth for the legal disclaimer.
///
/// Surfaced on the onboarding flow (first launch) and in Settings,
/// as required by the frontend spec.
enum Disclaimer {
  static let text: String = """
    This tool is for informational and educational purposes only. It does not \
    constitute investment advice. Past price trends do not guarantee future \
    performance. Consult a licensed financial advisor before making investment \
    decisions.
    """
}
