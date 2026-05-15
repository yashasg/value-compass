import Foundation

/// Outcome of validating a candidate Massive API key. Failure cases carry
/// human-readable reasons but never echo the key itself.
enum MassiveAPIKeyValidationOutcome: Equatable, Sendable {
  /// Massive accepted the key (HTTP 2xx).
  case valid
  /// Massive explicitly rejected the key (HTTP 401/403).
  case invalid(reason: String)
  /// Massive returned a non-auth error (other 4xx/5xx).
  case serverError(status: Int)
  /// The validation request failed before reaching Massive (network down,
  /// DNS failure, timeout, malformed response, etc.).
  case networkUnavailable(reason: String)

  var isValid: Bool {
    if case .valid = self { return true }
    return false
  }
}

/// Validates a Massive API key by exercising it against the Massive API.
///
/// The protocol is intentionally narrow so the SettingsFeature reducer can
/// inject a fake (`MassiveAPIKeyValidatorClient.testValue`) and the live
/// implementation can swap transports without touching the call sites.
protocol MassiveAPIKeyValidating: Sendable {
  func validate(key: String) async -> MassiveAPIKeyValidationOutcome
}

/// `URLSession`-backed Massive API key validator.
///
/// Sends an authenticated GET to `baseURL + probePath` with the candidate
/// key in the `Authorization: Bearer …` header. The probe deliberately
/// targets a lightweight endpoint (`/v1/account` by default) so we don't
/// pull large payloads just to confirm the key is accepted. Any 2xx is
/// treated as `valid`; 401/403 as `invalid`; other 4xx/5xx as `serverError`;
/// transport / decoding failures as `networkUnavailable`.
struct URLSessionMassiveAPIKeyValidator: MassiveAPIKeyValidating {
  static let defaultBaseURL = URL(string: "https://api.massive.com")!
  static let defaultProbePath = "/v1/account"
  static let defaultTimeoutSeconds: TimeInterval = 15

  let session: URLSession
  let baseURL: URL
  let probePath: String
  let timeoutSeconds: TimeInterval

  init(
    session: URLSession = .shared,
    baseURL: URL = Self.defaultBaseURL,
    probePath: String = Self.defaultProbePath,
    timeoutSeconds: TimeInterval = Self.defaultTimeoutSeconds
  ) {
    self.session = session
    self.baseURL = baseURL
    self.probePath = probePath
    self.timeoutSeconds = timeoutSeconds
  }

  func validate(key: String) async -> MassiveAPIKeyValidationOutcome {
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return .invalid(reason: "API key cannot be empty.")
    }

    var request = URLRequest(url: baseURL.appendingPathComponent(probePath))
    request.httpMethod = "GET"
    request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = timeoutSeconds

    do {
      let (_, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse else {
        return .networkUnavailable(
          reason: "Massive validation endpoint returned a non-HTTP response.")
      }
      switch http.statusCode {
      case 200..<300:
        return .valid
      case 401, 403:
        return .invalid(reason: "Massive rejected the API key.")
      default:
        return .serverError(status: http.statusCode)
      }
    } catch let error as URLError {
      return .networkUnavailable(reason: error.localizedDescription)
    } catch {
      return .networkUnavailable(reason: error.localizedDescription)
    }
  }
}
