# Privacy manifest — collected data declarations

This document explains every entry under `NSPrivacyCollectedDataTypes`
in `app/Sources/App/PrivacyInfo.xcprivacy`, and how each engineering
declaration must be mirrored on the App Store Connect "App Privacy"
nutrition label at submission time.

> ⚠️ **Not legal advice.** This is an engineering record of the data
> surface that exists in the codebase today. Final wording on the App
> Store Connect nutrition label and the Privacy Policy (#224) should be
> confirmed by qualified counsel before submission.

## What the manifest declares

`PrivacyInfo.xcprivacy` lists three collected data types, every one of
which is `Linked = true`, `Tracking = false`, and serves the
`AppFunctionality` purpose:

| `NSPrivacyCollectedDataType` | What flows through the network | App Store Connect label section |
|---|---|---|
| `NSPrivacyCollectedDataTypeDeviceID` | The `X-Device-UUID` header attached to every backend request (see *Where the identifier comes from* below). | *Identifiers → Device ID* |
| `NSPrivacyCollectedDataTypeOtherFinancialInfo` | `BackendPortfolioPayload.monthlyBudget` and every `BackendHoldingPayload.weight` transmitted by `BackendSyncProjection.makePayload(for:deviceUUID:)`. | *Financial Info → Other Financial Info* |
| `NSPrivacyCollectedDataTypeOtherUserContent` | `BackendPortfolioPayload.name` (the user-typed portfolio name) and the per-holding `BackendHoldingPayload.ticker` string. | *User Content → Other User Content* |

The mapping between manifest field and the App Store Connect nutrition
label for every entry is:

| Manifest field | App Store Connect label section |
|---|---|
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

## Where the financial info and user content come from

- `app/Sources/Backend/Networking/BackendSyncProjection.swift:8–15`
  defines `BackendPortfolioPayload.{name, monthlyBudget, maWindow,
  createdAt}` and `BackendHoldingPayload.{ticker, weight}`. The
  `monthlyBudget` and per-holding `weight` decimals are user-supplied
  financial figures derived from the portfolio editor (#125).
- `BackendSyncProjection.makePayload(for:deviceUUID:)` assembles those
  values from the live SwiftData `Portfolio` row before the projection
  hands the payload to `APIClient`.
- The payload then travels over TLS to `https://api.valuecompass.app`
  alongside the `X-Device-UUID` header, which is why both new entries
  carry `NSPrivacyCollectedDataTypeLinked = true` — the backend joins
  every payload row to the per-installation identifier.

## Why these flag values are correct

- **Linked = `true`** (all three entries): the backend persists rows
  keyed by the `X-Device-UUID`, so on the server side the device
  identifier, the portfolio name, the monthly budget, and the holding
  weights are all associated with one installation's user-generated
  content. Apple's definition of "linked" applies regardless of whether
  a human-readable user account exists — server-side association by an
  installation-stable identifier is sufficient.
- **Tracking = `false`** (all three entries): none of the collected
  values are combined with data from other apps or websites, shared
  with data brokers, or used to target advertising. The data flows
  only to the value-compass backend.
- **Purpose = `AppFunctionality`** (all three entries): the backend
  uses the identifier to scope a user's portfolios and to authorize
  subsequent requests, and uses the portfolio name / monthly budget /
  ticker weights solely to compute the value-compass contribution
  recommendation that is the app's core function. There is no
  analytics, product personalization, or third-party advertising flow.

If a future change broadens any of these (for example, if the
identifier ever flows to a third-party SDK, or if it ever drives
analytics/advertising surfaces), the manifest **and** the Connect
nutrition label must be updated together, and a Privacy Policy update
(#224) must accompany the change.

## Out of scope

- **Privacy Policy text and Settings link** (`#224`) — the human-readable
  version of the same disclosure. Must cover transmission of the
  portfolio name, monthly budget, and ticker allocations per #357.
- **Third-party services the app surfaces at the point of user
  consent** — every external service the app exercises, the published
  ToS/Privacy URLs surfaced in-app at the consent surface, and the
  re-verification trigger, are registered in
  [`docs/legal/third-party-services.md`](third-party-services.md) per
  App Store Review Guideline §5.2.3 and GDPR Art. 13(1)(e) (issue
  #294). This manifest declares **collection**; the third-party
  register declares **disclosure of recipients**.
- **App Review submission notes** (`#254`) — financial-tool framing.
- **`NSPrivacyAccessedAPITypes` (required-reason API)** — already
  shipped in commit `69af031` (PR #230 / closes #223) covering the
  one `UserDefaults` use site. No additional required-reason APIs
  are present in `app/Sources` as of the audit recorded in #271.
- **Sub-processor DPAs and international-transfer mechanisms** — every
  third party in the request path (Cloudflare, Supabase, the VM host,
  APNs) is registered, with its GDPR Art. 28 DPA reference and Art. 46
  transfer mechanism, in
  [`docs/legal/data-processing-agreements.md`](data-processing-agreements.md)
  and [`docs/legal/processor-register.csv`](processor-register.csv).
  This manifest only describes the **app-side** declaration; the
  processor-side accountability gate is enforced via the TestFlight
  readiness checklist (#391).
- **Per-data-category retention windows** — `PrivacyInfo.xcprivacy`
  does not carry a retention-period field, but the App Store Connect
  *App Privacy → Data Retention* answer set for every entry above must
  be filed verbatim from [`docs/legal/data-retention.md`](data-retention.md).
  That document is also the source of truth for the
  `portfolios.last_seen_at` purge schedule, the journald retention
  floor, and the Cloudflare access-log posture that GDPR Art. 5(1)(e)
  and CCPA §1798.100(a)(3) require us to publish to data subjects.

## How to update this declaration

If the collected data surface changes:

1. Edit `app/Sources/App/PrivacyInfo.xcprivacy` to add, remove, or
   reflag the relevant `NSPrivacyCollectedDataType` entry.
2. Update this file with the new entry, what flows through the
   network, and the linked/tracking/purpose flags chosen.
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
