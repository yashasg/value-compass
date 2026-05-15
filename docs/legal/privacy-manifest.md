# Privacy manifest — `X-Device-UUID` identifier flow

This document explains the single
`NSPrivacyCollectedDataTypeDeviceID` entry under
`NSPrivacyCollectedDataTypes` in
`app/Sources/App/PrivacyInfo.xcprivacy`, and how the engineering
declaration must be mirrored on the App Store Connect "App Privacy"
nutrition label at submission time.

> ⚠️ **Not legal advice.** This is an engineering record of the
> identifier surface that exists in the codebase today. Final wording
> on the App Store Connect nutrition label and the Privacy Policy
> (#224) should be confirmed by qualified counsel before submission.

## What the manifest declares

`PrivacyInfo.xcprivacy` lists exactly one collected data type:

| Field | Value |
|---|---|
| `NSPrivacyCollectedDataType` | `NSPrivacyCollectedDataTypeDeviceID` |
| `NSPrivacyCollectedDataTypeLinked` | `true` |
| `NSPrivacyCollectedDataTypeTracking` | `false` |
| `NSPrivacyCollectedDataTypePurposes` | `[NSPrivacyCollectedDataTypePurposeAppFunctionality]` |

The mapping between manifest field and the App Store Connect nutrition
label is:

| Manifest field | App Store Connect label section |
|---|---|
| `NSPrivacyCollectedDataTypeDeviceID` | *Identifiers → Device ID* |
| `NSPrivacyCollectedDataTypeLinked = true` | *Linked to the user* |
| `NSPrivacyCollectedDataTypeTracking = false` | *Not used to track you* |
| `NSPrivacyCollectedDataTypePurposeAppFunctionality` | *App Functionality* |

The Connect form must match the manifest exactly; mismatch is a
common §5.1.2 rejection cause.

## Where the identifier comes from

- `app/Sources/Backend/Networking/DeviceIDProvider.swift` lazily
  generates a `UUID().uuidString` on first use, persists it in the
  Keychain under `com.valuecompass.deviceUUID`, and returns the same
  value on every subsequent call. The identifier survives reinstall
  (within Apple's keychain accessibility constraints) and is never
  rotated client-side.
- `app/Sources/Backend/Networking/APIClient.swift` calls
  `makeOutgoingRequest(...)` which sets the
  `X-Device-UUID` request header on **every** outbound backend call
  via `URLSession`.
- `app/Sources/App/Dependencies/APIClientDependency.swift` wires
  `APIClient.shared.send(_:)` into `@Dependency(\.apiClient)`. Any
  reducer that resolves this dependency transmits the identifier
  automatically.

The backend (`backend/api/main.py`) accepts `device_uuid: UUID`
and joins it onto `Portfolio` rows, which is what makes the manifest
entry **linked** rather than unlinked.

## Why these flag values are correct

- **Linked = `true`:** the backend persists rows keyed by the UUID, so
  on the server side the identifier is associated with user-generated
  content (portfolios, contribution history). Apple's definition of
  "linked" applies regardless of whether a human-readable user account
  exists — server-side association by an installation-stable
  identifier is sufficient.
- **Tracking = `false`:** the identifier is never combined with data
  from other apps or websites, never shared with data brokers, and
  never used to target advertising. It is purely an installation
  identifier for the value-compass backend.
- **Purpose = `AppFunctionality`:** the backend uses the identifier
  solely to scope a user's portfolios and to authorize subsequent
  requests against those portfolios. There is no analytics, product
  personalization, or third-party advertising flow today.

If a future change broadens any of these (for example, if the
identifier ever flows to a third-party SDK, or if it ever drives
analytics/advertising surfaces), the manifest **and** the Connect
nutrition label must be updated together, and a Privacy Policy update
(#224) must accompany the change.

## Out of scope

- **Privacy Policy text and Settings link** (`#224`) — the human-readable
  version of the same disclosure.
- **App Review submission notes** (`#254`) — financial-tool framing.
- **`NSPrivacyAccessedAPITypes` (required-reason API)** — already
  shipped in commit `69af031` (PR #230 / closes #223) covering the
  one `UserDefaults` use site. No additional required-reason APIs
  are present in `app/Sources` as of the audit recorded in #271.

## How to update this declaration

If the identifier surface changes:

1. Edit `app/Sources/App/PrivacyInfo.xcprivacy` to add, remove, or
   reflag the relevant `NSPrivacyCollectedDataType` entry.
2. Update this file with the new identifier, why it is collected, and
   the linked/tracking/purpose flags chosen.
3. Re-file the App Store Connect "App Privacy" nutrition label with
   the same flags **before** the next submission.
4. Coordinate with #224 so the Privacy Policy text mirrors the new
   declaration.

## References

- Apple — *Describing data use in privacy manifests*:
  <https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_data_use_in_privacy_manifests>
- Apple — *App privacy details on the App Store*:
  <https://developer.apple.com/app-store/app-privacy-details/>
- App Store Review Guideline §5.1.2 — *Data Use and Sharing*:
  <https://developer.apple.com/app-store/review/guidelines/#5.1.2>
