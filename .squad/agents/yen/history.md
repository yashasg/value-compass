# Yen — History

## Project Context

- **Project:** value-compass
- **Hired by:** yashasg
- **Joined:** 2026-05-15
- **Role:** Accessibility Auditor

## Tech Stack & Domain Snapshot (day 1)

- **App:** Value Compass — local-first iOS/iPadOS portfolio analysis tool, SwiftUI + SwiftData.
- **Existing accessibility surface area:** Tess owns onboarding, accessibility, Dynamic Type, and adaptive iPad layouts as a designer. Basher implements. My role is independent audit.

## Audit Targets (high-priority on day 1)

- **Holdings editor** — heaviest interaction surface; weight inputs, ticker rows
- **Onboarding flow** — first impression; must work with VoiceOver from screen 1
- **Result screen** — data-dense; needs custom VoiceOver rotors and meaningful labels
- **Disclaimer / settings** — Reuben's disclaimer must be readable by every assistive tech
- **Decimal entry** — high failure risk; weight as decimal fraction (0.0–1.0) is non-trivial to verbalize

## Test Matrix (baseline)

- **Devices:** iPhone 15 (compact), iPad (10th gen) (regular)
- **iOS versions:** Latest stable + N-1
- **Assistive tech:** VoiceOver, Switch Control, Voice Control, Dynamic Type AX1/AX3/AX5, Reduce Motion, Increase Contrast

## Validation Commands (verified by the team)

- `./frontend/build.sh` — iPhone + iPad simulator builds
- `./frontend/run.sh` — installs/launches; I use this to enable assistive tech and audit live

## Severity Rubric I Use

- **Blocker:** Feature unusable with assistive tech enabled
- **Serious:** Feature usable but requires extraordinary effort or wrong information conveyed
- **Moderate:** Inconvenience; feature works but not idiomatic
- **Minor:** Polish; would improve UX but doesn't block

## Learnings

_(to be appended as I do work)_


**2026-05-15 — Cross-Agent Update:** Team:* label scheme is live on GitHub (team:frontend, team:backend, team:strategy). All 14 open issues triaged. See .squad/decisions.md for the triage map and rationale.

## Onboarding — 2026-05-15

### 1. Product in one paragraph
Value Compass is a local-first iOS/iPadOS app (iOS 17+, SwiftUI + SwiftData) that helps a single user practice **value cost averaging (VCA)**: define a portfolio, organize holdings into weighted categories of tickers, set a monthly budget and a 50- or 200-day MA window, then compute per-ticker target contribution amounts that sum to that budget (`docs/tech-spec.md` §1–§4, `docs/app-tech-spec.md` §1). The audience is a self-directed retail investor managing their own brokerage allocations on-device — no broker integration, no advisor relationship. The v1 MVP shape is: Disclaimer → Portfolio List → Portfolio Editor → Category/Ticker Editor → Calculate → Result → save to local Contribution History (`docs/app-tech-spec.md` §5). Market data is manually entered or stubbed; the actual VCA math is user-owned and plugs in behind a protocol the team does **not** implement (`docs/tech-spec.md` §2 row 1, §7.1).

