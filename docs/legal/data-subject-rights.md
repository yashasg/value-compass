# Data subject rights — engineering reference

This document is the engineering record of how Investrum honors the
**data-subject rights** carried by every regulatory regime that attaches
to an `X-Device-UUID`-linked record on the value-compass backend. It is
the single source the public Privacy Policy
([`docs/legal/privacy-policy.md`](privacy-policy.md) §6) and the
TestFlight readiness checklist
([`docs/testflight-readiness.md`](../testflight-readiness.md)) consume
to answer "which code path delivers which right?".

> ⚠️ **Not legal advice.** The summaries below describe the **endpoints
> that exist in the code today** and the regulator clauses they map to.
> Final notice text, statutory deadlines, and any identity-verification
> protocol required for a `mailto:`-style fallback channel must be
> reviewed by qualified counsel before the matching Privacy Policy copy
> ships. See the "Open questions for counsel" section at the end.

## Why this file exists

The iOS app declares `X-Device-UUID` as a **linked, collected device
identifier** in `app/Sources/App/PrivacyInfo.xcprivacy` (closed #271).
The backend then joins user-content rows (`Portfolio`, `Holding`) to
that identifier in `backend/db/models.py`. As soon as the backend
network surface lights up (#128), every identifier-linked row carries
the data-subject-rights tripod:

1. **Right of access / portability** (GDPR Art. 15 / Art. 20; CCPA
   §1798.100 / §1798.130(a)(3)) — what the controller holds about the
   subject, in a structured machine-readable form.
2. **Right of rectification** (GDPR Art. 16; CCPA §1798.106) — correct
   inaccurate personal data.
3. **Right of erasure** (GDPR Art. 17; CCPA §1798.105) — delete
   identifier-linked personal data.

Each of those rights MUST map to a verifiable code path before App
Store submission, or the published Privacy Policy makes a claim the
implementation does not honor. This file is the map.

## Endpoint ⇄ right map

| Right | Regulator clauses | Endpoint(s) | Issue | Status |
|---|---|---|---|---|
| Access / Portability | GDPR Art. 15, Art. 20; CCPA §1798.100, §1798.110, §1798.130(a)(3) | `GET /portfolio/export` | [#333](https://github.com/yashasg/value-compass/issues/333) | Shipped (PR #436) |
| Rectification — scalar fields | GDPR Art. 16; CCPA §1798.106 | `PATCH /portfolio` | [#374](https://github.com/yashasg/value-compass/issues/374) | Shipped (PR #446) |
| Rectification — holding weight | GDPR Art. 16; CCPA §1798.106 | `PATCH /portfolio/holdings/{ticker}` | [#374](https://github.com/yashasg/value-compass/issues/374) | Shipped (PR #446) |
| Rectification — ticker typo | GDPR Art. 16; CCPA §1798.106 | `DELETE /portfolio/holdings/{ticker}` + `POST /portfolio/holdings` | [#374](https://github.com/yashasg/value-compass/issues/374) | Shipped (PR #446) |
| Erasure (row-scoped) | GDPR Art. 17; CCPA §1798.105 (partial) | `DELETE /portfolio/holdings/{ticker}` | [#374](https://github.com/yashasg/value-compass/issues/374) | Shipped (PR #446) |
| Erasure (full account, backend) | GDPR Art. 17; CCPA §1798.105 | `DELETE /portfolio` | [#450](https://github.com/yashasg/value-compass/issues/450) | This PR |
| Erasure (full account, iOS surface) | GDPR Art. 17; CCPA §1798.105; App Store §5.1.1(v) | iOS Settings → "Erase All My Data" (calls `DELETE /portfolio` + rotates Keychain UUID) | [#329](https://github.com/yashasg/value-compass/issues/329) | Open — frontend Settings flow + UUID rotation still pending. |
| Right to be informed | GDPR Art. 13; CCPA §1798.100(a) | The published Privacy Policy itself | [#224](https://github.com/yashasg/value-compass/issues/224) | Shipped (PR #417) |
| Right to restrict / object | GDPR Art. 18 / Art. 21 | Settings → remove Massive API key + uninstall | n/a | Shipped |

With `DELETE /portfolio` shipped by this PR, every endpoint in the
DSR tripod (access/portability, rectification, erasure) has a live
implementation. The remaining work in #329 is purely client-side —
wiring the iOS Settings flow that calls the endpoint and rotating
the Keychain `X-Device-UUID` post-success — not a backend deliverable.

## Per-right implementation notes

### Access / Portability — `GET /portfolio/export`

Returns every persisted `Portfolio` + cascaded `Holding` row keyed to
the calling `X-Device-UUID`, in a structured JSON envelope
(`PortfolioExportResponse`) with a `format_version` field so additive
evolution is auditable. Cache-only `StockCache` market-data fields are
**intentionally excluded** — they are ticker-keyed market data, not
personal data.

Auth: App Attest + a `device_uuid` that resolves to an existing
portfolio. Stamps `last_seen_at` on success so a DSR call alone keeps
the row out of the retention purge documented in
[`data-retention.md`](data-retention.md).

Verbatim contract: `app/Sources/Backend/Networking/openapi.json` →
`PortfolioExportResponse`.

### Rectification — `PATCH /portfolio`

Corrects any subset of the scalar portfolio fields (`name`,
`monthly_budget`, `ma_window`) in a single call. Each field is
optional; the body must carry at least one non-null value or the call
is rejected with the standard `schemaUnsupported` envelope (an empty
PATCH would otherwise no-op but still stamp activity, which is
ambiguous).

`ma_window` is validated against the documented allow-list
(`SUPPORTED_MA_WINDOWS = {50, 200}`) **before** the database
CheckConstraint sees it, so the client receives the precise
`unsupportedMovingAverageWindow` envelope rather than a generic 422.

Returns the rectified scalar fields on success so the iOS client can
confirm its local SwiftData state matches the server. Stamps
`last_seen_at`. Strictly scoped to the calling device.

### Rectification — `PATCH /portfolio/holdings/{ticker}`

Corrects a single holding's `weight`. `DecimalString` preserves exact
precision end-to-end (parity with `monthly_budget`; see #392) so a
correction that re-states the value cannot silently introduce
IEEE-754 drift.

Returns the persisted `ticker` + `weight` on success. The 404 envelope
is `portfolioNotFound` with `message = "Holding not found for
portfolio."` — we deliberately do **not** invent a new
`holdingNotFound` error code so the client surface remains a closed
enumeration.

### Rectification — ticker typo (`DELETE` + `POST`)

A holding whose ticker symbol itself is wrong (`AAPL` intended as
`MSFT`) cannot be corrected by `PATCH` because `ticker` is part of the
row's natural key. The client routes through
`DELETE /portfolio/holdings/{ticker}` followed by
`POST /portfolio/holdings` with the corrected ticker. The DELETE is
**row-scoped** — it removes exactly one `(portfolio, ticker)` pair
and leaves every other row, including the parent portfolio, untouched.
It is **not** the broader full-account erasure mechanism tracked under
issue #329.

### Erasure — full account (`DELETE /portfolio`)

Removes every `X-Device-UUID`-linked row the backend stores for the
caller in a single transaction. The model relationship cascade
(`Portfolio.holdings` → `cascade="all, delete-orphan"`) plus the
`Holding.portfolio_id` `ON DELETE CASCADE` FK guarantee that a
`db.delete(portfolio)` removes the parent row AND every child
`Holding`. Cache-only `StockCache` market data is **not** touched —
ticker market data is shared across devices and is not personal
data of the caller.

Auth: App Attest + a `device_uuid` that resolves to an existing
portfolio (404 `portfolioNotFound` otherwise). Returns `204 No
Content` on success.

Unlike every other authenticated endpoint, the erasure handler
deliberately does **not** stamp `last_seen_at`. The row is being
removed in the same transaction; a stamp would either no-op (if it
runs first) or resurrect a freshly-deleted row (if it runs against
an orphan reference). The retention-purge sweep documented in
[`data-retention.md`](data-retention.md) does not need a stamp here
— the row is gone, which is a strictly stronger outcome than a
stamp could provide.

Scoped strictly to the calling device's portfolio. A regression
that drops the `where(device_uuid == ...)` filter is caught by
`test_delete_portfolio_does_not_touch_other_devices` in
`backend/tests/test_api.py`.

The companion iOS Settings flow ("Erase All My Data" → calls this
endpoint, rotates the Keychain UUID, re-fires onboarding) lives in
issue [#329](https://github.com/yashasg/value-compass/issues/329) —
the backend prerequisite is now shipped, so #329 is no longer
gated on a missing endpoint.

### Right to be informed — published Privacy Policy

The published `docs/legal/privacy-policy.md` is the controller's
Art. 13 notice. It enumerates this entire endpoint map verbatim, so a
change here MUST update the policy in the same PR — see the
re-validation hooks documented in `loop-strategy.md`.

### Right to restrict / object

Investrum's only off-device flow today is Massive API-key validation,
which the user revokes by removing the key in Settings. No automated
decision-making is performed under GDPR Art. 22; the calculations are
deterministic and run on-device.

## Response-deadline reference

| Regulation | Response window | Citation |
|---|---|---|
| GDPR | 1 month (extendable by 2 months for complex requests with notice) | Art. 12(3) |
| UK GDPR | 1 month (same extension mechanism) | UK GDPR Art. 12(3), DPA 2018 |
| CCPA / CPRA (right to know / delete / correct) | 45 days (extendable by 45 days with notice) | Cal. Civ. Code §1798.130(a)(2), §1798.145(g) |
| CCPA (Notice of receipt of verifiable consumer request) | 10 business days | 11 CCR §7021(b) |

The in-product paths above respond synchronously (within an HTTP round
trip); the deadlines apply to any out-of-band channel (e.g. the
`mailto:privacy@…` fallback contemplated in issue #374, not yet
implemented — see "Open questions for counsel").

## Identity verification

The in-product paths verify the caller cryptographically:

1. **App Attest** — Apple's hardware-backed attestation on every
   request. Without a valid `X-App-Attest` header the backend returns
   `appAttestMissing` and never touches the database.
2. **`X-Device-UUID` keyed read** — the caller's UUID is the row's
   natural identifier. A request that cannot supply a UUID that
   resolves to a portfolio receives `portfolioNotFound`.

CCPA Regulations 11 CCR §7060 permits "non-account-holder" verification
to be password-less when the request is fulfilled through the same
authenticated mechanism the user already uses to access the service.
Apple-issued App Attest + a device-bound Keychain UUID is that
mechanism here. **Counsel must confirm** this verification posture is
adequate before publishing the policy URL.

## Re-validation hooks

A change to any of the following files SHOULD update this document in
the same PR:

| File | Why |
|---|---|
| `backend/api/main.py` | Endpoint contracts: changing a DSR route's shape, status codes, or auth changes the user-facing right. |
| `backend/db/models.py` | A new column on `Portfolio` or `Holding` expands the personal-data surface the rights attach to. |
| `app/Sources/Backend/Networking/openapi.json` | The contract iOS clients consume; out-of-sync schema means the policy claim does not match the wire. |
| `docs/legal/privacy-policy.md` §6 | The published policy text MUST stay congruent with this engineering record. |
| `docs/legal/data-retention.md` | A new retention category may require a matching DSR path. |
| `docs/legal/processor-register.csv` | A new processor changes the controller chain a DSR has to flow through. |

This list is the engineering-side checklist; the legal-side checklist
lives in [`privacy-policy.md`](privacy-policy.md) §10.

## Open questions for counsel (must resolve before publication)

1. Is App Attest + `X-Device-UUID` (no separate identity affidavit)
   sufficient verification under CCPA Regulations 11 CCR §7060 and
   GDPR Art. 12(6) for an account-less app whose only stable
   identifier IS the device UUID?
2. Do we need an out-of-band `mailto:privacy@…` fallback for users
   who cannot use the in-product paths (e.g. lost device, deleted
   app)? Issue #374 proposes one; the engineering-side gate is
   identity verification on a channel that cannot rely on App Attest.
3. Does the row-scoped `DELETE /portfolio/holdings/{ticker}` need an
   audit-log retention period for fraud-prevention purposes (typical:
   30 days post-delete, retained as access-restricted log only), or
   is the operational record in `data-retention.md` sufficient?
4. For California users, do we need a separate "Notice of Right to
   Correct" surface at the point of collection per 11 CCR §7023, or
   does the existing privacy-policy linkage in Settings → Legal
   satisfy the disclosure-at-collection obligation?

These items must be resolved (and recorded back here) before the
Privacy Policy URL goes live with the App Store listing.

---

## Cross-references

- [`privacy-policy.md`](privacy-policy.md) §6 — published "Your rights"
  text consumed from this document.
- [`data-retention.md`](data-retention.md) — `last_seen_at` stamping
  on every DSR call interlocks with the retention-purge schedule.
- [`data-processing-agreements.md`](data-processing-agreements.md) —
  processor chain a DSR has to flow through when sync is active.
- [`app-review-notes.md`](app-review-notes.md) — Notes-to-Reviewer
  language references this document for §5.1.1(v) account-deletion
  posture once issue #329 lands.
- [`processor-register.csv`](processor-register.csv) — every entry
  with `personal_data = true` must reach a DSR path documented here.
