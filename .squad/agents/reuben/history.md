# Reuben — History

## Project Context

- **Project:** value-compass
- **Hired by:** yashasg
- **Joined:** 2026-05-15
- **Role:** Legal & Compliance Counsel

## Tech Stack & Domain Snapshot (day 1)

- **App:** Value Compass — local-first iOS/iPadOS portfolio analysis tool. v1 ships without a server.
- **Domain:** Personal-finance / portfolio analysis. **Not investment advice.** This distinction is load-bearing for App Review and for liability.

## Critical Compliance Areas (day 1)

1. **Financial-advice disclaimer** — Apple App Review guideline 1.1.6 + general liability. The app must clearly state it does not provide investment advice. Disclaimer needs to be visible during onboarding and reachable from settings.
2. **Privacy** — App is local-first; no PII leaves the device in v1. Privacy policy must accurately describe this. App Privacy labels in App Store Connect must match.
3. **Market data attribution** — Not active in v1 (no backend), but when sync arrives, market-data provider terms (Polygon, IEX, etc.) typically require attribution and have caching/redistribution restrictions.
4. **Third-party Swift packages** — Need to inventory licenses. Most iOS packages are MIT/Apache (safe). Flag any GPL/AGPL.
5. **Trademark** — "Value Compass" name needs a basic trademark search (USPTO TESS) before broad launch.

## Outputs the team expects from me

- Disclaimer text (with placement guidance for Tess/Basher)
- Privacy Policy and ToS drafts
- License inventory for the Swift Package Manager dependency tree
- App Privacy declaration mapping for App Store Connect (Frank consumes this)
- Risk register / compliance checklist for App Review submission

## ⚠️ Caveat I Carry Into Every Task

I am NOT licensed counsel. I surface issues, draft starting language, and flag risk — but the user MUST have an actual lawyer review anything before public launch. I will say this loudly and often.

## Learnings

_(to be appended as I do work)_


**2026-05-15 — Cross-Agent Update:** Team:* label scheme is live on GitHub (team:frontend, team:backend, team:strategy). All 14 open issues triaged. See .squad/decisions.md for the triage map and rationale.

## Onboarding — 2026-05-15

### 1. Product in one paragraph (compliance lens)

Value Compass is a local-first iOS/iPadOS app (iOS 17+/iPadOS 17+) that helps a user practice **value cost averaging (VCA)** by computing a per-ticker target contribution amount from a user-defined portfolio (`docs/tech-spec.md` §1, `docs/app-tech-spec.md` §1). The user organizes holdings into Categories → Tickers, sets a monthly budget and a 50/200 moving-average window, and the app — via an app-owned `ContributionCalculating` protocol seam — produces a contribution breakdown that gets saved to a local, immutable history ledger (`docs/tech-spec.md` §4, §7.1; `docs/db-tech-spec.md` §2). The intended user is an individual retail investor managing their own portfolio on-device. **The "analysis tool, not investment advice" framing is load-bearing**: it (a) determines whether Apple App Review treats this as a regulated financial product under Guideline 1.1.6, (b) sets the liability ceiling if a user underperforms, and (c) controls whether we are forced into broker/RIA-style disclosures we are not equipped to make. The disclaimer text already exists in `app/README.md` and is mirrored in `docs/app-tech-spec.md` §10 — my job is to make sure that exact framing is preserved everywhere it surfaces.

### 2. Architecture facts that affect my work