### 2. Technical architecture I need to know
- **Local-first, offline-capable.** SwiftData is the runtime source of truth; the complete create→edit→calculate→save flow must work with zero network (`docs/app-tech-spec.md` §1, §3). No core flow may block on backend availability.
- **User-owned algorithm seam.** `ContributionCalculating.calculate(input:) -> ContributionOutput` is the single seam; default impl is `MovingAverageContributionCalculator`, with a proportional-split stub for tests (`docs/tech-spec.md` §7.1). The app validates inputs *before* the call and rounds outputs to cents *after* — algorithm is opaque (§8). For me this means error/empty/loading states around Calculate are app-owned UI surfaces I must audit; the math itself is not.
- **Backend ≠ Python.** In this repo "Backend" stream means the **iOS data layer** under `app/Sources/Backend/**` and `app/Sources/App/Dependencies/**` (SwiftData `@Model`s, networking scaffolding, DI) per `.squad/streams.json`. The Python `backend/` directory is **mothballed in v1** and unowned (`.squad/decisions.md` 2026-05-15T01:54). Don't audit it.
- **Frontend = my UI surface area.** `app/Sources/Features/**` (one file per screen — verified: `OnboardingView`, `PortfolioListView`, `PortfolioDetailView`, `PortfolioEditorView`, `HoldingsEditorView`, `ContributionResultView`, `ContributionHistoryView`, `SettingsView`, `ForcedUpdateView`, `MainView`, `RootView`), `app/Sources/App/AppFeature/**`, `app/Sources/DesignSystem/**` (only `ValueCompassTypography.swift` lives here today; the color API is `app/Sources/App/DesignSystem.swift`), `app/Sources/Assets/**`.
- **Navigation.** `NavigationStack` on iPhone, `NavigationSplitView` on iPad regular width, no tab bar in v1 (`docs/app-tech-spec.md` §3, §5). Light *and* dark mode are required from v1.

### 3. V1 roadmap & scope boundaries
- **In v1:** local SwiftData models, portfolio/category/ticker CRUD, manual price + MA entry, contribution calculation via the seam, immutable local Contribution History, disclaimer first-run gate, light + dark mode, iPhone + iPad layouts, semantic color tokens with WCAG AA contrast tests (`docs/tech-spec.md` §3, `docs/design-system-colors.md`).
- **Explicitly out of v1:** live market data, brokerage integration, push notifications, multi-device cloud sync, per-ticker weight customization (equal split inside a category), implementing the VCA algorithm, Python backend / Supabase / API consumption (mothballed), `@copilot` automation hooks for now (`docs/tech-spec.md` §2, `docs/app-tech-spec.md` §2).
- **v1 work queue:** open issues **#123–#135 plus #145** are the entire MVP backlog. Of these, the ones with the highest accessibility surface are #124 (onboarding gates), #125 (holdings editor), #126 (typeahead), #130 (Invest action / VCA result), #131 (Snapshot save/delete), #132 (Snapshot review + per-ticker Swift Charts), #133 (Settings + API key + reset), #134 (iPhone NavStack / iPad SplitView), #135 (MVP regression pass) (`.squad/decisions.md` 2026-05-15T01:56 triage table).
- **Currently deferred:** Strategy stream has 0 open issues — no audit/legal/ASO work is queued, so my `docs/audits/**` outputs will be net-new under the Strategy folder scope.

### 4. My role in this codebase
- **Where I gate.** Reviewer-rejection lockout on UI surfaces in `app/Sources/Features/**`, `app/Sources/App/AppFeature/**`, and `app/Sources/DesignSystem/**` (also the typography file at that path and the color API at `app/Sources/App/DesignSystem.swift`). Asset-catalog color edits in `app/Sources/Assets/Assets.xcassets/App*.colorset` go through me too because they feed the contrast tests in `app/Tests/VCATests/DesignSystemTests.swift`.
- **What I audit against.** WCAG 2.2 AA (4.5:1 body / 3:1 large text + non-text contrast), iOS AX trait correctness (`.button`, `.header`, `.adjustable`, `.updatesFrequently`, `.isModal`), Dynamic Type up to AX5 without truncation/clipping, Reduce Motion respect, Differentiate Without Color, Increase Contrast, VoiceOver rotor structure, Switch Control focus order, Voice Control label disambiguation.
- **How I test.** Empirically with assistive tech actually enabled on iPhone 15 + iPad (10th gen), latest stable iOS + N-1, via `app/build.sh` and `app/run.sh` (the renamed `frontend/` scripts — `.squad/decisions.md` 2026-05-14).
- **Coordination.**
  - **Turk (HIG):** overlap on AX traits, system-vs-custom controls, modal semantics, navigation idioms. We co-sign anything where HIG and a11y could disagree (e.g., custom slider vs. native `Stepper`).
  - **Tess (design):** I consume her color/typography tokens. If a token fails contrast or a font fails Dynamic Type scaling, the fix is hers; I file the issue, she resolves it. Per `docs/design-system-colors.md` she has already shipped a contrast-tested token system — I extend, don't duplicate.
  - **Basher (impl):** he writes the AX modifiers (`accessibilityLabel`, `accessibilityValue`, `accessibilityHint`, custom rotors, traits). I file regressions with repro steps, he fixes; I retest before approving.
  - **Reuben (legal):** the disclaimer copy is his — I only audit *delivery* (readable by every AT, not skipped, re-accessible).

