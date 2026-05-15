import ComposableArchitecture
import Foundation

/// `@DependencyClient` wrapper around `MassiveAPIKeyValidating` (issue #127).
///
/// Reducers call `@Dependency(\.massiveAPIKeyValidator)` to validate a
/// candidate Massive API key against Massive's API before persisting it
/// (initial save) or to re-confirm a saved key on demand (later refresh).
/// The macro-synthesized `testValue` makes any unstubbed call fail loudly so
/// reducer tests have to inject the outcome they want.
@DependencyClient
struct MassiveAPIKeyValidatorClient: Sendable {
  var validate: @Sendable (_ key: String) async -> MassiveAPIKeyValidationOutcome = { _ in
    .invalid(reason: "Validator not configured.")
  }
}

extension MassiveAPIKeyValidatorClient: DependencyKey {
  static let liveValue: MassiveAPIKeyValidatorClient = {
    let validator = URLSessionMassiveAPIKeyValidator()
    return MassiveAPIKeyValidatorClient(
      validate: { key in await validator.validate(key: key) }
    )
  }()

  static let previewValue: MassiveAPIKeyValidatorClient = .init(
    validate: { _ in .valid }
  )
}

extension DependencyValues {
  var massiveAPIKeyValidator: MassiveAPIKeyValidatorClient {
    get { self[MassiveAPIKeyValidatorClient.self] }
    set { self[MassiveAPIKeyValidatorClient.self] = newValue }
  }
}
