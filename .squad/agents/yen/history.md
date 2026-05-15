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


