# Investrum — third-party services register

> ⚠️ **Engineering record, not legal advice.** This file enumerates every
> external service the Investrum iOS app exercises today, the URL it talks
> to, the published Terms of Service and Privacy Policy URLs we surface
> in-app at the point of user consent, and the trigger that requires the
> next re-verification. A qualified attorney must review this register
> before each App Store submission (issue #294 cites App Store Review
> Guideline §5.2.3, GDPR Art. 13(1)(e), and Cal. Civ. Code §1798.130(a)(5)).

## Purpose

Apple §5.2.3 and the GDPR/CCPA notice-at-collection obligations require
that the user is told, at the point a third-party data flow is initiated,
that the flow exists and is governed by the third party's terms. This
register is the source of truth that the in-app surface
(`app/Sources/Features/SettingsView.swift` — Massive API Key section
footer plus `Link` rows) and the public Privacy Policy
(`docs/legal/privacy-policy.md` §8) are both derived from.

If any field in the table below changes — a new service is added, a URL
is renamed, a deprecation is published, or the request shape changes —
the in-app surface and the Privacy Policy must be updated together,
counsel must re-review, and the TestFlight readiness checklist re-runs
the link-resolution step (`docs/testflight-readiness.md` §"Release
operation").

## Services in the request path today

### Massive (market-data API key validation)

| Field | Value | Source |
|---|---|---|
| Operator | Massive Industries Inc. (trading as Massive — `massive.com`) | `https://massive.com/` site footer |
| Role | Independent controller for the developer account / API key the user creates with Massive. Recipient of user-initiated requests authenticated by the user-supplied key. | App Store Review Guideline §5.2.3; GDPR Art. 4(7) and Art. 13(1)(e) |
| Service used | Account/key validation endpoint; future EOD market-data lookups (issue #128, deferred). | [`app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift`](../../app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift) |
| API host | `https://api.massive.com` | Base URL declared inside [`app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift`](../../app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift) (`validate(key:)` request construction) |
| Endpoints exercised | `POST /v1/account` (key validation; called on save and re-validate from Settings). | [`app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift`](../../app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift) |
| Data sent | The Massive API key the user enters, carried as `Authorization: Bearer <key>`. No portfolio, holdings, contribution history, device identifier, or telemetry is sent in this request path. | [`app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift`](../../app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift) |
| Data received | HTTP status only (the response body is consulted for validity but never surfaced to the UI, persisted, or logged). | [`app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift`](../../app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift) |
| At-rest storage of the key | iOS Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) — never `UserDefaults`, SwiftData, fixtures, logs, or analytics. | [`app/Sources/Backend/Networking/KeychainStore.swift`](../../app/Sources/Backend/Networking/KeychainStore.swift), [`app/Sources/Backend/Networking/MassiveAPIKeyStore.swift`](../../app/Sources/Backend/Networking/MassiveAPIKeyStore.swift) |
| Terms of Service URL surfaced in-app | <https://massive.com/legal/terms> | [`app/Sources/Backend/Models/Disclaimer.swift`](../../app/Sources/Backend/Models/Disclaimer.swift) — `LegalLinks.massiveTermsOfService` |
| Privacy Policy URL surfaced in-app | <https://massive.com/legal/privacy> | [`app/Sources/Backend/Models/Disclaimer.swift`](../../app/Sources/Backend/Models/Disclaimer.swift) — `LegalLinks.massivePrivacyPolicy` |
| User-consent surface | Settings → Massive API Key section. Section footer names Massive as the recipient before the user taps Save; the two `Link` rows hand the user off to Safari to read the published policy text before consent. | [`app/Sources/Features/SettingsView.swift`](../../app/Sources/Features/SettingsView.swift) — `apiKeySection` |
| App Store Connect "App Privacy" treatment | The Massive API key is **provided by the user, processed by Massive, and not collected by us**. No additional "Data Linked to You" / "Data Used to Track You" entry is required on Investrum's nutrition label for the Massive flow — we are not the controller for the key the user gives to Massive. | [`docs/legal/privacy-manifest.md`](privacy-manifest.md) — out-of-scope section |
| Re-verification trigger | (a) the API host (`api.massive.com`) is changed inside `MassiveAPIKeyValidator.swift`; (b) a new endpoint is added to `MassiveAPIKeyValidator.swift` or any other file under `app/Sources/Backend/Networking/Massive*.swift`; (c) the request shape (headers, body, or content type) changes; (d) Massive announces a ToS or Privacy Policy URL change; (e) any new Massive surface (e.g., the issue #128 EOD market-data refresh) lands. | This file |

## Out of scope (not third-party services for this register)

- **Apple platform services** (App Store, TestFlight, App Store Connect,
  StoreKit, MetricKit, APNs). Apple's role is the platform on which the
  app runs, not a third-party data recipient. The user's agreement with
  Apple governs these flows.
- **Swift Package Manager dependencies bundled in the app**. These are
  libraries that execute in-process; none make network requests on
  Investrum's behalf today. Attribution and licensing are tracked
  separately in [`THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md).
  Re-audit if any bundled dependency begins issuing network traffic.
- **Cloudflare / Supabase / VM host / journald** in front of the
  developer-owned backend (`api.valuecompass.app`, dormant in HEAD).
  These are sub-processors of the **developer**, not separate
  third-party services from the user's perspective. They are registered
  separately in [`data-processing-agreements.md`](data-processing-agreements.md)
  and [`processor-register.csv`](processor-register.csv) under the GDPR
  Art. 28 controller/processor framework, not under §5.2.3.

## How to update this register

1. Add, edit, or remove a row in the table above describing the service,
   API host, endpoints, request/response shape, at-rest storage,
   consent surface, and the published ToS/Privacy URLs.
2. Update `LegalLinks` in
   [`app/Sources/Backend/Models/Disclaimer.swift`](../../app/Sources/Backend/Models/Disclaimer.swift)
   to add a constant for each newly-surfaced policy URL; the
   compiler-verified `URL(string:)!` force-unwrap pins each URL
   exactly once across the app.
3. Add a `Link` row inside the consent surface (e.g., the relevant
   `Section` in `SettingsView.swift` or a future `OnboardingView`
   step). The accessibility identifier convention is
   `settings.<service>.<documentKind>.link`.
4. Update [`docs/legal/privacy-policy.md`](privacy-policy.md) §8 so the
   public-facing policy enumerates the new service and references this
   register.
5. Update the link-resolution step in
   [`docs/testflight-readiness.md`](../testflight-readiness.md) so the
   pre-submission checklist verifies the new URL resolves on a real
   device before the next external build is uploaded.
6. Counsel must review the new entry and the in-app surface text before
   the next App Store submission. Record the review (date, reviewer,
   approved version SHA) in the change log below.

## Change log

| Date | Change | Reviewer | Approved at SHA |
|---|---|---|---|
| 2026-05-15 | Initial register published; Massive added with `massive.com/legal/terms` and `massive.com/legal/privacy` URLs verified against the operator's site on this date. Surfaced in `SettingsView` Massive API Key section (issue #294). | Pending (Reuben — engineering record; licensed counsel pre-submission gate). | _to be set on submission_ |

## References

- App Store Review Guideline §5.2.3 — Intellectual Property, third-party
  content/services: <https://developer.apple.com/app-store/review/guidelines/#5.2.3>
- App Store Review Guideline §5.6 — Developer Code of Conduct:
  <https://developer.apple.com/app-store/review/guidelines/#5.6>
- GDPR Art. 13(1)(e) — recipients or categories of recipients:
  <https://gdpr-info.eu/art-13-gdpr/>
- Cal. Civ. Code §1798.130(a)(5) — notice at collection:
  <https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?sectionNum=1798.130>
- Massive — Terms of Service: <https://massive.com/legal/terms>
- Massive — Privacy Policy: <https://massive.com/legal/privacy>
