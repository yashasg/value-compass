# Data retention schedule

This document is the engineering record of how long value-compass keeps
each surface of `X-Device-UUID`-linked personal data, and the
mechanisms that enforce those limits. It is the artifact that
[`docs/legal/privacy-manifest.md`](privacy-manifest.md) and the
forthcoming Privacy Policy (tracked in #224) consume to answer GDPR
Art. 13(2)(a) ("the period for which the personal data will be stored,
or if that is not possible, the criteria used to determine that
period") and CCPA / CPRA §1798.100(a)(3).

> ⚠️ **Not legal advice.** This file is an engineering record of the
> retention surface that exists in the codebase today. The specific
> retention windows below (540 days / 30 days) are starting points based
> on commonly-cited regulator guidance and must be reviewed by qualified
> counsel before the matching Privacy Policy copy ships. The right
> number depends on (a) the publisher's stated purpose for retention,
> (b) jurisdictional minimums where any apply (none attach here because
> we do not custody assets and do not have an AML record-keeping
> obligation, but counsel must confirm), and (c) any operational need
> disclosed in App Store-facing copy. A real lawyer must sign off on the
> final values and on the language that publishes via #224 before App
> Store submission.

## Why this schedule exists

The iOS app declares the `X-Device-UUID` header as
`NSPrivacyCollectedDataTypeDeviceID` with `Linked = true` and purpose
`AppFunctionality` (`app/Sources/App/PrivacyInfo.xcprivacy:10–23`,
closed #271). The backend joins financial-info and user-content rows to
that identifier across three surfaces:

1. **Database rows** — `backend/db/models.py` defines `Portfolio.device_uuid`
   (`UUID, nullable=False`) keyed against `holdings.portfolio_id` via
   `ON DELETE CASCADE`.
2. **Application logs** — `backend/poller/apns.py` and the per-request
   error paths in `backend/api/main.py` emit log lines that may quote
   a redacted device-id suffix (the raw UUID is never logged after this
   schedule's redaction landed; see [Application logs](#application-logs)
   below).
3. **Reverse-proxy access logs** — Cloudflare sits in front of vca-api
   (per `backend/README.md`) and records request URLs and headers
   (including `X-Device-UUID`) at the edge.

GDPR Art. 5(1)(e) requires a documented storage-limitation schedule for
every one of those surfaces. CCPA / CPRA §1798.100(a)(3) requires the
same disclosure at the point of collection. This document is the source
of truth for the numbers; every other artifact must consume the values
from here.

## Schedule

| Surface | Personal data quoted | Retention window | Enforcement mechanism |
|---|---|---|---|
| `portfolios.device_uuid` + cascaded `holdings` | Device ID + Other Financial Info + Other User Content | **540 days of inactivity** (≈18 months) | `backend/poller/purge.py` daily APScheduler job (see [Database rows](#database-rows)) |
| `stock_cache` | None (ticker-keyed; not personal data) | Indefinite — until the ticker is delisted or the row is manually evicted | Manual; no scheduled purge required |
| Application logs (`vca.api`, `vca.poller`, `vca.poller.purge`, `vca.apns`) | Redacted device-id suffix only (last-4 hex characters); no raw UUID | **30 days** | `backend/infra/systemd/journald-vca-retention.conf` (`MaxRetentionSec=30day`) |
| DSR-fulfillment audit log (`vca.api` `event=dsr.*` lines — GDPR Art. 5(2) accountability + CCPA Regulations 11 CCR §7102(a) records-of-requests-honored) | Redacted device-id suffix only (last-4 hex characters); operation event name; affected-row count; portfolio_id | **30 days** (journald floor — inherited from Application logs row) | `backend/infra/systemd/journald-vca-retention.conf`; `backend/common/logging_utils.py` `redact_device_uuid` enforces the suffix-only surface |
| Cloudflare access logs | Raw `X-Device-UUID` header + request URL | **30 days** (Cloudflare plan default ≤ 30 days at submission time; tighter overrides via Logpush if the active plan exceeds 30 days) | Cloudflare retention configuration (verified at deploy and at every plan change) |

### Database rows

`Portfolio.last_seen_at` (added in migration `0003_add_portfolio_last_seen_at`)
is stamped to `datetime.now(UTC)` on every authenticated request that
resolves a portfolio by its `device_uuid` (`backend/api/main.py`
`_stamp_activity`). The retention-purge sweep
(`backend/poller/purge.py::purge_inactive_portfolios`) runs daily at
`PURGE_HOUR_UTC` (default 03:00 UTC) via APScheduler
(`backend/poller/__main__.py::build_scheduler`) and deletes every
`portfolios` row whose `last_seen_at < now - PORTFOLIO_RETENTION_DAYS`
(default 540 days). Legacy rows that pre-date the activity-stamp wiring
fall back to `created_at` so the schedule applies even before the first
post-migration request.

The deletion is performed via the SQLAlchemy ORM (`session.delete(...)`)
so the `Portfolio.holdings` cascade configured in `backend/db/models.py`
runs alongside the database-level `ON DELETE CASCADE` foreign key —
holdings rows therefore never out-live their owning portfolio.

Override knobs (environment variables, never hardcoded):

* `PORTFOLIO_RETENTION_DAYS` — inactivity window (days). Default 540.
  Tuneable so counsel-approved windows can ship without a code change.
* `PURGE_HOUR_UTC` / `PURGE_MINUTE_UTC` — daily fire time. Default
  03:00 UTC. Useful on staging hosts that want to validate the sweep
  on-demand.

### Application logs

`backend/poller/apns.py` and `backend/api/main.py` redact every
`device_uuid` reference to its last-4 hex characters via the shared
`backend/common/logging_utils.py::redact_device_uuid` helper before
emitting an `INFO` log line. The redaction is a data-protection-by-design
complement (GDPR Art. 25) to the retention schedule: even if a journald
snapshot ends up in an unanticipated artifact, the suffix carries ~16
bits of identity, which is enough for a developer to correlate against
a single bug-report device but far too few to re-identify across the
user base.

The DSR-fulfillment audit log surface
(`event=dsr.export.portfolio` and the sibling write-side
`event=dsr.*` lines tracked under #457) inherits the same redaction
floor from `redact_device_uuid` and the same 30-day journald window:
they exist to demonstrate that the controller honored a data-subject
request (GDPR Art. 5(2) accountability + CCPA Regulations 11 CCR
§7102(a) records-of-requests-honored), not to widen the application-log
surface. If counsel determines the CCPA §7102(a) "24 months" record is
required as a persisted store, that becomes a separate retention row
(its own audit-only table or S3/R2 sink) and must be added here at the
same time.

The 30-day journald retention floor is enforced by
`backend/infra/systemd/journald-vca-retention.conf`. Deploy automation
copies that file to `/etc/systemd/journald.conf.d/vca-retention.conf`
and runs `systemctl restart systemd-journald` so the floor is in place
before either vca-api or vca-poller emits a single record (see
`vca-api.service` / `vca-poller.service` deploy notes).

### Cloudflare access logs

Cloudflare retention is plan-dependent. The deploy operator confirms at
each plan change that the active plan defaults to ≤ 30 days or that
Logpush is configured with a 30-day rotation to `R2`. If the active
plan's default exceeds 30 days and Logpush cannot be configured, the
operator must record the variance here and on the Privacy Policy (#224)
before that policy publishes — the schedule above is the contract.

## App Store Connect "Data Retention" answers

`PrivacyInfo.xcprivacy` does not carry a retention-period field; the
matching surface on App Store Connect is the **Data Retention** answer
set under the App Privacy nutrition label. The answers below are the
consolidated record (cross-referenced from
[`docs/legal/privacy-manifest.md`](privacy-manifest.md) so the
engineering record stays internally consistent):

| App Privacy section | Data Retention answer | Source |
|---|---|---|
| Identifiers → Device ID | Retained until 540 days of inactivity | `portfolios.last_seen_at` enforcement above |
| Financial Info → Other Financial Info | Retained until 540 days of inactivity (cascades from Portfolio) | Cascaded `holdings` retention |
| User Content → Other User Content | Retained until 540 days of inactivity (cascades from Portfolio) | Cascaded `holdings.ticker` + `Portfolio.name` retention |

## Cross-references

* GDPR Art. 5(1)(e) — Storage limitation. <https://gdpr-info.eu/art-5-gdpr/>
* GDPR Art. 13(2)(a) — Notice-at-collection retention disclosure. <https://gdpr-info.eu/art-13-gdpr/>
* CCPA / CPRA Cal. Civ. Code §1798.100(a)(3) — Notice-at-collection retention disclosure. <https://leginfo.legislature.ca.gov/faces/codes_displayText.xhtml?lawCode=CIV&division=3.&title=1.81.5.&part=4.&chapter=&article=>
* Apple App Store Review Guideline §5.1.1 — Data Collection and Storage. <https://developer.apple.com/app-store/review/guidelines/#5.1.1>
* EDPB Guidelines 4/2019 on Article 25 — Data protection by design and by default.
* Sync-gate ledger update — `.squad/decisions.md`: "retention schedule" is the eighth pre-submission surface alongside the binary, PrivacyInfo, privacy policy, nutrition label, age rating, third-party-ToS surface, in-app DSR path.
* Related issues — #224 (Privacy Policy, consumes this schedule), #271 (App Privacy nutrition label, mapped above), #329 (Art. 17 erasure, complementary), #333 (Art. 20 portability, complementary), #338 (NOTICE / THIRD_PARTY_NOTICES).

## When this schedule must change

* A new third-party processor that stores `X-Device-UUID`-linked rows
  ships — add a row to the table above and update
  [`docs/legal/data-processing-agreements.md`](data-processing-agreements.md).
* The inactivity window changes (counsel sign-off) — change
  `PORTFOLIO_RETENTION_DAYS` default in `backend/common/config.py`
  **and** the row in the schedule **and** the matching App Store Connect
  Data Retention answer **and** the Privacy Policy (#224) copy.
* The journald retention floor changes — change
  `backend/infra/systemd/journald-vca-retention.conf` **and** the row in
  the schedule **and** the matching App Store Connect copy.
* The Cloudflare plan tier changes — record the new default-retention
  period or Logpush configuration here, and update the Privacy Policy
  if the value drifts above 30 days.