- **Local-first; SwiftData on-device persistence** (`docs/app-tech-spec.md` §3, `docs/db-tech-spec.md` §2). Portfolio, Category, Ticker, ContributionRecord, TickerAllocation all live in the app's default `ModelContainer`. No encryption in v1 (`docs/tech-spec.md` §5) — acceptable position because the data is non-sensitive (ticker symbols + target amounts), but I should note this in the App Privacy declaration.
- **No data leaves the device in v1 for the core flow.** No backend dependency, no account, no sync, no cloud (`docs/tech-spec.md` §1, Non-Goals #3/#7; `docs/app-tech-spec.md` §2 Non-Goals #3, §13). **This is a strong compliance posture for App Privacy labels (we can declare "Data Not Collected" for the portfolio/history surface) and for GDPR/CCPA/PIPEDA (no controller-processor relationship; no cross-border transfer; no DSR machinery needed).**
- **API keys are stored locally** — issue #127 ("Massive API key validation and Keychain storage"). Keychain is the right surface (hardware-backed, per-device, not iCloud-synced unless explicitly opted in). I need to confirm with Virgil that the Keychain item's `kSecAttrSynchronizable` flag is **false** in v1, otherwise the key replicates to iCloud and silently expands our data-egress surface.
- **Market-data refresh is over URLSession to a third party (Massive)** — issue #128 ("Massive client and shared local EOD market-data refresh"). When this lands I MUST verify: (a) what request payload is sent — does it include any user identifier, portfolio identifier, or list of held symbols? (b) Massive's ToS — attribution clauses, redistribution restrictions, caching limits, rate-limit disclosure obligations. (c) Is the API key sent in clear over TLS only, never logged? (d) Does the request URL or query string echo any portfolio data into request logs?
- **Bundle ID is `com.valuecompass.VCA` and the app declares the `remote-notification` background mode** (`docs/testflight-readiness.md` §1, item 2). Push notifications are listed as deferred in v1 (`docs/tech-spec.md` Non-Goals #5), but the entitlement is enabled. **Compliance issue:** if the entitlement is declared but unused, App Review may push back, and I have to either (a) justify it as planned post-MVP, or (b) recommend stripping it from the v1 entitlement set to keep the privacy story clean.

### 3. V1 roadmap & scope boundaries

**In v1 (open issues, per `.squad/decisions.md` triage table dated 2026-05-15):**

- #123 — Local SwiftData models (portfolios, market data cache, settings, snapshots)
- #124 — Local-only app shell and onboarding gates
- #125 — Portfolio, category, and symbol-only holding editor
- #126 — Bundled NYSE equity and ETF metadata with typeahead
- #127 — Massive API key validation and Keychain storage
- #128 — Massive client and shared local EOD market-data refresh
- #129 — TA-Lib-backed TechnicalIndicators package
- #130 — Invest action with required capital and local VCA result
- #131 — Explicit Portfolio Snapshot save and delete
- #132 — Snapshot review and per-ticker Swift Charts
- #133 — Settings, API key management, preferences, and full local reset
- #134 — iPhone NavigationStack and iPad NavigationSplitView workspace
- #135 — Complete MVP integration and regression test pass
- #145 — P0: migrate the app from MVVM to TCA (architecture refactor; not a feature)

**Mothballed / out-of-scope in v1** (`docs/tech-spec.md` Non-Goals; `.squad/streams.json` description; `.squad/decisions.md` 2026-05-15 stream-collapse decision):

- Python `backend/` (FastAPI `vca-api`, `vca-poller`, Supabase Postgres) — unwired, no team owns it in streams.json
- Generated OpenAPI Swift client (`app/Sources/Backend/Networking/openapi.json` mirror exists but is unused)
- Backend sync, account system, cloud sync, multi-device
- Push notifications (entitlement enabled but unused — see §2 above)
- Brokerage integration

**Why this matters for me:** GDPR/CCPA/PIPEDA exposure is **currently minimal** because there is no controller-processor relationship (no server collects user data) and no cross-border transfer of personal data. The moment sync/accounts ship (post-MVP), exposure spikes — I will need a Data Processing Agreement with Supabase, a published Privacy Policy with controller info, an EU/UK representative if we ship in EEA, CCPA "Do Not Sell or Share" surface, and DSR (access/delete/portability) tooling. None of that is needed for v1 — but I should pre-draft so we are not blocked when sync work begins.

### 4. My active surfaces in v1

Concrete things I should be watching, in priority order:

1. **Financial-advice disclaimer copy and placement** — Canonical text is in `app/README.md` and mirrored in `docs/app-tech-spec.md` §10:
   > _"This tool is for informational and educational purposes only. It does not constitute investment advice. Past price trends do not guarantee future performance. Consult a licensed financial advisor before making investment decisions."_
   Per `docs/app-tech-spec.md` §5 ("Onboarding & First-Run Flow") it must appear as a one-time first-launch gate AND remain reachable from a Settings/Info surface. **I need to coordinate with Tess** on: (a) the visual treatment (must be readable, not gray-on-gray micro-copy), (b) Dynamic Type support so it doesn't truncate, (c) the acknowledgment control (button vs. checkbox-then-button — I lean toward an explicit "I Understand" button to create an evidentiary record of acknowledgment), (d) whether the disclaimer is also surfaced inline on the Contribution Result screen and on the Invest action screen (#130) where the financial-advice risk is highest. **Open question:** is acknowledgment persisted (so re-launches skip the gate)? If yes, where — SwiftData or `UserDefaults`? Either is fine but it must survive a settings-reset (#133) so a reset user re-acknowledges.
2. **App Privacy labels** (App Store Connect → App Privacy) — Frank consumes my mapping. In v1 the declaration should be **"Data Not Collected"** for the portfolio/history surface (no collection by us; no third-party SDK collection because there is no analytics SDK, no crash-reporting SDK declared in v1, no ad SDK). **Verify with Virgil:** does the Massive market-data request transmit (a) the user's symbol list, (b) any device identifier, (c) the API key only? If only (c), the privacy declaration stays clean and I can declare "Data Not Linked to You — Other Diagnostic Data: None." If (a), I need to declare "Financial Info — App Functionality" because a portfolio symbol list is arguably financial information about the user even though it does not contain holdings amounts.
3. **Third-party Swift package license review** — known v1 dependencies that need a license check:
   - **TA-Lib (issue #129)** — there is a Swift wrapper landscape around the C library. The C TA-Lib library is **BSD-licensed** (good — permissive, attribution-only). I need to confirm which Swift wrapper (if any) is being adopted and verify *its* LICENSE file (some wrappers are MIT, some Apache 2.0; both fine). **Flag any wrapper that pulls in GPL/AGPL transitively.**
   - **Massive client (issue #128)** — appears to be a first-party HTTP client written by us against the Massive API; if it uses any third-party HTTP/JSON helpers beyond URLSession, those need license review.
   - I should produce a `docs/legal/third-party-licenses.md` inventory once #128 and #129 have landed Package.swift entries.
4. **Apple App Review Guidelines I am specifically watching** for the v1 submission:
   - **§1.1.6 Objectionable Content (False Information / Misleading)** — financial-advice disclaimer mitigates this.
   - **§5.1 Privacy** (5.1.1 Data Collection and Storage; 5.1.2 Data Use and Sharing) — clean in v1 thanks to no-collection posture.
   - **§5.5 Developer Code of Conduct** — ensure ToS/EULA do not over-promise outcomes.
   - **§3.1 In-App Purchase** — N/A in v1 (no monetization in scope per spec).
   - **§4.0 Design / 4.2 Minimum Functionality** — not my surface (Tess/Turk own this), but the v1 scope is rich enough to clear the threshold.
   - **§5.2 Intellectual Property** — license inventory feeds this.
5. **Onboarding gate copy (issue #124)** — disclaimer surface; this is where the disclaimer copy + acknowledgment UX lives. I should produce final copy and acknowledgment microcopy and hand it to Basher/Tess.
6. **Trademark exposure of "Value Compass" name and iconography** — basic USPTO TESS search needed for "Value Compass" word mark (Class 9 — downloadable software; Class 36 — financial services). Not a blocker for TestFlight, but a blocker for paid public launch and definitely a blocker before any marketing spend. Same check for any logo/glyph Tess produces.
7. **Settings → Full local reset (issue #133)** — must wipe the SwiftData container *and* the Keychain item from #127. The reset language ("Delete all my data" or similar) feeds the App Privacy label's "Data Deletion" section and feeds the Privacy Policy's user-rights section. I should ghostwrite the reset-confirmation copy.

### 5. Specific compliance risks in the v1 work queue

Issue-by-issue compliance touchpoints:

- **#123 — SwiftData models for portfolios, market data, settings, snapshots.** No GDPR issue (purely local persistence). Compliance ask: confirm the "settings" model does not include any optional analytics opt-in toggle that would trigger an App Privacy disclosure; if it does, route through me.
- **#124 — Local-only app shell and onboarding gates.** **High-touch for me.** This is where the disclaimer first-run gate lives. I own the copy and the acknowledgment UX recommendation. Need to land before TestFlight or App Review will reject under §1.1.6 / §5.5.
- **#125 — Portfolio, category, and symbol-only holding editor.** Low compliance touch. One note: ensure no example / placeholder portfolio names imply real-person ownership or imply specific recommendations (e.g., do not pre-fill "Buffett Portfolio").
- **#126 — Bundled NYSE equity and ETF metadata with typeahead.** **License check required.** Where does the bundled metadata come from? NYSE listings are factual (no copyright on the facts) but if we are bundling a third-party CSV/database with original selection or annotation, the source's license matters. Common sources: Nasdaq Trader symbol files (public-domain-ish), IEX Cloud (paid, ToS restrictions), or hand-curated from issuer S-1s. **I need to know the source before this ships.**
- **#127 — Massive API key validation and Keychain storage.** Security-posture relevant for App Privacy labels (Apple asks how secrets are protected). Keychain is the right answer. Confirm `kSecAttrSynchronizable = false` (do not iCloud-sync the key in v1). Confirm the key is never logged, never printed in error messages, never echoed into crash reports.
- **#128 — Massive client and shared local EOD market-data refresh.** **Highest unresolved compliance risk in v1.** Three asks: (a) document the exact request shape and what user-derived data (if any) appears in URL/headers/body; (b) review and excerpt the Massive ToS attribution + redistribution + caching + rate-limit clauses into `docs/legal/`; (c) confirm certificate pinning is either implemented or explicitly declined with rationale. The Privacy Policy must accurately list Massive as a data recipient if any user-derived data is sent (even just symbol lists).
- **#129 — TA-Lib-backed TechnicalIndicators package.** **License check.** TA-Lib C is BSD (permissive). Verify the chosen Swift wrapper's LICENSE and pin to a known-good version. Add to license inventory.
- **#130 — Invest action with required capital and local VCA result.** **Highest financial-advice exposure in v1.** This is the screen that says "invest $X in Y." If a regulator or a litigant ever argued we provide investment advice, this is the screen they would point to. The disclaimer must be **load-bearing and visible on this screen** — not hidden behind a tooltip. I will draft per-screen microcopy: a persistent footer or banner reading something like "Educational tool — not investment advice. See full disclaimer in Settings." Tess and Basher implement.
- **#131 — Explicit Portfolio Snapshot save and delete.** Snapshot history is local-only and immutable per `docs/db-tech-spec.md` §2.1 and `docs/app-tech-spec.md` §9 ("must remain on device and must never be synced"). Confirm with Virgil that no telemetry/diagnostic surface exfiltrates snapshot contents.
- **#132 — Snapshot review and per-ticker Swift Charts.** Low touch. Verify no chart library pulls in non-permissive licenses (Apple's Swift Charts is fine — first-party).
- **#133 — Settings, API key management, preferences, and full local reset.** **High-touch for me.** "Full local reset" feeds App Privacy "Data Deletion" claim and Privacy Policy user-rights section. I should write the reset-confirmation copy and confirm reset wipes BOTH SwiftData AND the Keychain item.
- **#134 — iPhone NavigationStack and iPad NavigationSplitView workspace.** No compliance touch.
- **#135 — Complete MVP integration and regression test pass.** No compliance touch directly, but this is where I should sign off that the disclaimer flow, the reset flow, and the onboarding acknowledgment all behave correctly end-to-end before TestFlight upload.
- **#145 — Migrate from MVVM to TCA.** No compliance touch directly. One ask: TCA's reducer architecture often introduces a logging/debug surface (`_printChanges`, `Reducer.dependency(\.logger)`); confirm that any debug logging is gated behind `#if DEBUG` so it cannot ship and silently log user portfolio state.

### 6. Open questions

Things in the spec / current state that I need legal clarity on before TestFlight, listed for the user / Danny:

1. **Disclaimer placement specificity.** `docs/app-tech-spec.md` §10 says "Display it during onboarding or first launch, and keep it accessible later from an app information/settings surface if that surface exists in v1." The "if that surface exists" is too soft — I need a hard commitment that **either** Settings (#133) **or** a persistent info button on Portfolio List exposes the disclaimer at any time. Recommend: settle this in #124 (onboarding gates) with an explicit acceptance criterion that the disclaimer is reachable in ≤ 2 taps from any screen.
2. **Privacy Policy URL.** App Store Connect requires a Privacy Policy URL at submission time. **None is referenced anywhere in the specs or `docs/testflight-readiness.md`.** Where will it be hosted? Recommend: a `legal/privacy-policy.md` rendered to a static page on either GitHub Pages (under the existing `yashasg.github.io` namespace or a project page) or a simple Vercel/Netlify deploy. I can draft the policy text; someone needs to commit to a hosting plan before TestFlight beta-test invites go out (not strictly required for internal TestFlight, but required for external testers).
3. **ToS / EULA jurisdiction (choice-of-law and venue).** Apple's standard EULA covers a lot, but if we publish a custom EULA we must pick a governing-law jurisdiction. **Unknown:** what jurisdiction is the user / publishing entity in? Default recommendation if unspecified: rely on Apple's standard EULA for v1 (no custom EULA shipped) — this is the lowest-risk path and standard for indie / pre-revenue apps. Confirm with user.
4. **Publishing entity.** Is the App Store Connect account an individual developer or a registered legal entity (LLC/Inc/Ltd)? This affects (a) who is the "data controller" named in the Privacy Policy, (b) personal liability exposure for the financial-tool framing, and (c) trademark filing eligibility. Need to know before drafting any public-facing legal doc.
5. **Massive ToS not yet on file.** I need a copy of (or a verified link to) Massive's API Terms of Service and Privacy Policy committed to `docs/legal/` before #128 merges. Cannot sign off on the privacy declaration otherwise.
6. **Push-notification entitlement justification.** `docs/testflight-readiness.md` step 2 enables push notifications on the App ID; v1 doesn't use them. Either (a) strip the entitlement for the v1 submission, or (b) document a planned post-MVP use. Apple has rejected apps for declaring entitlements they don't use.
7. **Crash-reporting / analytics SDK posture.** Specs do not mention any analytics or crash-reporting SDK (Firebase/Sentry/Crashlytics/Amplitude/etc.). I am operating on the assumption that v1 ships with **none** — which makes the App Privacy declaration trivially clean. **Confirm with Livingston / Virgil before submission** — if anyone slips one in late, the privacy declaration changes materially.
8. **Trademark search status for "Value Compass."** Not yet performed. Not a TestFlight blocker, but a public-launch / marketing-spend blocker. Should be done before Frank produces App Store metadata copy that leans on the brand.

⚠️ **Standing caveat (repeated from the top of this file):** I am NOT licensed counsel. Every item above is best-effort risk surfacing and starting language. The user MUST have an actual lawyer review the Privacy Policy, any ToS/EULA, and the financial-advice disclaimer before public launch.

---

## Cycle #42 — 2026-05-16T01:20:31Z (Specialist Parallel Loop)

**HEAD:** `1662b32` (chore(turk): cycle #41 history — window CLEAN, watchlist 4/4 PASS, #328 closed via PR #509, NO_OP).
**Anchor:** `98424f0` (compliance(dsr-audit-log): emit structured audit log on GET /portfolio/export (closes #445) (#506) — my prior in-lane closure at cycle #39).
**Window:** `98424f0..1662b32`. **First Reuben cycle-history entry committed to this file** (cycles #40 and #41 — Reuben did not produce a history commit because no novel compliance evidence surfaced and orchestrator log carried the gate evidence; this entry rebases the per-cycle history line at #42).
**Justification for anchor:** `98424f0` was Reuben's last in-window source/docs commit and the natural diff reference point for the two persistent re-validation hooks (#224, #294). Selecting it gives the widest defensible window for in-lane evidence (any compliance-relevant source delta from cycles #40 + #41 + #42 would land in this diff).

### Window-content classification

`git --no-pager diff --name-only 98424f0..HEAD` → 5 files, all under `.squad/agents/{frank,nagel,saul,turk,yen}/history.md` (Frank's `inbox-saul-cycle-40.md` is the only non-history file, and it's a peer-handoff scratch file under `.squad/`, not a product surface). **Zero source-code, zero docs, zero contract, zero policy-text delta.** This is a 100% specialist-history-only window.

### Re-validation gates (both run)

- **#224 (`docs/legal/privacy-policy.md`) — PASS-no-trigger.**
  - Command: `git --no-pager diff --stat 98424f0..HEAD -- app/Sources/Backend/Networking/APIClient.swift app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift app/Sources/Backend/Networking/DeviceIDProvider.swift app/Sources/App/PrivacyInfo.xcprivacy app/Sources/App/AppFeature/SettingsFeature.swift docs/legal/privacy-policy.md`
  - Result: empty. None of the 5 source triggers fired; `privacy-policy.md` untouched. No re-verification required.
- **#294 (`docs/legal/third-party-services.md`) — PASS-no-trigger.**
  - Command: `git --no-pager diff --stat 98424f0..HEAD -- app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift app/Sources/Backend/Networking/MassiveAPIKeyStore.swift app/Sources/Backend/Models/Disclaimer.swift app/Sources/Features/SettingsView.swift docs/legal/third-party-services.md`
  - Result: empty. None of the 4 source triggers fired; `third-party-services.md` untouched. No re-verification required.
  - Note: contrast with cycle #39, when #294 FIRED via `75643ba` (Yen `SettingsView.swift:298` `.savedSuccessfully` arm) and re-verified STILL ACCURATE. This cycle's window does not include any `SettingsView.swift` touch.

### In-window compliance keyword grep

Filter: `git --no-pager diff 98424f0..HEAD -- '*.swift' '*.md' '*.json' '*.plist' '*.py' ':(exclude).squad/agents/*/history.md' ':(exclude).squad/agents/frank/inbox-saul-cycle-40.md'` against keyword set `advice|disclaimer|massive|polygon|attribution|copyright|license|gdpr|ccpa|finra|x-device|api_key|consent|cookie|tracking|analytics|pii`.

**Result: 0 hits across every keyword class.** The 203 raw hits in the unfiltered diff are all narrative references inside specialist history files (Saul/Nagel/Yen/Turk discussing prior compliance closures from cycles #39–#41 in their own history append). No source-surface keyword introduction, no policy-text drift, no third-party SDK introduction.

### DSR roster status (per-issue OPEN/CLOSED + last activity)

| # | State | Last activity | Lane | Notes |
|---|---|---|---|---|
| #329 (erasure) | CLOSED | 2026-05-15T20:28:43Z | done | Pre-cycle-#39 closure (in-app server-side erasure path landed via prior cycle) |
| #449 (rectification UI) | OPEN | 2026-05-15T20:43:49Z | team:frontend P2 mvp | No movement since cycle #38. Settings trigger + fallback plumbing for right-to-correct flow pending |
| #444 (export UI) | OPEN | 2026-05-15T20:55:12Z | team:frontend P2 | No movement since cycle #38. Settings trigger + share-sheet plumbing for GET /portfolio/export pending |
| #457 (DSR write-side audit log, successor to closed #445) | OPEN | 2026-05-15T21:09:11Z | team:backend P2 security | No movement since cycle #38. PATCH/DELETE DSR audit log gap (Art. 5(2) accountability) — write-side counterpart now ripe to pull, GET-side precedent shipped in 98424f0 |
| #443 (App Privacy Connect parity) | OPEN | 2026-05-15T18:16:25Z | team:frontend P2 mvp security | No movement since cycle #38. Storefront answer-set parity vs PrivacyInfo.xcprivacy documentation gap |

**DSR-lane movement this cycle: zero.** All four OPEN DSR items are 4-to-7 hours stale relative to cycle-#42 start. **#457 is now the natural next pull** — GET-side audit-log precedent (#445) landed in window; write-side is the symmetric next step, schema/redaction helpers already centralized at `backend/common/logging_utils.py:24-38` and re-exportable.

### Carry-forward status (cycle-#39 list)

1. **§7102(a) 24-month persisted-store question** — **PROMOTED FROM PROSE TO TRACKED ISSUE.**
   - Filed as **#511 OPEN** by `yashasg` at `2026-05-16T00:41:37Z` (between cycle #39 close and cycle #42 start).
   - Labels: `documentation`, `priority:p2`, `security`, `team:backend`, `squad:reuben`.
   - Title: `compliance(dsr-audit-log): CCPA 7102(a) 24-month records-of-requests obligation unresolved against 30-day journald floor`.
   - Body explicitly cites `docs/legal/data-retention.md:107-110` conditional prose (the artifact Reuben pre-staged at cycle #39) and `backend/api/main.py:985-998` (the 30-day journald emit shipped in `98424f0`).
   - Acceptance criteria require licensed-counsel determination on whether 7102(a) applies, conditional-vs-resolved status update in `data-retention.md`, and either persisted-store design + data-retention row OR rationale documentation.
   - Status: **Decision gate before #224 publishes — pre-launch blocker.** Carry-forward retires as prose tracking; lifecycle now happens on #511. **Standing caveat applies: I am not licensed counsel; this determination must come from outside.**
2. **#485 (privacy-policy §6 wording-drift, in-process erasure return)** — **CLOSED 2026-05-15T22:45:40Z** via commit `8bd0cc1` (PR #495). Pre-cycle-#42 closure; carry-forward retires.
3. **"Value Compass" trademark search** — **OBSOLETE / SUPERSEDED.** Project rename to "Investrum" landed pre-cycle-#39; trademark clearance for the *current* name was tracked as **#314 (CLOSED)** with body `compliance(trademark): document Investrum name + logo + VCA-trigram clearance before App Store submission`. The legacy "Value Compass" word-mark search referenced in my day-1 history (§3 item 5) was rendered moot by the rename. Residual third-party-trademark exposure in storefront copy is covered by **#411 OPEN** (`compliance(marketing-assets): legal review checklist for App Store Connect screenshots / preview video / CPP / promotional copy`). Carry-forward retires; #314 already closed, #411 governs forward exposure.

### Cycle-window roster reconciliation (outside in-cycle work but recorded for ledger continuity)

Cycle-#39 close-state roster (14 open): `#237, #287, #344, #364, #385, #398, #408, #411, #427, #438, #443, #444, #449, #457`.

Current roster (14 open): `#237, #287, #344, #364, #398, #408, #411, #427, #438, #443, #444, #449, #457, #511`.

**Delta: −#385, +#511** (net 14, matches prompt).
- **#385** (`compliance(security-policy): publish coordinated vulnerability disclosure policy (SECURITY.md) for public repo`) **CLOSED 2026-05-16T00:38:34Z** — out-of-cycle closure between cycle #39 (00:22Z) and cycle #42 start (01:20Z). I did not author the closure within this cycle; logging here for roster ledger continuity. Verified `gh issue view 385` returns closed-state; the SECURITY.md publication is a docs/process artifact, not a source-surface delta inside my `98424f0..HEAD` diff window.
- **#511** (filed 2026-05-16T00:41:37Z) — promotion of §7102(a) carry-forward (above).

### In-window findings

**Zero novel compliance gaps.**

The window contains no product-surface, contract-surface, or policy-text delta. Both persistent re-validation gates returned PASS-no-trigger. Compliance keyword grep against non-history-file diff returned zero hits. No new third-party data flow, no new SDK introduction, no new disclaimer-text drift, no new EULA/ToS surface, no new App Store policy-relevant declaration. Therefore no new compliance evidence to surface.

### Dedup search (4 keyword axes)

Run before any candidate filing. None of the four axes surfaced a novel gap; all hits collide with already-tracked issues or out-of-lane closures.

- **Axis 1 — `CCPA 7102 audit retention` (gh issue list --state all --search ... in:title,body --label squad:reuben):** 2 hits — **#511 OPEN** (the §7102(a) carry-forward issue, already filed by user) + **#457 OPEN** (DSR write-side audit log, distinct scope — whether audit lines are *emitted* on PATCH/DELETE, not how long retained). Distinct surfaces; no new filing warranted.
- **Axis 2 — `journald 24 month records`:** 2 hits — same #511 + #457 collision. No new filing warranted.
- **Axis 3 — `trademark Value Compass`:** 4 hits — **#411 OPEN** (storefront marketing legal review, the live forward-exposure surface), **#314 CLOSED** (Investrum/VCA-trigram clearance — superseded "Value Compass" by rename), **#408 OPEN** (breach-notification, tangential semantic match on `Cal. Civ. Code §1798.82`), **#338 CLOSED** (repo-notices MIT preservation, no trademark scope). No novel trademark gap surfaced.
- **Axis 4 — `privacy-policy section 6 erasure`:** 4 hits — **#457 OPEN** (DSR write-side), **#364 OPEN** (privacy-manifest SPM Required-Reason API audit, distinct surface), **#374 CLOSED** (data-rectification path landed), **#471 CLOSED** (HIG quit/relaunch reroute landed). No novel privacy-policy text drift surfaced (and #485 already closed the §6 step-5 wording-drift carry-forward).

### Decisions

- **NO_OP on filings.** Window contains no source/docs/policy delta; both persistent re-validation gates PASS-no-trigger; compliance keyword grep returns zero compliance-relevant hits outside specialist history; four-axis dedup confirms no novel candidate.
- **Do NOT add a comment to #511.** The user filed it with complete evidence (data-retention.md:107-110 conditional prose + backend/api/main.py:985-998 30-day floor + statutory cites). A fresh specialist comment would add noise per cycle-#39 cross-lane stance.
- **Do NOT add a comment to #385's closure.** The SECURITY.md publication landed via a non-Reuben PR thread; the closure is self-documenting.
- **Retire two carry-forwards** (#485 closed; "Value Compass" trademark superseded by rename to Investrum + #314 closed).
- **Promote #457 to next-pull in DSR lane.** GET-side audit-log precedent shipped in `98424f0`; write-side schema/redaction helpers are already centralized at `backend/common/logging_utils.py:24-38` per cycle #39 evidence; the symmetric PATCH/DELETE emit is now the lowest-effort, highest-value next pull in the DSR roster. (Decision-only; not filing or pulling this cycle — flagging for the next sanctioned in-lane closure window.)

### Issue routing proof

None — no issue filed, no comment posted. NO_OP cycle.

### Roster snapshot (post-cycle, live via gh)

| # | Title (truncated) | Priority | Lane | Status note |
|---|---|---|---|---|
| #237 | compliance(licenses): in-app third-party acknowledgements for SPM deps | P2 mvp | team:frontend, team:strategy | open |
| #287 | compliance(age-rating): document App Store Connect age-rating answers for financial-utility | P2 mvp | team:frontend, team:strategy | open |
| #344 | compliance(data-minimization): non-collection categories + ATT stance for App Privacy nutrition label | P2 mvp | team:frontend | open |
| #364 | compliance(privacy-manifest): SPM dependency Required-Reason API audit + re-verification step | P2 mvp | team:frontend | open |
| #398 | compliance(eula): App Store Connect License Agreement posture (Standard vs Custom EULA) | P2 mvp | team:frontend | open |
| #408 | compliance(breach-notification): GDPR Art. 33/34 + Cal. Civ. Code §1798.82 procedure | P2 mvp | team:frontend | open |
| #411 | compliance(marketing-assets): legal review checklist for App Store Connect screenshots/preview/CPP/promo | P2 mvp | team:frontend, team:strategy | open |
| #427 | compliance(app-review-notes): §2.5.2 + SDK-absence negative declarations in Notes-to-Reviewer | P2 mvp | team:frontend, team:strategy | open |
| #438 | compliance(disclaimer): UI test coverage for calc-output disclaimer surfaces | P2 mvp | team:frontend | open |
| #443 | compliance(app-privacy): ASC storefront answer-set parity vs PrivacyInfo.xcprivacy (dormant-sync binary) | P2 mvp | team:frontend | open (DSR-adjacent) |
| #444 | compliance(data-export-ui): Settings trigger + share-sheet for GET /portfolio/export | P2 | team:frontend | open (DSR) |
| #449 | compliance(data-rectification-ui): Settings trigger + fallback for right-to-correct flow | P2 mvp | team:frontend | open (DSR) |
| #457 | compliance(dsr-audit-log): PATCH/DELETE DSR endpoints audit-log gap (write-side counterpart to closed #445) | P2 | team:backend | open (DSR; next-pull) |
| #511 | compliance(dsr-audit-log): CCPA 7102(a) 24-month records-of-requests vs 30-day journald floor | P2 | team:backend | open (DSR; counsel decision gate) |

**Total: 14 open.** Matches prompt. Δ vs cycle #39: net 0 (−#385 closed, +#511 filed; both out-of-cycle but reconciled here).

### Forward watch / handoff (≤2 lines)

- **Next pull candidate:** #457 (DSR write-side audit log) — GET-side precedent + centralized redaction helpers shipped at cycle #39; symmetric PATCH/DELETE emit is the lowest-friction next closure. If #471/#485-style in-process erasure flow or any DSR endpoint touches `backend/api/main.py` next cycle, fire #294 manually as a precaution (third-party register prose may need re-verification even though triggers didn't fire this cycle).
- **Counsel-decision watch:** #511 (§7102(a) 24-month obligation) is now a tracked pre-launch blocker for #224 publication; no specialist action available until licensed-counsel determination lands.

### Standing caveat

I am NOT licensed counsel. Every output in this cycle — the gate-PASS evidence, the DSR roster reconciliation, the carry-forward retirements, the routing for #457, and the framing of #511 as a "counsel decision gate" — is paralegal/compliance-engineering work product. Nothing in this entry substitutes for a licensed attorney's determination, and the user MUST obtain an actual attorney's review of (at minimum) the §7102(a) applicability question on #511, the EULA posture on #398, the breach-notification procedure on #408, and the Privacy Policy + ToS final text before any public App Store submission or marketing spend.

(end Reuben cycle #42)

---

## Cycle #43 — 2026-05-16T01:40:19Z (Specialist Parallel Loop)

**HEAD:** `54d9df5` (aso(frank): cycle #42 — full 6-peer probe restored (zone STABLE 4.68–4.84★), storefront ZERO delta, Snowball ID corrected, NO_OP filing).
**Window:** `1662b32..54d9df5` (6 commits, all specialist cycle-#42 history appends).
**Prompt-supplied anchor:** `1662b32` (chore(turk) cycle #41 history) — matches the cycle-#42 HEAD I closed on.

### Window-content classification

`git --no-pager log --oneline 1662b32..54d9df5` → 6 commits, all `<role>(<member>): cycle #42 …` history closures by Frank, Saul, Reuben (self, my own #42 commit `5f7e774`), Yen, Turk, Nagel. `git --no-pager diff --stat 1662b32..54d9df5` → 7 files, 677 insertions: 6 per-member `.squad/agents/<m>/history.md` plus `.squad/agents/frank/inbox-saul-cycle-42.md` (peer handoff scratch under `.squad/`, not a product surface). **Zero source-code, zero docs, zero contract, zero policy-text delta.** This is a 100% specialist-history-only window — identical content-shape to cycles #40, #41, #42.

### Re-validation gates (both run, both PASS-no-trigger)

- **#224 (`docs/legal/privacy-policy.md`) — PASS-no-trigger.**
  - Command: `git --no-pager diff --stat 1662b32..54d9df5 -- app/Sources/Backend/Networking/APIClient.swift app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift app/Sources/Backend/Networking/DeviceIDProvider.swift app/Sources/App/PrivacyInfo.xcprivacy app/Sources/App/AppFeature/SettingsFeature.swift`
  - Result: empty. None of the 5 source triggers fired; `privacy-policy.md` untouched. No re-verification required.
- **#294 (`docs/legal/third-party-services.md`) — PASS-no-trigger.**
  - Command: `git --no-pager diff --stat 1662b32..54d9df5 -- app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift app/Sources/Backend/Networking/MassiveAPIKeyStore.swift app/Sources/Backend/Models/Disclaimer.swift app/Sources/Features/SettingsView.swift`
  - Result: empty. None of the 4 source triggers fired; `third-party-services.md` untouched. No re-verification required.

This is the **fourth consecutive PASS-no-trigger cycle** for both hooks (cycles #40, #41, #42, #43). Last actual fire was #294 at cycle #39 via `75643ba` (Yen `SettingsView.swift:298` `.savedSuccessfully` arm) — re-verified STILL ACCURATE that cycle.

### In-window compliance keyword grep

Filter: `git --no-pager diff 1662b32..54d9df5 -- '*.swift' '*.md' '*.json' '*.plist' '*.py' ':(exclude).squad/agents/*/history.md' ':(exclude).squad/agents/frank/inbox-saul-cycle-42.md'` against keyword set `advice|disclaimer|massive|polygon|attribution|copyright|license|gdpr|ccpa|finra|x-device|api_key|consent|cookie|tracking|analytics|pii`.

**Result: 0 hits.** Non-history diff is empty; the empty stream of course matches nothing, but the bracketing keyword grep on the full unfiltered diff (203-shape narrative references in peers' history texts) is irrelevant because excluded paths are not product surfaces. No source-surface keyword introduction, no policy-text drift, no third-party SDK introduction.

### #511 follow-up (§7102(a) carry-forward)

`gh issue view 511 --json state,labels,updatedAt,comments` returns:
- State: **OPEN** (confirmed still open this cycle).
- updatedAt: `2026-05-16T00:41:46Z` (unchanged from cycle #42 close — issue filed at 00:41:37Z by `yashasg`, the 9-second drift is the label-application echo; no comment activity since).
- Labels: `documentation`, `priority:p2`, `security`, `team:backend`, `squad:reuben` (unchanged).
- Comments: 1 (the original body's auto-quoted body; same comment-count as cycle #42).

**Carry-forward action: log-only, no comment.** #511 is dormant pending licensed-counsel determination on §7102(a) applicability; per cycle-#42 stance, a fresh specialist comment would add noise — the issue body already cites `docs/legal/data-retention.md:107-110` + `backend/api/main.py:985-998` with full statutory framing. **#511 remains the pre-launch decision gate before #224 publishes.**

### Carry-forward: wording-drift §6 lines 257–258 ("disclaimer screen" vs SettingsView l.345/370 "welcome screen") — STILL UNFIXED

Cycle-#42 prompt flagged this as a residual wording-drift in `docs/legal/privacy-policy.md` §6 (the section describing the post-erasure post-state) — the policy text still says "disclaimer screen" but the in-process erasure reroute lands on the welcome screen per `SettingsView.swift` l.345/370. **Closure #485 fixed the "on next launch" tense drift but did not address the screen-name drift.** No source delta this cycle touches `SettingsView.swift` or `privacy-policy.md`, so the drift cannot be closed without an in-lane docs edit. Per hard constraint this cycle (do NOT edit `docs/legal/*`), this stays as a carry-forward. **Action item for next sanctioned docs-edit cycle:** patch `privacy-policy.md` §6 l.257–258 to replace "disclaimer screen" with "welcome screen" to match `SettingsView.swift` l.345/370 reality and the post-#471/#475 in-process reroute behavior.

### Dedup search (mandatory, 4 keyword axes)

Run before any candidate filing.

- **Axis 1 — `audit log` / `DSR` / `data-retention`:** Open hits → **#457** (DSR write-side audit log, next-pull), **#511** (§7102(a) 24-month vs 30-day journald). Closed hits → **#445** (GET-side audit log shipped at cycle #39), **#339** (retention schedule). No novel gap; both open issues already track the audit-log/retention surface.
- **Axis 2 — `third-party` / `privacy` / `eula`:** Open hits → **#398** (EULA posture), **#364** (privacy-manifest SPM Required-Reason API audit), **#411** (marketing-assets legal review, includes third-party trademarks), **#427** (App-review-notes SDK-absence). Closed hits → **#294** (third-party-terms surface), **#441** (third-party-services register drift). No novel gap.
- **Axis 3 — `age-rating` / `breach`:** Open hits → **#287** (age-rating questionnaire), **#408** (breach-notification GDPR Art. 33/34 + §1798.82). No novel gap.
- **Axis 4 — `eu/ccpa/gdpr`:** Open hits → **#449** (Art. 16 rectification UI), **#444** (Art. 15 export UI), **#443** (App Privacy ASC parity), **#457**, **#511**. Closed hits → **#329** (Art. 17 erasure), **#374** (Art. 16 rectification backend), **#391** (Art. 28 DPA / Art. 46 transfer, closed cycle #38). No novel gap.

**Conclusion:** All four axes collide with already-tracked issues. No novel compliance gap surfaced. No filing warranted.

### In-window findings

**Zero novel compliance gaps.** Same content-shape as cycle #42: history-only window, both gates PASS-no-trigger, keyword grep empty, dedup four-axis all collide.

### Decisions

- **NO_OP on filings.** Window contains no source/docs/policy delta; both persistent re-validation gates PASS-no-trigger; compliance keyword grep returns zero hits outside specialist history; four-axis dedup confirms no novel candidate.
- **Do NOT add a comment to #511.** Same rationale as cycle #42 — issue body is complete; specialist comment would add noise. Carry-forward continues as log-only; lifecycle stays on #511 until licensed counsel decides.
- **Wording-drift §6 l.257–258 carry-forward retained.** Patch deferred to next sanctioned `docs/legal/*` edit cycle; cannot edit this cycle per prompt's hard constraint.
- **#457 remains next-pull in DSR lane.** Stance unchanged from cycle #42 — GET-side precedent (`98424f0`) shipped, write-side schema/redaction helpers centralized at `backend/common/logging_utils.py:24-38`, symmetric PATCH/DELETE emit is the lowest-friction next closure when a sanctioned in-lane window opens.

### Issue routing proof

None — no issue filed, no comment posted, no label applied. NO_OP cycle.

### Roster snapshot (post-cycle, 14 open via gh)

`#237, #287, #344, #364, #398, #408, #411, #427, #438, #443, #444, #449, #457, #511` — **identical to cycle-#42 close (14 open, net 0 delta).** No filings, no closures, no out-of-cycle drift this window.

### Forward watch / handoff (≤2 lines)

- **Next pull candidate:** unchanged — **#457** (DSR write-side audit log). If any commit in the next window touches `backend/api/main.py` DSR endpoints (PATCH/DELETE) or `app/Sources/Features/SettingsView.swift`, fire #294 and #224 gates manually as a precaution.
- **Counsel-decision watches:** **#511** (§7102(a) 24-month obligation), **#398** (EULA posture), **#408** (breach-notification procedure) all dormant pending licensed-counsel input; no specialist action available.

### Standing caveat

I am NOT licensed counsel. The gate-PASS evidence, #511 status check, wording-drift carry-forward retention, four-axis dedup, and roster reconciliation in this entry are paralegal/compliance-engineering work product. Nothing here substitutes for a licensed attorney's determination, and the user MUST obtain an actual attorney's review of (at minimum) #511 §7102(a) applicability, #398 EULA posture, #408 breach-notification procedure, and the Privacy Policy + ToS final text before any public App Store submission or marketing spend.

(end Reuben cycle #43)
