# Data Processing Agreements and international-transfer register

This document is the engineering register of every third-party data processor
that handles `X-Device-UUID`-linked personal data (and any portfolio /
holdings / contribution content joined to it) on behalf of the value-compass
controller. It records the GDPR Art. 28(3) Data Processing Agreement (DPA)
status and the GDPR Chapter V / Art. 46 international-transfer mechanism for
each processor.

> ⚠️ **Not legal advice.** This file is an engineering record of the
> processor surface that exists in the codebase today. The DPA and
> transfer-mechanism choices below must be confirmed by qualified counsel
> before submission and re-validated whenever a new third-party service is
> introduced (see [When this register must change](#when-this-register-must-change)).

## Why this register exists

`PrivacyInfo.xcprivacy` declares `NSPrivacyCollectedDataTypeDeviceID`,
`NSPrivacyCollectedDataTypeOtherFinancialInfo`, and
`NSPrivacyCollectedDataTypeOtherUserContent` as **linked** to the user
([`docs/legal/privacy-manifest.md`](privacy-manifest.md)). Every byte of that
data flows over the network and is therefore processed on the controller's
behalf by every infrastructure provider in the request path. Under GDPR
Art. 28(3), a written contract (a DPA) is required with each such processor;
under Art. 46, transfers to a third country (e.g. the United States) require
an adequate safeguard such as the EU–U.S. Data Privacy Framework (DPF) or
Module 2 Standard Contractual Clauses (SCCs).

Equivalent accountability obligations apply under CCPA §1798.140(j)–(v)
(service-provider contracts) and PIPEDA Sch. 1 Principle 4.1.3 (accountability
for transferred data).

## Controller and data subjects

| Role | Identity |
|---|---|
| Controller | value-compass publisher (Apple Developer Team ID per [`docs/testflight-readiness.md`](../testflight-readiness.md)). |
| Data subjects | End users of the iOS app whose device generates an `X-Device-UUID` ([`app/Sources/Backend/Networking/DeviceIDProvider.swift`](../../app/Sources/Backend/Networking/DeviceIDProvider.swift)). |
| Categories of personal data | Persistent device identifier (`X-Device-UUID`); financial information (`monthly_budget`, holding `weight`); user content (portfolio `name`, holding `ticker`). |
| Lawful basis | Contractual necessity (GDPR Art. 6(1)(b)) — providing the user-requested portfolio sync feature. |

## Processor register

| Processor | Role in the request path | Personal data processed | Establishment | Transfer mechanism (GDPR Ch. V) | DPA status | Source / contact |
|---|---|---|---|---|---|---|
| **Cloudflare, Inc.** | Reverse proxy, DDoS mitigation, response caching, App Attest cryptographic verification ([`backend/api/main.py`](../../backend/api/main.py), [`backend/README.md`](../../backend/README.md), [`backend/api/README.md`](../../backend/api/README.md)). All HTTP requests to `https://api.valuecompass.app` (including the `X-Device-UUID` header) traverse Cloudflare's edge. | Device ID; full request URL and headers; request and response bodies for non-cached responses. | United States (global edge network). | EU–U.S. Data Privacy Framework (DPF) self-certification + Cloudflare's standard SCC addendum (controller → processor, Module 2). | Cloudflare's standard DPA at <https://www.cloudflare.com/cloudflare-customer-dpa/> applies to all paid plans and to free-tier accounts on acceptance via the dashboard. **Status: TODO — confirm acceptance and record the acceptance timestamp + account email in [`processor-register.csv`](#processor-register-source-of-truth) before TestFlight submission.** | Cloudflare DPA portal: <https://www.cloudflare.com/gdpr/introduction/> · DPF: <https://www.dataprivacyframework.gov/list> |
| **Supabase, Inc.** | Managed Postgres host for the `portfolios`, `holdings`, and `stock_cache` tables ([`backend/db/README.md`](../../backend/db/README.md), [`docs/db-tech-spec.md`](../db-tech-spec.md)). Stores `device_uuid` joined to user-provided budget / ticker / weight rows. | Device ID; budget; ticker symbol; weight; row timestamps. | United States (default region for Supabase free / pro tiers). | EU–U.S. Data Privacy Framework (DPF) self-certification + Supabase Module 2 SCCs as Annex 2 of the DPA. | Supabase standard DPA at <https://supabase.com/legal/dpa> applies on acceptance via the dashboard (Settings → Legal). **Status: TODO — confirm acceptance and record the acceptance timestamp + project reference before TestFlight submission.** | Supabase DPA: <https://supabase.com/legal/dpa> · DPF list link above. |
| **Microsoft Corporation (Azure)** | Hosts the VM running `vca-api` and `vca-poller` under systemd ([`README.md`](../../README.md), [`backend/infra/systemd/`](../../backend/infra/systemd/)). Operational logs (`journald`) may quote `X-Device-UUID` until the retention schedule from #339 is enforced. | Device ID (in transient request logs); request metadata. | Region depends on the deployed Azure VM. The chosen region must be recorded below. | Within EEA: not a transfer. Outside EEA: Microsoft Products and Services DPA (Online Services Terms) including the EU SCCs (Module 2) attached as the OST DPA. | Microsoft's *Products and Services Data Protection Addendum (DPA)* applies to all Azure subscriptions on the Microsoft Customer Agreement / Online Subscription Agreement; it does not require separate signature. **Status: TODO — record the subscription ID and the Azure region for the production VM before TestFlight submission.** | Microsoft Products and Services DPA: <https://www.microsoft.com/licensing/docs/view/Microsoft-Products-and-Services-Data-Protection-Addendum-DPA> |
| **Apple, Inc. (APNs)** | Push delivery for the "new ticker ready" notification ([`backend/poller/apns.py`](../../backend/poller/apns.py)). Receives the APNs device token; **not** `X-Device-UUID`. | APNs device token (Apple-issued, opaque); push payload (no `X-Device-UUID`, no financial data — verify on every diff to `backend/poller/apns.py`). | United States. | Built into the Apple Developer Program License Agreement; APNs is a first-party platform service Apple controls jointly with its operating-system role. No separate DPA required for the data flow as currently designed. | Not separately required. Operate under the Apple Developer Program License Agreement. | Apple Developer Program License Agreement: <https://developer.apple.com/support/terms/apple-developer-program-license-agreement/> |
| **Polygon.io, Inc.** | Source of market-data caches ([`backend/poller/`](../../backend/poller/)). No personal data is sent to Polygon; the poller fetches tickers by symbol on a server-side schedule. | None. Outbound only; no `X-Device-UUID`, no portfolio content, no identifiers tied to a data subject. | United States. | Not applicable — no personal data is transferred. | Not required (no personal data leaves the controller for Polygon). Re-validate if a future change forwards user-attributable data. | Polygon.io ToS: <https://polygon.io/terms> |

### Status legend

- **Confirmed** — DPA accepted by an authorised signatory, evidence (signed PDF or dashboard acceptance log) archived in the controller's legal vault, and the acceptance timestamp recorded in [`processor-register.csv`](#processor-register-source-of-truth).
- **TODO** — DPA terms are published by the processor and applied on acceptance, but the controller has not yet recorded acceptance evidence. **Blocks submission.**
- **Re-validate** — A DPA is on file but the processor's terms or the data flow has changed since acceptance; counsel must re-confirm before continued use.

## Processor register — source of truth

`docs/legal/processor-register.csv` is the machine-readable source of truth
for the rows above. Engineers updating this file are responsible for keeping
the human-readable table in sync.

The CSV captures the columns reviewers need at audit time:

```
processor,role,personal_data,establishment,transfer_mechanism,dpa_status,dpa_link,acceptance_evidence
```

Empty `dpa_status` or `acceptance_evidence` cells are submission blockers.

## Pre-submission gate

`docs/testflight-readiness.md` references this register as a manual gate
before the manual `ios-deploy` workflow is run. The infra-change checklist
([Infra-change gate](#infra-change-gate) below) is the corresponding
engineering-side gate.

A submission is blocked unless every row in [`processor-register.csv`](processor-register.csv)
that processes personal data has:

1. A non-empty `dpa_status` of `Confirmed`.
2. A non-empty `acceptance_evidence` link or filename.
3. A non-empty `transfer_mechanism` if `establishment` is outside the EEA
   (DPF certification or SCC module reference).

The controller's privacy policy must also name each `Confirmed` sub-processor
and disclose the `transfer_mechanism` per GDPR Art. 13(1)(f) / Art. 14(1)(f)
(see open issue #224 for the published policy).

## Infra-change gate

Any change to one of the following surfaces must add a row (or update an
existing row) in [`processor-register.csv`](processor-register.csv) and in
this document, and must obtain a `Confirmed` DPA before merging:

- A new outbound HTTPS host in `backend/api/`, `backend/poller/`, or any new
  iOS network surface in `app/Sources/Backend/Networking/`.
- Any new cloud service or SaaS integration that receives `X-Device-UUID`,
  portfolio name, ticker symbol, or any other linked personal data.
- A region change for an existing processor (e.g. moving the Azure VM
  cross-region; switching the Supabase project's region).
- Any change to `backend/infra/systemd/` log destinations that could
  externalise journald output to a third party.

This gate is enforced by code review; there is no automated check yet
(future tooling can lint the openapi `servers[]` list and `backend/poller/`
outbound calls against the processor register).

## When this register must change

Update this file and bump the relevant CSV row immediately on any of the
following events:

1. **New processor introduced** — add a row, link the DPA, attach SCC / DPF
   evidence, set status to `TODO` until acceptance is confirmed, then flip
   to `Confirmed`.
2. **Processor terms changed** — re-validate the SCC module / DPF coverage
   and either flip status to `Re-validate` until counsel signs off, or
   record a new acceptance entry in the CSV.
3. **Region change** — update `establishment` and re-check the
   transfer mechanism; for any move into the United States or other third
   country, an SCC or DPF reference is required.
4. **Processor deprecation** — keep the row with status `Decommissioned`
   and the decommission date so the audit trail is retained per the
   retention schedule (#339).

## References

- GDPR Art. 28 (Processor obligations):
  <https://gdpr-info.eu/art-28-gdpr/>
- GDPR Chapter V — Art. 44–50 (Transfers to third countries):
  <https://gdpr-info.eu/chapter-5/>
- Commission Decision 2021/914 (Standard Contractual Clauses):
  <https://eur-lex.europa.eu/eli/dec_impl/2021/914>
- EU–U.S. Data Privacy Framework list:
  <https://www.dataprivacyframework.gov/list>
- CCPA service-provider contract requirements (§1798.140(j)–(v)):
  <https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CIV&sectionNum=1798.140>
- PIPEDA Schedule 1, Principle 4.1.3 (Accountability):
  <https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/the-personal-information-protection-and-electronic-documents-act-pipeda/p_principle/principles/p_accountability/>
