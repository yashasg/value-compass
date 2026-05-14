import Foundation

/// Compares semantic version strings of the form `MAJOR.MINOR.PATCH`.
///
/// Missing components are treated as 0 (`"1.2"` == `"1.2.0"`). Non-numeric
/// components compare as 0; this is intentionally lenient so that a malformed
/// `X-Min-App-Version` server header never accidentally locks users out.
enum AppVersion {
  /// Returns `true` if `current` is strictly less than `minimum`.
  static func isBelowMinimum(current: String, minimum: String) -> Bool {
    compare(current, minimum) == .orderedAscending
  }

  static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
    let l = components(lhs)
    let r = components(rhs)
    let count = max(l.count, r.count)
    for i in 0..<count {
      let a = i < l.count ? l[i] : 0
      let b = i < r.count ? r[i] : 0
      if a < b { return .orderedAscending }
      if a > b { return .orderedDescending }
    }
    return .orderedSame
  }

  private static func components(_ version: String) -> [Int] {
    version.split(separator: ".").map { Int($0) ?? 0 }
  }
}
