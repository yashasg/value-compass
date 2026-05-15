import ConcurrencyExtras
import XCTest

@testable import VCA

/// Tests for `KeychainMassiveAPIKeyStore` policy (issue #127).
///
/// These exercise the store's contract — trim on save, treat empty as
/// delete, surface keychain errors as `MassiveAPIKeyStoreError.underlying`,
/// no leaking of raw `OSStatus` values — by injecting in-memory closures in
/// place of the real Keychain. The simulator Keychain is unreachable from
/// XCTest bundles without a code-signed host-app entitlement
/// (`errSecMissingEntitlement`), so the live `KeychainStore` integration is
/// instead validated end-to-end via `RootViewSmokeTests` + manual run.
///
/// Fixtures use clearly-not-credentials placeholder strings.
final class MassiveAPIKeyStoreTests: XCTestCase {

  // MARK: - Helpers

  private struct FakeBackend {
    let store: LockIsolated<[String: String]>
    let load: @Sendable (String) throws -> String?
    let save: @Sendable (String, String) throws -> Void
    let remove: @Sendable (String) throws -> Void
  }

  private func makeFakeBackend(
    initial: [String: String] = [:],
    failOn op: BackendOp? = nil
  ) -> FakeBackend {
    let store = LockIsolated<[String: String]>(initial)
    return FakeBackend(
      store: store,
      load: { key in
        if op == .load { throw FakeBackendError.injected }
        return store.value[key]
      },
      save: { value, key in
        if op == .save { throw FakeBackendError.injected }
        store.withValue { $0[key] = value }
      },
      remove: { key in
        if op == .remove { throw FakeBackendError.injected }
        store.withValue { $0.removeValue(forKey: key) }
      }
    )
  }

  private enum BackendOp { case load, save, remove }
  private enum FakeBackendError: Error, CustomStringConvertible {
    case injected
    var description: String { "injected" }
  }

  // MARK: - Tests

  func testLoadKeyReturnsNilWhenNothingSaved() throws {
    let backend = makeFakeBackend()
    let store = KeychainMassiveAPIKeyStore(
      load: backend.load, save: backend.save, remove: backend.remove)
    XCTAssertNil(try store.loadKey())
  }

  func testLoadKeyTreatsEmptyStoredValueAsNil() throws {
    let backend = makeFakeBackend(initial: [
      KeychainMassiveAPIKeyStore.defaultKeychainAccount: ""
    ])
    let store = KeychainMassiveAPIKeyStore(
      load: backend.load, save: backend.save, remove: backend.remove)
    XCTAssertNil(try store.loadKey())
  }

  func testSaveAndLoadRoundTrip() throws {
    let backend = makeFakeBackend()
    let store = KeychainMassiveAPIKeyStore(
      load: backend.load, save: backend.save, remove: backend.remove)
    try store.saveKey("placeholder-massive-key-AAAA")
    XCTAssertEqual(try store.loadKey(), "placeholder-massive-key-AAAA")
    XCTAssertEqual(
      backend.store.value[KeychainMassiveAPIKeyStore.defaultKeychainAccount],
      "placeholder-massive-key-AAAA")
  }

  func testSaveTrimsSurroundingWhitespace() throws {
    let backend = makeFakeBackend()
    let store = KeychainMassiveAPIKeyStore(
      load: backend.load, save: backend.save, remove: backend.remove)
    try store.saveKey("   placeholder-massive-key-BBBB \n")
    XCTAssertEqual(try store.loadKey(), "placeholder-massive-key-BBBB")
  }

  func testSaveOverwritesPreviousKey() throws {
    let backend = makeFakeBackend()
    let store = KeychainMassiveAPIKeyStore(
      load: backend.load, save: backend.save, remove: backend.remove)
    try store.saveKey("placeholder-massive-key-CCCC")
    try store.saveKey("placeholder-massive-key-DDDD")
    XCTAssertEqual(try store.loadKey(), "placeholder-massive-key-DDDD")
  }

  func testSaveEmptyDeletesViaRemove() throws {
    let removedKeys = LockIsolated<[String]>([])
    let backend = makeFakeBackend(initial: [
      KeychainMassiveAPIKeyStore.defaultKeychainAccount: "placeholder-massive-key-EEEE"
    ])
    let store = KeychainMassiveAPIKeyStore(
      load: backend.load,
      save: backend.save,
      remove: { key in
        removedKeys.withValue { $0.append(key) }
        backend.store.withValue { $0.removeValue(forKey: key) }
      })
    try store.saveKey("   ")
    XCTAssertNil(try store.loadKey())
    XCTAssertEqual(removedKeys.value, [KeychainMassiveAPIKeyStore.defaultKeychainAccount])
  }

  func testDeleteRemovesPreviouslySavedKey() throws {
    let backend = makeFakeBackend()
    let store = KeychainMassiveAPIKeyStore(
      load: backend.load, save: backend.save, remove: backend.remove)
    try store.saveKey("placeholder-massive-key-FFFF")
    try store.deleteKey()
    XCTAssertNil(try store.loadKey())
    XCTAssertNil(backend.store.value[KeychainMassiveAPIKeyStore.defaultKeychainAccount])
  }

