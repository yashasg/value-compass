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
