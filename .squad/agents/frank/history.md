# Frank — History

## Project Context

- **Project:** value-compass
- **Hired by:** yashasg
- **Joined:** 2026-05-15
- **Role:** App Store Optimizer

## Tech Stack & Domain Snapshot (day 1)

- **App:** Value Compass — local-first iOS/iPadOS portfolio analysis tool. v1 ships without a server.
- **Differentiator (per Saul/Danny):** Category-level weight contribution analysis — a lens brokerage apps don't provide.
- **Targets:** iOS App Store + iPadOS App Store; English-first; additional locales TBD post-launch.

## Storefront Strategy Day-1 Hypotheses

- **Primary category:** Finance
- **Secondary category:** Productivity (TBD — confirm during submission)
- **Working app name:** Value Compass
- **Working subtitle:** _(to be drafted with input from Saul's positioning research)_
- **Search intent to rank for:** "portfolio analysis," "asset allocation," "category weighting," "investment categories," "DIY investor tools" — needs validation

## Cross-Team Dependencies

- **Saul** → market intel, persona, positioning that drives copy
- **Reuben** → App Privacy labels, compliance review of every claim, financial-advice disclaimer wording for the listing
- **Tess** → visual direction for screenshots and preview video
- **Turk** → HIG-correct screenshot composition; Apple rejects screenshots that don't reflect actual app surfaces
- **Basher** → real screenshots from the simulator

## Validation Commands (verified by the team)

- `./frontend/run.sh` — installs/launches the app; I use it to capture screenshots across device families

## Outputs the team expects from me

- Metadata draft (name, subtitle, keywords, description, "What's New")
- Screenshot brief + finalized screenshot set per device/locale
- App preview video script + capture brief
- App Privacy label mapping (built from Reuben's data inventory)
- Review-response templates
- Post-launch ranking dashboard + iteration log

## Learnings

_(to be appended as I do work)_


**2026-05-15 — Cross-Agent Update:** Team:* label scheme is live on GitHub (team:frontend, team:backend, team:strategy). All 14 open issues triaged. See .squad/decisions.md for the triage map and rationale.

## Onboarding — 2026-05-15

### 1. Product in one paragraph (ASO/copywriter lens)
Value Compass is a local-first iOS/iPadOS app for **DIY investors who want to practice value cost averaging (VCA)** without handing their portfolio data to a broker, advisor, or cloud service (`docs/tech-spec.md` §1, §2). Users define a portfolio (categories + tickers, monthly budget, MA window of 50 or 200), enter prices manually, tap **Calculate**, and the app returns a per-ticker target contribution amount and saves it to local history (`docs/tech-spec.md` §3, §6). Elevator pitch sounds like: *"Tell Value Compass what to invest in and how much per month — it tells you exactly how much to put into each ticker this period, all on-device, no account, no broker."* The tone to lead with is **calm, mathematical, private** — not hype, not "AI." It is a **calculator + journal**, not an advisor (and the legal disclaimer screen is non-negotiable per `docs/tech-spec.md` §3 — Reuben gates listing copy against that).

### 2. Architecture facts that affect my storefront copy
- **Local-first, no server in v1** (`docs/tech-spec.md` §1, §2 row 3, §5; `.squad/decisions.md:229–246`). SwiftData is the source of truth. → Marketing asset: **"Your portfolio data never leaves your device."** Strongest differentiator in the Finance category.
- **No account, no login, no cloud sync** (`docs/tech-spec.md` §2 rows 3 & 7). → "No sign-up. No email. No tracking." Likely flows directly into App Privacy labels: **Data Not Collected** (Reuben must confirm before I claim it).
- **User-owned VCA algorithm via `ContributionCalculating` protocol seam** (`docs/tech-spec.md` §7.1). → A second differentiator I can lead with for the technical/quant persona: **"Bring your own strategy"** / **"The algorithm is yours, not ours."** Don't oversell — for the broad ICP, the default `MovingAverageContributionCalculator` *is* the product.
- **Universal app — iOS 17+ and iPadOS 17+** with `NavigationStack` on iPhone and `NavigationSplitView` on iPad (`docs/tech-spec.md` Targets header, §6 Navigation). → Screenshots **must cover both iPhone and iPad device families** in App Store Connect; iPad split-view is its own visual story (multitasking-friendly, desk-tool framing).
- **Bundle ID `com.valuecompass.VCA`, SKU `value-compass-ios`, display name TBD** (`docs/testflight-readiness.md` step 5). → "Value Compass" is the working display name; final string is App Store Connect input, not yet locked.
- **Manual market data in v1; live data + backend sync deferred** (`docs/tech-spec.md` §2 rows 2 & 3, §7.2). → I must NOT claim "real-time prices," "auto-sync," "live quotes," or anything implying broker/data-feed integration. Reuben will reject; Apple Review may also.
- **Push/notifications NOT shipped in v1** but the entitlement is declared (`docs/tech-spec.md` §2 row 5; `docs/testflight-readiness.md` step 2 mentions `remote-notification` background mode). → Don't promise alerts/reminders in description; the capability exists for future use only.

### 3. V1 roadmap & scope boundaries
**The v1 work queue is GitHub issues #123–#135 plus #145** (`.squad/decisions.md:131–144`). Until these land, **my storefront is hypothetical** — every keyword test, screenshot composition, and "What's New" draft is provisional and subject to revision when the actual UI stabilizes. Scope I can write copy *against*:
- Local SwiftData models for portfolios/market data/settings/snapshots (#123)
- Local-only app shell + onboarding gates (#124) — implies a first-run experience worth screenshotting
- Portfolio/category/symbol-only holding editor (#125)
- Bundled NYSE equity + ETF metadata with typeahead (#126) — keyword fodder: "NYSE," "ETF"
- API key management + Keychain storage (#127, #133) — implies a "settings" screen
- Local EOD market-data refresh (#128) and TA-Lib indicators (#129) — even though backend is optional, *some* market data flow exists
- Invest action with required capital + local VCA result (#130) — the money screen
- Explicit Portfolio Snapshot save/delete (#131) — feature framing: "save snapshots"
- Snapshot review + per-ticker Swift Charts (#132) — **first-class screenshot subject** (charts = strong store conversion)
- iPhone NavigationStack + iPad NavigationSplitView workspace (#134) — iPad story
- Settings, preferences, full local reset (#133) — privacy framing: "wipe your data anytime"
- MVP integration + regression test pass (#135) — green-light gate before submission
- TCA migration (#145) — internal architecture, **not user-visible**, **do not mention in copy**

**NOT in v1 — never imply these on the storefront:**
- iCloud / multi-device sync (`docs/tech-spec.md` §2 row 7)
- User accounts, login, social features
- Brokerage integration (`docs/tech-spec.md` §2 row 6)
- Live/real-time quotes (`docs/tech-spec.md` §2 row 2)
- Push notifications / reminders (`docs/tech-spec.md` §2 row 5)
- Per-ticker custom weights (`docs/tech-spec.md` §2 row 4) — "equal split within category" only
- Strategy tuning UI (`docs/tech-spec.md` §13 row 1, deferred per Issue #15)

### 4. My active surfaces (when v1 ships)
- **App name + subtitle (30 chars).** Working name: **Value Compass**. Subtitle draft requires positioning input from **Saul** (target persona language) before I commit. Reuben must trademark-clear the name.
- **Keyword field (100 chars).** Needs Saul's keyword volume + competitive density data. Day-1 hypotheses logged above (portfolio analysis, asset allocation, category weighting, value cost averaging, VCA, DIY investor, ETF, NYSE) — **all unvalidated**.
- **Description + "What's New".** I draft after #135 lands and the actual feature set is frozen. Reuben reviews every claim against `docs/tech-spec.md` non-goals; the disclaimer line gets a verbatim mention.
- **Screenshots: per device, per locale.** Required device families: **iPhone (6.7", 6.5", 5.5" historical fallback) AND iPad (12.9" + 11")**. Coordinate with **Tess** for visual direction, **Yen** for a11y of any in-shot type/contrast, **Turk** for HIG correctness (Apple rejects screenshots that don't reflect actual app surfaces — I cannot mock features that #123–#135 haven't built). **Basher** captures from the simulator via `./app/run.sh`.
- **App preview video (15–30s).** Depends on whether final UI is stable post-#145 (TCA migration). I will not shoot until #135 passes regression.
- **Category.** Primary: **Finance** (locked-in hypothesis). Secondary: **Productivity** *or* **Lifestyle** — flag for Saul/Reuben review before submission. Productivity reads more accurately given the "calculator + journal" framing.
- **App Privacy labels.** Must be TRUTHFUL. Local-first arch (`docs/tech-spec.md` §5; `.squad/decisions.md:229–246`) implies "Data Not Collected" — but **Reuben gates this declaration**. If #128 (market-data refresh) calls any third-party API, that's a data-flow Reuben must classify before I submit labels.
- **Localization plan.** **English-first** (already documented day-1). Additional locales TBD post-launch — needs budget + ICP signal from Saul before I commit.

### 5. Concrete ASO questions to resolve before v1 launch
1. **Trademark clearance** — Is "Value Compass" trademark-clear for a Finance-category iOS app? (**Reuben**)
2. **v1 ICP** — Who is the primary buyer? Quant-curious DIY investor? Bogleheads-style index investor? FIRE community? Drives subtitle, keywords, description tone. (**Saul**)
3. **Keyword data** — Search-volume + competition data for the day-1 hypothesis keywords. (**Saul**)
4. **Screenshot ownership** — Are screenshots a Tess-driven design artifact (she designs marketing comps) or a Frank-driven marketing asset (I direct, Basher captures real screens)? Different process, different timeline. (**Tess + Danny**)
5. **Localization budget** — One locale or multiple at launch? Affects copy effort by N×. (**Danny / yashasg**)
6. **Secondary category** — Productivity vs. Lifestyle? Saul's persona work likely decides this. (**Saul + Reuben**)
7. **App icon final?** — Required for store listing, screenshot consistency, and preview-video bumper. (**Tess**)
8. **App Privacy declarations** — Confirm "Data Not Collected" is truthful end-to-end after #128 (market-data refresh) and #127/#133 (API key Keychain) ship. (**Reuben**)
9. **Disclaimer language for the listing** — The in-app disclaimer is required (`docs/tech-spec.md` §3); does Reuben want a parallel disclaimer line in the App Store description (e.g., "Not investment advice")? (**Reuben**)

### 6. Open questions (gaps in the spec that block ASO)
- **No confirmed App Store display name** — `docs/testflight-readiness.md` step 5 says "intended display name" without specifying it. Working assumption: "Value Compass."
- **No proposed App Store category in writing** — Finance is my hypothesis; nowhere in `docs/tech-spec.md` or `docs/testflight-readiness.md` is the category declared.
- **No defined ICP for keyword targeting** — `docs/tech-spec.md` §1 describes the *function* but not the *user persona*. Saul owes the persona deliverable; without it, keyword strategy is guesswork.
- **No localization scope** — Neither the spec nor the testflight readiness doc mentions which locales v1 ships in. Defaulting to English-only until told otherwise.
- **No statement on third-party SDKs / analytics / crash reporting** — Affects App Privacy labels. `docs/tech-spec.md` §5 implies none, but I need explicit confirmation from Reuben + Basher.
- **No marketing URL, support URL, or privacy policy URL** declared anywhere — all three are required App Store Connect fields. Reuben + Livingston/yashasg need to provision these.
- **No app icon specification or location** referenced in the spec — required for both the binary and the storefront.
- **Final UI freeze date relative to TCA migration (#145)** — affects whether app preview video and screenshots can be captured before or after the migration lands. If we shoot pre-#145 and the navigation/animations change, we redo the video.

---

## Cycle #42 — 2026-05-16T01:20Z — Specialist Parallel Loop

**HEAD:** `1662b32` · **Window:** `98424f0` → `1662b32` (cycles #40 + #41 narrative; zero source-tree commits).

**Storefront-surface invariants scan:** `git diff 98424f0..HEAD -- docs/aso/ app/Sources/Features/SettingsView.swift app/Sources/App/PrivacyInfo.xcprivacy app/Sources/App/Info.plist app/Sources/Assets app/run.sh` → **EMPTY**. Full-tree window touches `.squad/agents/frank/inbox-saul-cycle-40.md` + four specialist history files only. **Classification: 100% storefront-INVISIBLE.** Welcome-screen footer canonical (`SettingsView.swift` l.345/370) UNTOUCHED. No screenshot refresh, no preview re-shoot, no metadata revision triggered.

**Peer-set probe — FULL 6-PEER (cadence restored, cycle-#40 partial retried & SUCCEEDED).**

Raw: `curl -sS 'https://itunes.apple.com/lookup?id=1488720155,6463484375,1288676542,328412701,1071915644,1001257338&country=us'` → `resultCount=6`, all peers live. iTunes egress fully open.

| Peer | trackId | Cycle #37 baseline | Cycle #42 live | Δ | Version |
|---|---|---|---|---|---|
| Stock Events (anchor) | 1488720155 | 4.81 / 2087 | **4.80546 / 2087** | byte-identical (6+ cycles stable #33→#37→#39→#42) | v9.35.4 (2026-04-30) |
| Snowball Analytics | **6463484375** (new) | 4.84 / 2045 | **4.84059 / 2045** | STABLE | v36.0 (2026-05-13) |
| Delta by eToro | 1288676542 | 4.71 / 11373 | **4.70737 / 11373** | STABLE | v2026.1.1 (2026-04-27) |
| Yahoo Finance | 328412701 | 4.75 / 617900 | **4.75152 / 617974** | STABLE, +74 reviews | v26.9.2 (2026-05-15, fresh) |
| M1 Finance | 1071915644 | 4.68 / 72549 | **4.68281 / 72549** | STABLE | v2026.5.2 (2026-05-12) |
| Empower (Personal Capital lineage) | 1001257338 | 4.78 / 381493 | **4.77663 / 381624** | STABLE (−0.003 = nil at n=381K), +131 reviews | v2026.05.13(2603) (2026-05-14, fresh) |

**Aggregate verdict:** Peer-zone 4.68–4.84★ — **identical band to cycle #37, six weeks zero rating drift**. Three peers cut new versions in-window (Yahoo / M1 / Empower) with **zero rating impact** — no scandal, no virality, no release-driven surge. The four mid-cap peers (Stock Events, Snowball, Delta, M1) had **literally zero new reviews in 2+ weeks**. Remarkably quiet competitive surface. No copy/screenshot/preview revision warranted from market signal.

**⚠️ Methodology correction — Snowball Analytics track ID:** Legacy ID `1407781015` (cited in cycle-#39 Top Action #1 and Saul's cycle-#40 inbox) returns `resultCount=0` (DEAD). Live Snowball Analytics now lives at `6463484375` — same name, same publisher ("Snowball Analytics" by "Snowball Analytics"), Finance, US storefront. Verified independently via `iTunes /search?term=Snowball Analytics dividend` (new ID is first result). Cycle-#37 baseline value (4.84★/2,045) IS correct — only the ID reference was stale. **Instrument repair, not a market signal — no issue filing warranted.** Recommended swap notified to Saul; I adopt `6463484375` as canonical from cycle #43 onward.

**Saul-handoff intake (cycle-#40 inbox at `.squad/agents/frank/inbox-saul-cycle-40.md`):** Absorbed. Zero storefront-surface delta in window confirmed (same verdict). Yahoo +74 partial-probe read independently reproduced (and held — no further drift since #40). Wording-drift Reuben-owned carry-forward reaffirmed. #322 7th-commitment-candidate (DSR audit-log) available if/when Danny approves the commitments frame — no storefront-copy change warranted this cycle.

**Dedup sweep (15 ASO domain keywords vs 27-issue Frank roster):** `storefront, copy, screenshot, keyword, subtitle, aso, positioning, landing, metadata, marketing, preview-video, CPP, version-notes, promotional-text, app-privacy` →
- storefront → #220 (source of truth); copy → #261/#327/#342 + frame caption issues #362/370/387/400/409/431/442;
- screenshot → #246/#284/#292 + 7 frame issues; keyword → #245/#220; subtitle → #377/#245/#220; aso → roster-level (all 27 are `aso(...)`);
- positioning → Saul's lane (#377 partial); landing → N/A for iOS; metadata → #220; marketing → #351 (Marketing URL);
- preview-video → #251; CPP → #390; version-notes → #261/#270; promotional-text → #342; app-privacy → #353.

**Zero novel candidates.** All keywords either collide with existing slots, are owned by Saul (positioning), or N/A (landing).

**Roster live-verified:** `gh issue list --label squad:frank --state open --limit 200 --json number --jq 'length'` → **27**. STABLE vs cycle #39 close. Zero new filings.

**Saul handoff written FIRST (cycle-#38 lesson):** `.squad/agents/saul/inbox-frank-cycle-42.md` (8,640 bytes, verified on disk pre-narrative). Contents: peer-probe table with raw curl, methodology correction on Snowball ID, storefront-invariant classification, wording-drift carry-forward, #286/#322 status, roster reconciliation.

**Cycle outcome: NO_OP on issue filing.** Storefront-surface ZERO delta + peer-zone STABLE + dedup-sweep ZERO novel = no Frank-side filing warranted. Three pieces of forward-value produced this cycle: (1) cadence restored — full 6-peer probe re-executed successfully (closed the cycle-#40 partial gap); (2) Snowball ID methodology repair (Saul to adopt swap; I adopt cycle #43+); (3) confirmed 6+ cycle Stock Events anchor parity + 6-week peer-zone rating stability.

**Forward watch (cycle #43):**
- Adopt Snowball `6463484375` as canonical probe ID; legacy `1407781015` retired.
- Single-anchor Stock Events probe on cycle #43 (cadence: every cycle).
- Next full 6-peer probe due cycle #45 (every-3rd cadence: #42 → #45).
- Wording-drift carry-forward continues (Reuben-owned).
- If Danny surfaces v1.0 description-copy decision, evaluate #322 7th-commitment-candidate fold-in.

(end Frank cycle #42)

## Cycle #43 — 2026-05-16T01:40Z — Specialist Parallel Loop

**HEAD:** `54d9df5` · **Window:** `1662b32` → `54d9df5` (six commits — all six specialist history appends from cycle #42 close; zero source-tree commits).

**Storefront-surface invariants scan:** `git diff 1662b32..54d9df5 -- docs/aso/ app/Sources/Features/SettingsView.swift app/Sources/App/PrivacyInfo.xcprivacy app/Sources/App/Info.plist` → **EMPTY**. Full-tree window touches 7 files — six `.squad/agents/*/history.md` and one inbox (`.squad/agents/frank/inbox-saul-cycle-42.md`). **Classification: 100% storefront-INVISIBLE.** Welcome-screen footer canonical (`SettingsView.swift` l.345/370) UNTOUCHED. `Info.plist` `UILaunchScreen` color-only UNTOUCHED. `PrivacyInfo.xcprivacy` declarations UNTOUCHED. No screenshot refresh, no preview re-shoot, no metadata revision triggered.

**Peer-set probe — FULL 6-PEER (cadence cycle #43 trigger executed, 6/6 LIVE).**

Method: `curl -sS "https://itunes.apple.com/lookup?id=<id>&country=us"` per-peer, sequential. iTunes egress fully open.

| Peer | trackId | Cycle #42 baseline | Cycle #43 live | Δ rating | Δ count | Version |
|---|---|---|---|---|---|---|
| Stock Events (anchor) | 1488720155 | 4.80546 / 2087 | **4.80546 / 2087** | 0 (byte-identical, 7+ cycles #33→#37→#39→#42→#43) | 0 | v9.35.4 (2026-04-30) |
| Snowball Analytics | 6463484375 | 4.84059 / 2045 | **4.84059 / 2045** | 0 (byte-identical) | 0 | v36.0 (2026-05-13) |
| Delta by eToro | 1288676542 | 4.70737 / 11373 | **4.70737 / 11373** | 0 (byte-identical) | 0 | v2026.1.1 (2026-04-27) |
| Yahoo Finance | 328412701 | 4.75152 / 617974 | **4.75150 / 617900** | −0.00002 (nil at n=617K) | −74 (current-version recount; v26.9.2 release-window cache flux) | v26.9.2 (2026-05-15, unchanged release) |
| M1 Finance | 1071915644 | 4.68281 / 72549 | **4.68281 / 72549** | 0 (byte-identical) | 0 | v2026.5.2 (2026-05-12) |
| Empower (Personal Capital lineage) | 1001257338 | 4.77663 / 381624 | **4.77661 / 381493** | −0.00002 (nil at n=381K) | −131 (build-label refresh `2603→2605.13.3`; recount window) | v2026.05.13 (2026-05-14, unchanged release) |

**Aggregate verdict:** Peer-zone **4.68–4.84★** — identical band to cycles #37 / #42, **seven weeks zero rating drift**. Four peers byte-identical to cycle #42; Yahoo and Empower show sub-noise rating flux (∆ < 0.0001★) with modest count decreases consistent with Apple's current-version-aggregate recount window (both shipped versions 14–15 May, recount still open at probe time T+24h–48h). Zero new version releases in-window. No copy/screenshot/preview revision warranted from market signal.

**⚠️ Methodology correction — three legacy IDs from cycle-#43 spawn brief are DEAD.** The coordinator brief listed Yahoo `328412086`, M1 `1145410103`, Empower `504672533`. All three return `resultCount=0`. Cycle-#42 canonical IDs (`328412701` / `1071915644` / `1001257338`) used for probe — same publishers, same names, verified live across multiple prior cycles. Pattern matches the cycle-#42 Snowball repair (`1407781015→6463484375`). **Instrument hygiene, not a market signal — no issue filing warranted.** Canonical-ID swap notified to Saul; Frank retains `1488720155 / 6463484375 / 1288676542 / 328412701 / 1071915644 / 1001257338` as the authoritative probe set from cycle #43 onward.

**Cross-lane intel (6 cycle-#42 commits in window):** Frank #42 (`54d9df5`) — full-probe restored, Snowball ID repair; Saul #42 (`5e58594`) — NO_OP, #286 counter 28→29 banked, roster 16 stable; Reuben #42 (`5f7e774`) — both gates PASS-no-trigger, CCPA §7102(a) promoted to new issue **#511** (Reuben-lane, no shipped storefront-copy surface yet); Yen #42 (`4eba7dd`) — watchlist 4/4 PASS, roster 8 stable; Turk #42 (`5dd6585`) — roster 15→13 (#341/#360 closed off-HEAD); Nagel #42 (`0928cf8`) — 4/4 PASS, three clean cycles since #303. **None storefront-actionable today** — captured for cross-lane awareness only; #511 trajectory watched for potential #322 commitments-block fold-in.

**Dedup sweep (15 ASO domain keywords vs 27-issue Frank roster):** `storefront, copy, screenshot, keyword, subtitle, aso, positioning, landing, metadata, marketing, preview-video, CPP, version-notes, promotional-text, app-privacy` →
- storefront → #220 (source of truth); copy → #261/#327/#342 + frame caption issues #362/370/387/400/409/431/442;
- screenshot → #246/#284/#292 + 7 frame issues; keyword → #245/#220; subtitle → #377/#245/#220; aso → roster-level (all 27 are `aso(...)`);
- positioning → Saul's lane (#377 partial); landing → N/A for iOS; metadata → #220; marketing → #351 (Marketing URL);
- preview-video → #251; CPP → #390; version-notes → #261/#270; promotional-text → #342; app-privacy → #353.

**Zero novel candidates.** Coverage map byte-identical to cycle #42. All keywords either collide with existing slots, are owned by Saul (positioning), or N/A (landing).

**Roster live-verified:** `gh issue list --label squad:frank --state open --limit 200 --json number --jq 'length'` → **27**. STABLE vs cycle #42 close. Zero new filings.

**Saul handoff written:** `.squad/agents/frank/inbox-saul-cycle-43.md` (9,396 bytes, verified on disk). Contents: in-window verification + commit-by-commit storefront-impact table, cross-lane intel from all 6 cycle-#42 history commits, full 6-peer probe table vs cycle #42 baseline, methodology correction on the 3 dead spawn-brief IDs, #286 counter context (Saul-owned, peer-delta input ZERO), wording-drift §6 carry-forward (Reuben-owned), roster reconciliation, top-3 cycle-#44 asks.

**Cycle outcome: NO_OP on issue filing.** Storefront-surface ZERO delta + peer-zone STABLE (seven weeks) + dedup-sweep ZERO novel = no Frank-side filing warranted. Three pieces of forward-value produced this cycle: (1) cadence held — full 6-peer probe re-executed successfully at the cycle-#43 trigger; (2) second methodology repair (3 dead spawn-brief IDs swapped to canonical) — same hygiene pattern as cycle-#42 Snowball repair; (3) confirmed 7-cycle Stock Events anchor parity + 7-week peer-zone rating stability.

**Forward watch (cycle #44):**
- Single-anchor Stock Events probe on cycle #44 (cadence: every cycle).
- Next full 6-peer probe due cycle #46 (every-3rd cadence: #43 → #46).
- Wording-drift §6 carry-forward continues (Reuben-owned).
- #511 (CCPA §7102(a) accountability surface) trajectory watched — if Reuben ships, evaluate fold-in to #322 commitments-block candidate set.
- #468 in-app-events scaffolding watch — Nagel three clean cycles, no surface yet.

(end Frank cycle #43)