  func testLoadFailureWrapsUnderlyingError() {
    let backend = makeFakeBackend(failOn: .load)
    let store = KeychainMassiveAPIKeyStore(
      load: backend.load, save: backend.save, remove: backend.remove)
    XCTAssertThrowsError(try store.loadKey()) { error in
      guard case MassiveAPIKeyStoreError.underlying(let description) = error else {
        XCTFail("Expected MassiveAPIKeyStoreError.underlying, got \(error)")
        return
      }
      XCTAssertEqual(description, "injected")
    }
  }

  func testSaveFailureWrapsUnderlyingError() {
    let backend = makeFakeBackend(failOn: .save)
    let store = KeychainMassiveAPIKeyStore(
      load: backend.load, save: backend.save, remove: backend.remove)
    XCTAssertThrowsError(try store.saveKey("placeholder")) { error in
      guard case MassiveAPIKeyStoreError.underlying = error else {
        XCTFail("Expected MassiveAPIKeyStoreError.underlying, got \(error)")
        return
      }
    }
  }

  func testDeleteFailureWrapsUnderlyingError() {
    let backend = makeFakeBackend(failOn: .remove)
    let store = KeychainMassiveAPIKeyStore(
      load: backend.load, save: backend.save, remove: backend.remove)
    XCTAssertThrowsError(try store.deleteKey()) { error in
      guard case MassiveAPIKeyStoreError.underlying = error else {
        XCTFail("Expected MassiveAPIKeyStoreError.underlying, got \(error)")
        return
      }
    }
  }
}

/// Tests for `MassiveAPIKeyMask` rendering (issue #127).
final class MassiveAPIKeyMaskTests: XCTestCase {
  func testReturnsNilForEmptyOrWhitespaceInput() {
    XCTAssertNil(MassiveAPIKeyMask.mask(""))
    XCTAssertNil(MassiveAPIKeyMask.mask("   "))
  }

  func testReturnsAllBulletsForShortKeys() {
    XCTAssertEqual(MassiveAPIKeyMask.mask("a"), "\u{2022}\u{2022}\u{2022}\u{2022}")
    XCTAssertEqual(MassiveAPIKeyMask.mask("abcd"), "\u{2022}\u{2022}\u{2022}\u{2022}")
  }

  func testRevealsLastFourCharactersForLongerKeys() {
    XCTAssertEqual(
      MassiveAPIKeyMask.mask("placeholder-massive-key-WXYZ"),
      "\u{2022}\u{2022}\u{2022}\u{2022}WXYZ")
  }

  // MARK: accessibilityLabel(for:) — issue #243

  /// Empty / whitespace-only keys mirror `mask(_:)` and produce no label —
  /// SettingsView falls back to a generic "Saved API key" string, so the
  /// reducer must report `nil` when there is nothing to describe.
  func testAccessibilityLabelReturnsNilForEmptyOrWhitespaceInput() {
    XCTAssertNil(MassiveAPIKeyMask.accessibilityLabel(for: ""))
    XCTAssertNil(MassiveAPIKeyMask.accessibilityLabel(for: "   "))
  }

  /// Keys with `<= bulletCount` characters reveal no suffix in `mask(_:)`,
  /// so the spoken label avoids fabricating one and instead tells VoiceOver
  /// users that all characters are hidden.
  func testAccessibilityLabelHidesSuffixForShortKeys() {
    XCTAssertEqual(
      MassiveAPIKeyMask.accessibilityLabel(for: "a"),
      "Saved API key, last four characters hidden")
    XCTAssertEqual(
      MassiveAPIKeyMask.accessibilityLabel(for: "abcd"),
      "Saved API key, last four characters hidden")
  }

  /// Longer keys spell the trailing four characters with single spaces so
  /// VoiceOver pronounces each character individually instead of running
  /// digits/letters together as a single token.
  func testAccessibilityLabelSpellsLastFourCharactersForLongerKeys() {
    XCTAssertEqual(
      MassiveAPIKeyMask.accessibilityLabel(for: "placeholder-massive-key-WXYZ"),
      "Saved API key ending in W X Y Z")
    XCTAssertEqual(
      MassiveAPIKeyMask.accessibilityLabel(for: "abcdef1234"),
      "Saved API key ending in 1 2 3 4")
  }

  /// Surrounding whitespace must be trimmed before measuring length and
  /// extracting the suffix, mirroring `mask(_:)`'s own trimming behavior.
  func testAccessibilityLabelTrimsSurroundingWhitespace() {
    XCTAssertEqual(
      MassiveAPIKeyMask.accessibilityLabel(for: "  placeholder-key-WXYZ  "),
      "Saved API key ending in W X Y Z")
    XCTAssertEqual(
      MassiveAPIKeyMask.accessibilityLabel(for: "   abcd   "),
      "Saved API key, last four characters hidden")
  }
}