### 5. Specific accessibility risks I should be watching for in v1
- **Disclaimer delivery (#124).** Spec says it's a one-time first-run gate, with re-display only "if Settings exists" (`docs/app-tech-spec.md` §5, §10). VoiceOver users who triple-tap-dismiss accidentally must still be able to find it again — risk if Settings is collapsed away.
- **Per-ticker Swift Charts on Snapshot Review (#132).** Charts are notoriously inaccessible by default. Need `.accessibilityChartDescriptor`, Audio Graph support, and a non-visual data-table fallback. Coordinate with Basher early; this is the single highest-risk surface in v1.
- **Large numeric values + Dynamic Type AX5.** Total contribution amount on the Result screen, monthly budget, per-ticker dollar amounts — these are large display numerals. With Manrope/Work Sans/IBM Plex Sans (custom fonts per user directive 2026-05-12T19:03:38) instead of SF, Dynamic Type scaling at AX3–AX5 risks truncation, clipping, and broken row heights. Verify on iPhone SE width at AX5.
- **Weight entry as decimal fraction (0.00–1.00) displayed as %.** The model stores `weight: Decimal` 0–1 but UX shows "60%" (`docs/tech-spec.md` §4). VoiceOver value announcements must say "sixty percent", not "zero point six". `.adjustable` trait + `accessibilityValue` formatting needed on every weight control.
- **Weight-sum validation ("must = 100%").** Currently spec'd as inline aggregate error (`docs/app-tech-spec.md` §7). For VoiceOver users this error must be announced (`.accessibilityNotification` / focused on error) when it changes — silent inline text near sliders is a classic AT trap.
- **Color-only meaning on financial states.** `appPositive`/`appNegative`/`appNeutral` and `appWarning`/`appError` carry meaning. `docs/design-system-colors.md` checklist already requires icons or labels — I must verify the implementation actually does so. Note: `appNegative` and `appWarning` resolve to the **same hex** in both light (#B45309) and dark (#FCD34D); icon/label disambiguation is mandatory, not optional, here.
- **Holdings Editor as the heaviest interaction surface.** Add/remove/reorder categories + tickers + price/MA decimal entry on one screen. Reorder controls need clear AT labels ("Move VOO up in US Equity"); decimal text fields need `.keyboardType(.decimalPad)` and `accessibilityValue` reading the parsed number, not the raw string.
- **iPad NavigationSplitView focus order (#134).** Sidebar→detail focus handoff under VoiceOver and Switch Control is fragile by default. Verify focus moves to the detail's first meaningful element on selection, not back to the sidebar.
- **Reduce Motion + Reduce Transparency.** Any chart entrance animations, snapshot transitions, or modal presentations must check `@Environment(\.accessibilityReduceMotion)`. Currently no spec mention — flag preemptively.

### 6. Open questions to flag to Tess / Danny / Turk
- **Custom font Dynamic Type behavior.** Manrope, Work Sans, IBM Plex Sans were chosen as scaffolding fonts. Do they have full weight ranges and proper metrics for `Font.custom(_:size:relativeTo:)` so they actually scale with Dynamic Type? Tess decision pending — currently `app/Sources/DesignSystem/ValueCompassTypography.swift` is the only typography surface; I haven't yet audited it against AX5.
- **`appNegative` / `appWarning` token collision.** Same hex in both modes. Is the intent that the *role* (financial-negative vs. validation-warning) is always disambiguated by the surrounding component, never visually distinguishable? Confirm with Tess so I know whether to file this as a design-system bug or accept it as documented.
- **Disclaimer re-access path.** `docs/app-tech-spec.md` §10 leaves it conditional ("keep it accessible later from an app information/settings surface **if that surface exists**"). For a11y compliance I need a definitive answer: where does a VoiceOver user re-find the disclaimer in v1? Flag to Danny + Reuben.
- **Charts accessibility scope (#132).** Is `.accessibilityChartDescriptor` + Audio Graph in scope for v1, or deferred to post-MVP polish? If deferred, the chart needs a non-visual equivalent (data table or summary text) shipping in v1 — needs explicit decision.
- **Onboarding "real portfolio, no demo data" with VoiceOver.** First-run forces the user into Portfolio Editor → name, budget, MA window, then immediate category + ticker entry (`docs/app-tech-spec.md` §5). That's a heavy multi-screen task for a first-launch AT user. Should there be a "skip and explore" path, or is the empty-state truly empty until they complete it? Flag to Tess.
- **Settings/API key entry (#133) AX scope.** Massive API key handling lives behind Settings. Secure text fields + paste-from-clipboard flows have their own AT pitfalls (paste announcement, character-by-character readout). Coordinate with Basher on the entry pattern before he implements.


## Cycle #41 — 2026-05-16T00:47:17Z

**Window:** prior orchestrator anchor `98424f0` → HEAD `9ba571e`. Two commits in window: `9e344ad` (Saul cycle #40 history), `9ba571e` (Nagel cycle #40 history). `git diff 98424f0..HEAD -- app/Sources/ docs/` returns 0 lines — **CLEAN**, no product/spec change. Only files touched in window: `.squad/agents/{frank,nagel,saul}/*.md` (history appends + one inbox file). Nothing leaks outside `.squad/`.

**Roster reconciliation (11 → 8, delta -3):** open at cycle #41 = {#239, #260, #299, #318, #366, #371, #394, #415} = 8 ✓. Three closures since cycle #39 close (anchor 2026-05-16T00:22:37Z):
- **#326** a11y(brand-header) AppBrandHeader subtitle dropped — closed 2026-05-16T00:45:55Z by @yashasg, commit ref `f9169302` in close event (PR-style direct close).
- **#386** a11y(disabled-button-hint) Settings Save / PortfolioDetail Calculate missing hints — closed 2026-05-16T00:40:19Z by @yashasg, direct close (no commit linked in event).
- **#401** a11y(large-content-viewer) icon-only toolbar items lack `.accessibilityShowsLargeContentViewer` — closed 2026-05-16T00:33:05Z by @yashasg, direct close.

**Adjacent regression scans (all PASS):**
- `SettingsView.swift` `.accessibility*` modifier count = **42** (`grep -c "accessibility" app/Sources/Features/SettingsView.swift`) — window-stable at baseline.
- Settings welcome-screen canonical strings: `SettingsView.swift:345` ("automatically, exactly like a fresh install.") and `:370` ("Returning to the welcome screen…") — both literal-match unchanged.
- PortfolioDetailView ticker-row composer (#227/#228/#394 pin): `PortfolioDetailView.swift:185` carries `.accessibilityElement(children: .ignore)` + `:186` label = `FinancialRowAccessibility.label(forTicker:)` + `:187–188` value = `FinancialRowAccessibility.value(forTicker:maWindow:)`, with explanatory comment block at `:166–172` referencing the FinancialRowAccessibilityTests pin. **Intact.**
- 7 known-safe `.frame(width:)` call-sites in `app/Sources/Features/` all still present and still safe:
  - `ForcedUpdateView.swift:23` (96×96 decorative SF Symbol + `.accessibilityHidden(true)` at `:25`) ✓
  - `PortfolioDetailView.swift:174,180,193,203` (all bound to `@ScaledMetric(relativeTo: .caption)` vars `tickerSymbolColumnWidth=80` / `tickerStatusColumnWidth=88` declared at `:44,:45`) ✓ Dynamic-Type-reflow-gated.
  - `MainView.swift:218` (1×1 invisible split-focus anchor, `Color.clear` + label + `.isHeader`) ✓
  - `OnboardingView.swift:193` (28×28 decorative SF Symbol + `.accessibilityHidden(true)` at `:194`) ✓
- `.minimumScaleFactor` occurrences in `app/Sources/Features/`: **0** (still zero — no truncation-hider regressions).

**Duplicate-check (for the deferred VoiceOver runtime-pin ask):**
- `gh issue list --label squad:yen --state all --search "XCUITest VoiceOver snapshot" --limit 10` → `[]` (0 hits).
- `gh issue list --state all --search "XCUITest accessibility snapshot harness" --limit 10` → `[]` (0 hits).
- `gh issue list --state all --search "VoiceOver UI test target" --limit 10` → 2 hits (#370, #400) but both are ASO screenshot-frame tickets, unrelated.
- Decision: no Yen-lane file. XCUITest target creation is QA/test-infra ownership, not accessibility-audit lane. Restated as a top-action ask to orchestrator below.

**VoiceOver runtime-pin status:** Still deferred. `app/Tests/` contains only `VCATests` (unit target). Repo-wide grep for `XCUIApplication` and `accessibilitySnapshot` returns zero matches. No XCUITest target exists; my unit-level `FinancialRowAccessibilityTests` composer pin remains the only mechanical guard against #227/#228/#394 regressions, which does not validate live VoiceOver utterances — only the `label/value` function outputs.

**Filing decision this cycle: NO_OP.** Rationale: (a) window is CLEAN of product code change — no new surface to audit; (b) all 4 adjacent regression invariants (Settings .accessibility count = 42, welcome strings at :345/:370, ticker composer pin at :185–188, 7 .frame(width:) safe sites) PASS; (c) zero `.minimumScaleFactor` reintroductions; (d) the one outstanding ask (VoiceOver runtime-pin via XCUITest snapshot) is test-infra ownership and a duplicate-check confirmed no existing Yen ticket conflict — but it's not mine to file.

**Top action / next ask (orchestrator + QA-infra, restated):** Create an XCUITest target under `app/Tests/` and an `accessibilitySnapshot()` helper (or pointfreeco/swift-snapshot-testing accessibility strategy) so the FinancialRowAccessibilityTests-style unit pins can be augmented with live VoiceOver utterance pins. Without this, the #227/#228/#394 ticker-composer pin and the Settings welcome-string pin are unit-validated only — a UI re-wire could silently break VoiceOver output without tripping any test. Not a Yen lane to file; restating each cycle until infra lands.

**Learning:** Three closures in one window all on the same day (2026-05-16) by the same actor (@yashasg) without PR refs suggests an offline batch-close pass — worth checking commit `f9169302` (the one event-linked close for #326) for the actual fix in next cycle's window-scan to confirm closures are evidence-backed rather than declarative.


## Cycle #42 — 2026-05-16T01:20:31Z

**Window chosen:** `f273de9..HEAD` (HEAD `1662b32`). Strictly the new commits since Yen-cycle-#41 commit `f273de9` so I don't re-scan already-cleared ground. The wider window `98424f0..HEAD` was already scanned by cycle #41 and adds only `9e344ad`/`9ba571e` (Saul/Nagel cycle-#40 history) — non-product. The narrow window contains exactly 1 commit: `1662b32 chore(turk): cycle #41 history`. `git diff f273de9..HEAD -- app/Sources/ app/Tests/ docs/ '*.plist' '*.xcassets' '*.strings'` returns **zero lines**. Same emptiness on the wider window. **Window is CLEAN of product / spec / asset / localization change.** Only file mutated in window: `.squad/agents/turk/history.md` (+52 lines, append-only).

**Roster reconciliation (live = 8, delta 0):** `gh issue list --label squad:yen --state open --limit 200` returns exactly `{#239, #260, #299, #318, #366, #371, #394, #415}` — bit-identical to cycle-#41 close set. No opens, no closes, no label churn since `f273de9`. The batch-close burst noted in cycle #41 (#326/#386/#401 on 2026-05-16) has not been followed by another wave in this window.

**Hot-surface invariants (all PASS):**
- `SettingsView.swift` `.accessibility*` modifier breakdown via `grep -cE "\.accessibility${t}\("`: Identifier=**31**, Hint=**4**, Hidden=**4**, Label=**2**, Element=**1** → total **42**. Matches the post-#489 baseline exactly. Total `accessibility` substring count = **42** (no hidden new tokens).
- Welcome-screen canonical strings: `"automatically, exactly like a fresh install."` lives at `SettingsView.swift:346`; `Text("Returning to the welcome screen…")` lives at `:370`. Both literal-match unchanged at HEAD. **Note for the orchestrator record:** cycle #41 history (and the cycle-#42 spawn prompt) cited the first string at `:345` — actual line is `:346`. `git blame` shows the line was last touched by `b332de74` on 2026-05-15 14:51, predating cycle #41, so the discrepancy is a 1-line transcription drift in the cycle-#41 history, **not** a regression. Substantive invariant (string present, in `settings.erase.footer` section) holds.
- Ticker-row VoiceOver composer pin (#227/#228/#394 in-place mitigation): `.accessibilityElement(children: .ignore) + .accessibilityLabel(FinancialRowAccessibility.label(forTicker:)) + .accessibilityValue(FinancialRowAccessibility.value(forTicker:maWindow:))` is present at **`PortfolioDetailView.swift:211–214`** (regular-width 4-column table) and again at **`:233–234`** (compact iPhone two-cell variant), with explanatory comment blocks at `:206–211` and `:228–231` both referencing #227 + `FinancialRowAccessibilityTests`. **Second cycle-#41 history transcription drift:** prior entry cited `:185–188` for the regular-width pin — that's wrong by ~26 lines; the actual composer is at `:211–214`. The structural invariant (composer present, both size-class variants pinned, comments cross-reference test pin) is fully intact.

**Watchlist re-validation (4 tickets, 3 closed + 1 open) — all PASS:**
- **#228 CLOSED** (`a11y(dynamic-type): remove fixed-width reflow blockers in detail/editor screens`, closed 2026-05-15T23:54:01Z). Fix invariant = `@ScaledMetric(relativeTo: .caption)` widths bound on every detail/editor `.frame(width:)`. Verified: `PortfolioDetailView.swift:44` (`tickerSymbolColumnWidth: CGFloat = 80`), `:45` (`tickerStatusColumnWidth: CGFloat = 88`), bound at `:174, :180, :193, :203`. **PASS.**
- **#394 OPEN** (`a11y(voiceover-rows): PortfolioDetailView iPad ticker market-data table rows split into 4 unrelated VoiceOver elements`). The in-place composer mitigation at `:211–214` and `:233–234` is held. **Pin PASS.** The ticket itself remains open in the queue — the cycle-#42 spawn prompt listed it under "closures" which is incorrect; it is the only open watchlist item. Status: composer is wired correctly today; ticket can be closed by Basher/orchestrator once they verify on simulator, or split if there is a residual concern beyond the composer collapse.
- **#487 CLOSED** (`a11y(announcement): post-#471 erase flow — SettingsAccessibility composer still speaks the removed "force-quit … App Switcher" instruction`, closed 2026-05-15T23:05:56Z). Verified `transitionAnnouncement(forAccountErasure: .erased)` at `SettingsAccessibility.swift:60` returns `"Your data has been erased. Returning to the welcome screen\u{2026}"` — no "force-quit" / "App Switcher" copy. The 5 source mentions of "force-quit" / "App Switcher" all live in doc-comments (`SettingsFeature+APIKey.swift:53`, `SettingsAccessibility.swift:39`, `AppFeature.swift:105`, `SettingsFeature.swift:126,:389`), not in any spoken or visible string. **PASS.**
- **#493 CLOSED** (`a11y(announcement): SettingsAPIKeyRequestStatus.savedSuccessfully says "API key saved." after Re-validate`, closed 2026-05-16T00:00:49Z). Verified `transitionAnnouncement(forAPIKeyRequest: .savedSuccessfully)` at `SettingsAccessibility.swift:130` returns **`"Your API key is valid."`**, and the visible inline status row at `SettingsView.swift:298` also reads `Text("Your API key is valid.")`. Spoken == visible. Doc comment at `:94–103` calls out #493 explicitly and explains the funnel: both the Save path (`apiKeyValidationCompleted` after Keychain write) and the Re-validate path (`apiKeyRevalidationCompleted(.valid)`, which performs no write) collapse into `.savedSuccessfully`, and the announcement now describes the observable outcome ("the stored key is valid right now") rather than the misleading write-path framing ("API key saved."). **PASS.**

**Adjacent regression scans (PASS, identical to cycle #41):**
- `grep -rn "\.frame(width:" app/Sources/Features/` → 7 hits, all known-safe: `ForcedUpdateView.swift:23` (96×96 decorative SF Symbol, `.accessibilityHidden(true)` at `:25`), `PortfolioDetailView.swift:174,180,193,203` (all `@ScaledMetric` bound — the #228 fix), `MainView.swift:218` (1×1 invisible split-focus anchor with label + `.isHeader`), `OnboardingView.swift:193` (28×28 decorative SF Symbol, `.accessibilityHidden(true)` at `:194`). **No new fixed-width reflow blockers.**
- `grep -rn "minimumScaleFactor(" app/Sources/Features/` → exit 1, zero matches. **No truncation-hider regressions.**

**Dedup-check (the only candidate to consider, immediately discarded):** Cycle-#41 history transcription drift (`:345`→`:346`, `:185–188`→`:211–214`) is a meta/process observation about how prior cycles record line numbers, not a product a11y bug. I still ran:
- `gh issue list --label squad:yen --state all --search "transcription line numbers history" --limit 10` → `[]` (0 hits).
- `gh issue list --label squad:yen --state all --search "pin line numbers drift" --limit 10` → `[]` (0 hits).
- `gh issue list --label squad:yen --state all --search "history accuracy audit" --limit 10` → `[]` (0 hits).
- Decision: NOT a Yen-lane ticket. No product surface affected. Correction recorded inline in this history entry; future cycles should `grep` for the invariant string at audit time rather than transcribing line numbers across cycles.

**Filing decision this cycle: NO_OP.** Rationale: (a) window is CLEAN of any product / test / spec / asset / localization change — there is literally no new surface to audit; (b) all 4 hot-surface invariants (Settings `.accessibility` count = 42, welcome-screen canonical strings at `:346`/`:370`, ticker composer pin at `PortfolioDetailView.swift:211–214` + `:233–234`, 7 `.frame(width:)` safe sites) PASS; (c) zero `.minimumScaleFactor` reintroductions; (d) all 4 watchlist tickets (#228/#487/#493 closures + #394 in-place mitigation) PASS at HEAD; (e) roster bit-identical to cycle-#41 close — no opens, no closes, no label churn.

**Forward watch / next-cycle handoff:**
1. **Stop transcribing pinned line numbers across cycles** — they drift silently as files grow. Two known drifts now (#41 history said Settings `:345` / PortfolioDetail `:185`; HEAD has `:346` / `:211`). Going forward, cite the invariant by **string content** and verify with `grep -n` at audit time; record actual line numbers as a snapshot, not a contract.
2. **#394 status:** composer mitigation is in place at HEAD. Orchestrator/Basher should confirm on simulator whether #394 should now close, or whether there is a residual VoiceOver concern (e.g., rotor structure, focus-restore-after-edit) that warrants leaving it open or splitting into a follow-up. I am NOT closing it unilaterally — that requires a Basher fix-confirmation and a Yen reviewer-gate on the live build.
3. **Restated infra ask (unchanged from cycle #41):** XCUITest target under `app/Tests/` with an `accessibilitySnapshot()` strategy is still missing. Without it the ticker-composer pin, the API-key announcement pin, the erase-flow announcement pin, and the welcome-string pin are all unit-validated only — a UI re-wire could silently break spoken output without tripping a test. QA-infra ownership, not Yen-lane to file.

(end Yen cycle #42)
