# Investrum — Privacy Policy

> ⚠️ **Draft, not legal advice.** This document is the engineering record of
> what data Investrum currently collects, processes, and retains, written in
> the form of a public-facing Privacy Policy so the published copy can be
> derived from a single source of truth that tracks the code. The text below
> must be reviewed and signed off by qualified counsel before it is published
> to the App Privacy Policy URL or linked from the App Store listing
> (issue #224, acceptance criterion: "Have licensed counsel review the public
> policy text before launch").
>
> This file intentionally does **not** describe a Terms of Service or
> End-User License Agreement. The EULA posture (Apple Standard vs. Custom)
> is tracked separately in issue #398; nothing in this Privacy Policy creates
> contractual terms beyond Apple's standard agreement.

---

## Source of truth

| Field | Value | Source |
|---|---|---|
| Publisher / Controller | Apple Developer Team that submits the build to App Store Connect. | [`docs/testflight-readiness.md`](../testflight-readiness.md) |
| App name (user-visible) | **Investrum** | [`app/Sources/App/AppBrand.swift`](../../app/Sources/App/AppBrand.swift), [`app/Sources/App/Info.plist`](../../app/Sources/App/Info.plist) `CFBundleDisplayName` |
| Repository name (internal) | `value-compass` (engineering identifier; not user-facing) | This repository |
| Effective date | Date the published policy goes live; matches the version this file is at when counsel approves. | git history |

The published policy MUST use the user-visible name `Investrum`
throughout. Internal references to `Value Compass` exist only in this
repository's engineering history (closed issue #79) and are not
appropriate for the published text.

---

## 1. Summary (plain-English)

Investrum is a personal portfolio analysis tool. It runs on your iPhone or
iPad and helps you track your own existing holdings, set your own target
allocation, and compute how much new money to add per allocation to move
toward that target.

- We do **not** require an account.
- We do **not** sell, share, or rent your data.
- We do **not** embed third-party advertising SDKs, analytics SDKs, or
  trackers.
- Your portfolio, holdings, and contribution history stay on your device
  by default.
- One network flow leaves your device today: validating the optional
  Massive market-data API key that **you** provide in Settings. We send
  the key to Massive's servers exactly as you would if you used Massive
  directly; we do not retain or transmit that key to anyone else.
- We assign your install a stable per-device identifier
  (`X-Device-UUID`) the first time the app launches so we can identify
  your device on the (currently unwired) backend sync API without
  asking for an account. You can clear this identifier at any time by
  deleting the app or using the in-app reset flow (see §6).

What we collect, why, and how long is detailed in §2–§7.

> **One-sentence transparency statement** (per CCPA §1798.130(a)(5)(B)):
> Investrum does not "sell" or "share" personal information as those
> terms are defined under the California Consumer Privacy Act, and has
> not done so in the preceding 12 months.

---

## 2. What we collect, and why

This is the complete enumeration as of the current build. Adding a new
category requires updating this section, the App Privacy nutrition label
in App Store Connect, and `app/Sources/App/PrivacyInfo.xcprivacy`
([`docs/legal/privacy-manifest.md`](privacy-manifest.md)) before the
change ships.

### 2.1 On your device only (never transmitted off-device)

| Category | What it is | Why we keep it | Where it lives |
|---|---|---|---|
| Portfolio definitions | The portfolio name and target allocations you create. | Required for the app's core function — computing new-money contributions toward your targets. | SwiftData store on your device. |
| Holdings | Ticker, shares, cost basis (if you provide it), and any per-holding notes. | Required to compute the per-allocation contribution. | SwiftData store on your device. |
| Contribution history | Past calculation results you choose to save. | Lets you compare contributions month over month. | SwiftData store on your device. |
| Preferences | Theme, language, disclaimer-acknowledgment state. | Standard app settings. | `UserDefaults` on your device. |
| Massive API key (if you provide one) | The API key you enter under Settings → Massive API Key. | Required to call Massive on your behalf for market-data validation. | iOS Keychain on your device — never stored in `UserDefaults`, SwiftData, fixtures, logs, or analytics. |

### 2.2 Sent to Massive (third party — your direct relationship)

If — and only if — you enter a Massive API key in Settings, Investrum
calls `https://api.massive.com/v1/account` with that key in the
`Authorization` header to validate it
([`app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift`](../../app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift)).
The relationship between you and Massive is governed by Massive's own
Terms of Service and Privacy Policy; Investrum does not act as Massive's
agent, does not receive Massive's response payload beyond a
success/failure status, and does not relay your Massive key to any
other party. See §8 for the third-party-ToS surfacing requirement
tracked under issue #294.

### 2.3 Sent to the Investrum backend (when sync is enabled)

When backend sync is wired into the app (not yet active in v1; see
[`docs/legal/data-retention.md`](data-retention.md) and the closed
decision behind issue #271), each backend request includes:

| Header | What it is | Purpose | Legal basis |
|---|---|---|---|
| `X-Device-UUID` | A per-install UUIDv4 generated on first launch and persisted in your device's Keychain. | Identifies your install on the backend without requiring an account. | GDPR Art. 6(1)(b) — performance of the user-requested sync feature; CCPA "service-provider" relationship per §1798.140(j)–(v). |

The body of those requests carries the portfolio, holdings, and
contribution-history rows linked to that `X-Device-UUID`. See §7 for
how those rows are retained and erased.

### 2.4 Apple's standard build infrastructure (we do not see this)

Apple may collect crash diagnostics, App Store analytics, and other
device-level signals under your iOS privacy settings. Those flows are
governed by Apple's privacy policy; Investrum does not receive any
share-with-developer crash data unless you opt in via iOS Settings →
Privacy & Security → Analytics & Improvements → Share with App
Developers. Even if you opt in, the data Apple shares is aggregated and
de-identified per Apple's standard practice.

### 2.5 What we do **not** collect

For clarity (and matching the App Privacy "Data Not Collected"
declaration in [`docs/legal/privacy-manifest.md`](privacy-manifest.md)):

- We do not embed advertising SDKs and we do not request App Tracking
  Transparency permission.
- We do not embed third-party analytics SDKs (Firebase, Mixpanel,
  Amplitude, Segment, etc.).
- We do not collect contact details (email, phone, mailing address).
- We do not collect precise or coarse location.
- We do not access your photo library, contacts, calendar, health, or
  HomeKit data.
- We do not access your microphone or camera.
- We do not access your browsing history, search history, or
  cross-app activity.

---

## 3. Network endpoints we contact

| Endpoint | When | What we send | What we receive | Reference |
|---|---|---|---|---|
| `https://api.massive.com/v1/account` | When you save or re-validate a Massive API key in Settings. | Your Massive API key in the `Authorization` header. | HTTP status only (the body is parsed for validity but not surfaced). | `MassiveAPIKeyValidator.swift` |
| Investrum backend (host pinned at build time, see [`docs/services-tech-spec.md`](../services-tech-spec.md)) | When sync features are explicitly enabled by a future build. Not active in v1. | `X-Device-UUID`, request body with portfolios / holdings / contributions you have saved. | The persisted snapshot for your `X-Device-UUID`. | `APIClient.swift` |
| `https://apps.apple.com/search?term=Investrum` | If a forced-update prompt fires after a `min_app_version` signal. | Standard App Store search query. Opens in Safari / App Store. | App Store result page. | `ForcedUpdateFeature.swift` |

No other network endpoints are contacted by Investrum.

---

## 4. Identifiers

`X-Device-UUID` is the only persistent identifier Investrum generates.

- **What it is:** a randomly-generated UUIDv4
  ([`app/Sources/Backend/Networking/DeviceIDProvider.swift`](../../app/Sources/Backend/Networking/DeviceIDProvider.swift)),
  created on first launch and stored in the iOS Keychain so it survives
  app reinstalls until the Keychain is wiped.
- **What it identifies:** the install of Investrum on your device. It is
  not linked to your name, email, Apple ID, advertising identifier, or
  any other device-level identifier.
- **How to clear it:** see §6 (Your rights — Deletion).

Investrum does **not** read `identifierForVendor`,
`advertisingIdentifier` (IDFA), or any cross-app identifier. Investrum
does not request App Tracking Transparency authorization.

---

## 5. Disclosure of personal data

Investrum does not "sell" personal information (CCPA §1798.140(ad)),
does not "share" personal information for cross-context behavioral
advertising (CCPA §1798.140(ah)), and does not use personal information
to "target advertising" to you.

The only third-party processors that touch your data are:

| Processor | What they process | Purpose | Safeguard |
|---|---|---|---|
| Apple Inc. | Standard iOS APIs (Keychain, SwiftData, UserDefaults). | App execution. | Apple's standard developer agreement and privacy policy. |
| Massive Industries Inc. | The Massive API key you enter — only when you enter one. | Validating that key on your behalf. | Massive's own Terms of Service and Privacy Policy, which you accept by entering a Massive key. |
| Cloudflare, Inc. and PostgreSQL hosting provider (when backend sync is enabled) | `X-Device-UUID`-linked sync rows. | Routing and persisting your sync data. | DPA register and transfer-mechanism documentation in [`docs/legal/data-processing-agreements.md`](data-processing-agreements.md). |

We disclose personal data outside this list only when:

- you ask us to (e.g., a future data-export feature, issue #333);
- it is required by law (subpoena, court order, regulator request); or
- it is necessary to protect the rights, property, or safety of
  Investrum users, the public, or us.

---

## 6. Your rights

Investrum recognizes the following data-subject rights regardless of
where you live. Where a local law gives you stronger rights, those
apply.

### Right to be informed (GDPR Art. 13; CCPA §1798.100(a))

This Privacy Policy is the notice. We update it when the underlying
flows change (see §10).

### Right of access (GDPR Art. 15; CCPA §1798.110)

Every byte of personal data Investrum holds about you on your device is
already visible to you in the app — portfolios, holdings, contribution
history, preferences. The optional Massive API key is shown masked
(suffix only) for security; the raw key is never displayed by Investrum
after it is saved. When backend sync is active, the `GET /portfolio/export`
endpoint returns every `X-Device-UUID`-linked row the backend holds
about you in a structured, machine-readable JSON document (see
[Right to data portability](#right-to-data-portability-gdpr-art-20-ccpa-1798130a3)
below for the technical contract and verification protocol).

### Right to rectification / correction (GDPR Art. 16; CCPA §1798.106 / CPRA)

You can edit any portfolio, holding, target, or preference at any time
in the app. When backend sync is active, the same corrections propagate
to the server via:

- `PATCH /portfolio` — corrects the scalar portfolio fields (display
  name, monthly budget, moving-average window).
- `PATCH /portfolio/holdings/{ticker}` — corrects a holding's weight.
- `DELETE /portfolio/holdings/{ticker}` followed by
  `POST /portfolio/holdings` — corrects a holding whose ticker symbol
  itself is wrong, because the ticker is part of the row's natural key
  and cannot be PATCHed in place.

All three paths are authenticated by App Attest and scoped strictly to
the calling device's portfolio. The technical contract is documented in
the OpenAPI artifact at
[`app/Sources/Backend/Networking/openapi.json`](../../app/Sources/Backend/Networking/openapi.json)
under the `PatchPortfolioRequest`, `PatchPortfolioResponse`,
`PatchHoldingRequest`, and `PatchHoldingResponse` schemas, and the
consolidated DSR posture lives in
[`docs/legal/data-subject-rights.md`](data-subject-rights.md).

### Right to erasure / deletion (GDPR Art. 17; CCPA §1798.105)

You can erase every Investrum-controlled record tied to your device by
opening **Settings → Privacy & Data → Erase All My Data** and
confirming the destructive prompt. In a single action this:

1. Calls the backend `DELETE /portfolio` endpoint, which removes every
   `X-Device-UUID`-linked row the backend holds about you (the
   `Portfolio` row itself and, via the cascade in
   `PortfolioCascadeDeleter`, every `Holding`, `InvestSnapshot`, and
   `AppSettings` row keyed to it).
2. Wipes the on-device SwiftData store of the same record types.
3. Removes the saved Massive API key from the iOS Keychain.
4. Rotates the Keychain `X-Device-UUID` so future requests cannot be
   linked back to the erased records.
5. Resets the onboarding gate and returns Investrum to the disclaimer
   screen in the same session, exactly like a fresh install — you do
   not need to quit and relaunch the app.

The cache-only `StockCache` rows on the backend and the
`MarketDataBar` / `TickerMetadata` cache rows on the device are
intentionally not touched — ticker market data is shared across
devices and is not personal data of the caller. The endpoint is
authenticated by App Attest, scoped strictly to the calling device's
portfolio, and returns `204 No Content` on success; the contract is
documented in the OpenAPI artifact at
[`app/Sources/Backend/Networking/openapi.json`](../../app/Sources/Backend/Networking/openapi.json)
under the `DELETE /portfolio` operation.

Deleting the app from your device remains a complete-erasure fallback:
SwiftData, UserDefaults, and the Keychain partition scoped to the app
bundle ID are all removed by iOS. The consolidated DSR posture lives
in [`docs/legal/data-subject-rights.md`](data-subject-rights.md).

### Right to restrict processing (GDPR Art. 18) and to object (GDPR Art. 21)

You can revoke the only off-device flow currently wired (Massive API
key validation) at any time by removing the key in Settings. There is
no automated decision-making under GDPR Art. 22 — Investrum's
calculations are deterministic, run on your device, and produce
suggestions you choose to act on.

### Right to data portability (GDPR Art. 20; CCPA §1798.130(a)(3))

When backend sync is active, `GET /portfolio/export` returns every
`X-Device-UUID`-linked row the backend holds (portfolio name, monthly
budget, moving-average window, every holding with ticker and weight,
plus the timestamps that govern retention) as a structured,
machine-readable JSON document. The format is documented in the
OpenAPI contract at
[`app/Sources/Backend/Networking/openapi.json`](../../app/Sources/Backend/Networking/openapi.json)
under the `PortfolioExportResponse` schema; the response carries a
`format_version` field so future additions are auditable. The endpoint
is authenticated by App Attest and scoped strictly to the calling
device's portfolio.

While sync is unwired, your data lives on your device and is portable
by Apple's standard backup mechanisms (iCloud Backup, encrypted iTunes
backup).

### How to exercise these rights

Contact us at the email address published with the App Store listing
(per Apple's App Store Connect requirements). We respond within the
statutory window (30 days under GDPR Art. 12(3); 45 days under CCPA
§1798.130(a)(2), extendable per §1798.145(g)). To verify a request, we
ask only for the `X-Device-UUID` displayed under Settings → About →
Device ID — we do not request government identification.

You have the right to lodge a complaint with your data protection
authority. EU/EEA users may contact the supervisory authority in their
member state. UK users may contact the Information Commissioner's
Office (ICO). California users may contact the California Privacy
Protection Agency (CPPA).

---

## 7. Retention

Investrum keeps personal data only as long as needed for the purpose it
was collected and for any backup or audit window required by law.

| Category | Where it lives | Retention |
|---|---|---|
| Local SwiftData rows (portfolios, holdings, contributions) | Your device | Until you delete them or uninstall the app. |
| `UserDefaults` preferences | Your device | Until you delete them or uninstall the app. |
| Massive API key | Your device's Keychain | Until you remove it in Settings or uninstall the app. |
| `X-Device-UUID` | Your device's Keychain | Until you uninstall the app. |
| Backend rows joined to `X-Device-UUID` (when sync is active) | Processor (see §5) | See [`docs/legal/data-retention.md`](data-retention.md). |
| Application logs at the backend (when sync is active) | Processor | See [`docs/legal/data-retention.md`](data-retention.md). |

The retention schedule in [`docs/legal/data-retention.md`](data-retention.md)
is part of this Privacy Policy by reference. Updating the schedule
requires updating this section.

---

## 8. Third-party services

Investrum integrates with one third-party service today: **Massive**,
which provides market-data API access. The relationship is
user-initiated — you enter your own Massive API key — and your use of
Massive is governed by Massive's own Terms of Service and Privacy
Policy. Investrum surfaces those links at the API-key-entry point in
Settings (issue #294). We are not party to your agreement with Massive
and we do not act on Massive's behalf.

The Swift Package Manager dependencies bundled in the app are listed in
[`THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md). None of those
dependencies execute network requests on Investrum's behalf.

---

## 9. Children's privacy

Investrum is not directed at children under 13 (under 16 in some
jurisdictions) and does not knowingly collect personal information from
children. If you believe a child has provided personal information to
Investrum, contact us using the email address in the App Store listing
and we will delete the relevant data.

The App Store age rating reflects the financial-information content
classification rather than child-directed design.

---

## 10. Changes to this Privacy Policy

We update this Privacy Policy when the underlying data flows change.
Material changes (a new third-party processor, a new identifier, a new
data category, a change in retention duration) require a new effective
date and re-publication of the policy URL. The change history of this
document lives in the public repository history at
`docs/legal/privacy-policy.md`.

Engineering-side, any change to
[`app/Sources/Backend/Networking/APIClient.swift`](../../app/Sources/Backend/Networking/APIClient.swift),
[`app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift`](../../app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift),
[`app/Sources/App/PrivacyInfo.xcprivacy`](../../app/Sources/App/PrivacyInfo.xcprivacy),
or any new networking client triggers the re-validation hook in
[`loop-strategy.md`](../../loop-strategy.md) so this policy is reviewed
before the change ships.

---

## 11. Contact

For privacy questions or to exercise the rights listed in §6, contact
the publisher at the email address published under Investrum's App
Store listing → Developer → App Support / Privacy Policy.

For App Store policy questions about Investrum, contact Apple Inc. at
the address in the standard Apple developer agreement.

---

## Appendix A — Plain-language App Privacy nutrition label mapping

This appendix is informational. The authoritative mapping that ships in
App Store Connect lives in
[`docs/legal/privacy-manifest.md`](privacy-manifest.md) and
[`app/Sources/App/PrivacyInfo.xcprivacy`](../../app/Sources/App/PrivacyInfo.xcprivacy).

| App Store Connect category | Investrum's posture | Source |
|---|---|---|
| Data Used to Track You | None | No advertising or tracking SDK present. |
| Data Linked to You | `Device ID` (the `X-Device-UUID`), `Other Financial Info`, `Other User Content` — all for App Functionality only. | `PrivacyInfo.xcprivacy` |
| Data Not Linked to You | None declared. | No de-identified analytics collected. |

---

## Appendix B — Re-validation hooks

The following code surfaces must be re-checked any time a change to this
policy ships, and vice-versa:

- [`app/Sources/Backend/Networking/APIClient.swift`](../../app/Sources/Backend/Networking/APIClient.swift)
  (`X-Device-UUID` header)
- [`app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift`](../../app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift)
  (Massive endpoint and request shape)
- [`app/Sources/Backend/Networking/DeviceIDProvider.swift`](../../app/Sources/Backend/Networking/DeviceIDProvider.swift)
  (UUID generation and Keychain access group)
- [`app/Sources/App/PrivacyInfo.xcprivacy`](../../app/Sources/App/PrivacyInfo.xcprivacy)
  (privacy manifest declarations)
- [`app/Sources/App/AppFeature/SettingsFeature.swift`](../../app/Sources/App/AppFeature/SettingsFeature.swift)
  (key-entry and re-validation flows)

---

> **Final reminder:** This file is not a published policy until counsel
> signs off and the publisher hosts it at the App Privacy Policy URL
> declared in App Store Connect. Until that happens, the in-app link
> from Settings → Legal → Privacy Policy points to the canonical source
> of truth in this repository, which is what an App Review reviewer
> and a privacy regulator can verify against the code.
