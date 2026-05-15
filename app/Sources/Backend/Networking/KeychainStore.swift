import Foundation
import Security

/// Thin wrapper around the iOS Keychain Services C API.
///
/// Used by `DeviceIDProvider` to persist the device UUID across app reinstalls
/// (Keychain entries survive uninstall when the access group / accessibility
/// settings allow it).
enum KeychainStore {
  enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
  }

  /// Stores `value` in the keychain under `key`. Overwrites any existing
  /// entry. The item is bound to this device only and is available after
  /// first unlock.
  static func set(_ value: String, for key: String) throws {
    let data = Data(value.utf8)

    let baseQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
    ]

    // Attempt to update first; if no item exists, fall through to add.
    let updateAttributes: [String: Any] = [kSecValueData as String: data]
    let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttributes as CFDictionary)

    switch updateStatus {
    case errSecSuccess:
      return
    case errSecItemNotFound:
      var addQuery = baseQuery
      addQuery[kSecValueData as String] = data
      addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        throw KeychainError.unexpectedStatus(addStatus)
      }
    default:
      throw KeychainError.unexpectedStatus(updateStatus)
    }
  }

  /// Removes any entry stored under `key`. Treats "no item present" as
  /// success so callers (full local reset, `MassiveAPIKeyClient.delete`) can
  /// invoke this idempotently without first checking for existence.
  static func remove(_ key: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
    ]
    let status = SecItemDelete(query as CFDictionary)
    switch status {
    case errSecSuccess, errSecItemNotFound:
      return
    default:
      throw KeychainError.unexpectedStatus(status)
    }
  }

  /// Returns the value previously stored under `key`, or `nil` if no entry
  /// exists. Throws on unexpected keychain errors.
  static func get(_ key: String) throws -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
        return nil
      }
      return value
    case errSecItemNotFound:
      return nil
    default:
      throw KeychainError.unexpectedStatus(status)
    }
  }
}
