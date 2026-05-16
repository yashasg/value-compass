# Turk — History

## Project Context

- **Project:** value-compass
- **Hired by:** yashasg
- **Joined:** 2026-05-15
- **Role:** Apple HIG Compliance Reviewer

## Tech Stack & Domain Snapshot (day 1)

- **App:** Value Compass — local-first iOS/iPadOS portfolio analysis tool. SwiftUI + SwiftData.
- **Targets:** iPhone (compact + regular widths) and iPad (regular + large; Stage Manager + Split View + Slide Over).
- **Tess** owns design and adaptive iPad layouts; **Basher** implements. My role is audit and reviewer-gate.

## HIG Hot-Spots on Day 1

- **Sheets vs. full-screen covers** — Holdings editor is a candidate for a sheet; result screen probably a navigation push
- **Lists** — Inset grouped vs. plain; section headers; swipe actions for ticker/category rows
- **Forms** — Decimal weight entry needs a numeric keyboard with done-bar; HIG patterns for inline validation
- **iPadOS multitasking** — All surfaces must behave reasonably at compact (Slide Over), regular, and Stage Manager sizes
- **Keyboard shortcuts** — iPad with hardware keyboard expects ⌘N (new), ⌘W (close), ⌘, (settings), arrow-key navigation in lists
- **Pointer interactions** — Hover effects on tappable rows when iPad has trackpad
- **App icon** — Single icon must read at every size; no transparency; safe area for the corner radius

## Coordination Map

- **Tess** → designs to HIG; I audit her designs
- **Basher** → implements native controls; I audit his code
- **Yen** → accessibility-flavored HIG (focus order, AX traits, larger tap targets); we share the gate

## Validation Commands (verified by the team)

- `./frontend/build.sh` — iPhone + iPad simulator builds
- `./frontend/run.sh` — installs/launches; I use it to test live multitasking and keyboard behavior

## Audit Report Format

For every finding I produce: (1) HIG section cite, (2) what the app currently does, (3) what HIG calls for, (4) severity, (5) recommended fix or — if we deviate intentionally — the documented rationale to add to decisions.md.

## Learnings

_(to be appended as I do work)_


**2026-05-15 — Cross-Agent Update:** Team:* label scheme is live on GitHub (team:frontend, team:backend, team:strategy). All 14 open issues triaged. See .squad/decisions.md for the triage map and rationale.

## Onboarding — 2026-05-15

### 1. Product in one paragraph
Value Compass is a **local-first iOS/iPadOS app** that helps a single user practice **value cost averaging (VCA)** across a self-defined portfolio. The user creates a `Portfolio` (name, monthly budget, MA window of 50 or 200), groups holdings into `Category` rows with weights summing to 100%, adds `Ticker` rows under each category, and triggers a contribution calculation that yields per-ticker target amounts via the `ContributionCalculating` protocol seam. Saved runs become an immutable `ContributionRecord` history. **V1 MVP shape:** offline-only, single-device, manual market-data entry (no live prices), no sync, no tab bar — a single navigation hierarchy rooted at the Portfolio List, plus a one-time disclaimer gate, onboarding to first real portfolio, and a Settings surface for API key + local reset. Source: `docs/tech-spec.md` §1–3, `docs/app-tech-spec.md` §1, §5.

### 2. Technical architecture I need to know
- **Platform:** iOS 17+ / iPadOS 17+, universal target (`docs/app-tech-spec.md` §3).
- **UI:** SwiftUI exclusively. Light + dark mode required from v1. No tab bar — single navigation hierarchy.
- **Navigation:** `NavigationStack` on iPhone (compact); `NavigationSplitView` on iPad (regular). The actual conformance work for that adaptive split is **issue #134** (`team:frontend`) — that's the workspace I will be auditing closely against HIG navigation-pattern guidance.
- **Persistence:** SwiftData (`@Model`), main-actor synchronous CRUD, append-only `ContributionRecord`, cascade delete from `Portfolio` (`docs/tech-spec.md` §5).
- **State management today:** MVVM (view model per feature). **Issue #145** is a planning issue to migrate to **TCA (The Composable Architecture)** — child issues will spawn from it. The folder split below already mirrors a TCA-style "Feature" / "View" separation, suggesting the migration is partially staged.
- **Folders I will gate:**
  - `app/Sources/Features/**` — SwiftUI view layer. Current files: `RootView.swift`, `MainView.swift`, `OnboardingView.swift`, `PortfolioListView.swift`, `PortfolioEditorView.swift`, `PortfolioDetailView.swift`, `HoldingsEditorView.swift`, `ContributionResultView.swift`, `ContributionHistoryView.swift`, `SettingsView.swift`, `ForcedUpdateView.swift`.
  - `app/Sources/App/AppFeature/**` — Feature/view-model layer. Current files: `AppFeature.swift`, `MainFeature.swift` (+ `MainFeature+Shell.swift`), `OnboardingFeature.swift`, `PortfolioListFeature.swift`, `PortfolioEditorFeature.swift`, `PortfolioDetailFeature.swift`, `HoldingsEditorFeature.swift`, `ContributionResultFeature.swift`, `ContributionHistoryFeature.swift`, `SettingsFeature.swift` (+ `SettingsFeature+APIKey.swift`), `ForcedUpdateFeature.swift`.
- **Design tokens:** `app/Sources/App/DesignSystem.swift` + `app/Sources/Assets/Assets.xcassets/App*.colorset` — semantic tokens like `appPrimary`, `appSurface`, `appPositive`/`appNegative`/`appNeutral` (financial states must pair color with label/icon — see `docs/design-system-colors.md`).
- **Build/run:** `app/build.sh` (iPhone + iPad simulator), `app/run.sh` (boot, install, launch). Defaults to iOS/iPadOS 26.4, iPhone 17 + iPad (A16). I use `run.sh` to drive live multitasking and hardware-keyboard tests.

### 3. V1 roadmap & scope boundaries
**In v1 (issues #123–#135 + #145):**
- #123 — Local SwiftData models for portfolios, market data, settings, snapshots (`team:backend`).
- #124 — Local-only app shell + onboarding gates (disclaimer, first-run, empty state).
- #125 — Portfolio, category, and symbol-only holding editor.
- #126 — Bundled NYSE equity/ETF metadata with **typeahead** (HIG-relevant: typeahead pattern).
- #127 — API-key validation + Keychain storage (`team:backend`).
- #128 — Massive client and shared local **EOD market-data refresh** (`team:backend`).
- #129 — TA-Lib-backed `TechnicalIndicators` package (`team:backend`).
- #130 — Invest action with required capital + local VCA result.
- #131 — Explicit **Portfolio Snapshot** save and delete.
- #132 — **Snapshot review** screen + per-ticker **Swift Charts** (HIG-critical: Charts conformance, screen presentation pattern).
- #133 — **Settings**, API key management, preferences, full local reset (HIG: sheet vs. full-screen pattern).
- #134 — **iPhone NavigationStack and iPad NavigationSplitView workspace** (HIG-critical: my single highest-priority audit target).
- #135 — Complete MVP integration + regression test pass.
- #145 — Planning: MVVM → **TCA** migration (`team:frontend` + `team:backend`).

**Out of v1 (do not let scope creep through HIG critique):**
- No live market data, no brokerage integration, no push notifications, no multi-device/cloud sync, no per-ticker custom weights, no backend-required flows. The Python `backend/` tree is mothballed in v1. (`docs/tech-spec.md` §2; `docs/app-tech-spec.md` §2.)
- I must not push UI patterns that *require* network — every audit must validate the offline path.

### 4. My role in this codebase
- **Gating scope:** Every UI surface in `app/Sources/Features/**` and every feature/state file in `app/Sources/App/AppFeature/**`. PRs touching those paths need a HIG pass from me before reviewer gate clears.
- **What I audit against (Apple HIG):** Navigation patterns (push vs. sheet vs. full-screen cover, modality), list styles (inset grouped vs. plain, section headers, swipe actions), forms and pickers (segmented control vs. menu vs. picker, numeric keyboards with done-bar), iPadOS multitasking (Slide Over compact, Split View, Stage Manager resize), keyboard shortcuts and focus engine on iPad with hardware keyboard (⌘N, ⌘W, ⌘,, ⌘F, arrow-key list nav), pointer interactions (hover effects, pointer styles for tappable rows on iPad with trackpad), SF Symbols usage and weights, app icon (single icon, no transparency, safe area), Swift Charts conformance, Settings surface conventions, and disclaimer presentation.
- **Findings format:** (1) HIG section cite, (2) current behavior, (3) what HIG calls for, (4) severity, (5) fix or documented deviation rationale to add to `.squad/decisions.md`.
- **Coordination:**
  - **Tess** (`.squad/agents/tess/charter.md`) — owns design *within* HIG. I review her designs for HIG conformance before they go to Basher; on a conflict between her aesthetic call and HIG, HIG wins unless we log a deviation.
  - **Basher** (`.squad/agents/basher/charter.md`) — owns implementation. I audit his SwiftUI for native-control selection (e.g., `.sheet` vs. `.fullScreenCover` vs. `NavigationLink`, `Menu` vs. `Picker`, `List` style modifier choice).
  - **Yen** (`.squad/agents/yen/charter.md`) — owns accessibility. We overlap on focus order, hit targets (≥44pt), Dynamic Type behavior, and VoiceOver traits. Default split: structural HIG → me; AX traits/labels/Dynamic Type/contrast → Yen. Co-sign on: tap targets, focus engine, hardware-keyboard navigation, color-only meaning.
  - **Reuben** (`.squad/agents/reuben/charter.md`) — owns App Review Guidelines (policy). HIG ≠ App Review. If a finding is "Apple will reject this build," that's Reuben; if it's "this violates platform convention," that's me. Examples on his side: financial-disclaimer copy, account-deletion requirement, disclaimer presentation as a policy gate. Examples on my side: *how* the disclaimer is presented (sheet vs. full-screen cover, dismiss affordance).

### 5. Specific HIG risks I'm watching in v1
- **Adaptive navigation correctness (#134):** `NavigationSplitView` on iPad must collapse properly into `NavigationStack` at compact widths (Slide Over, Split View narrow column, Stage Manager small windows). Sidebar selection state and back-stack restoration across size-class transitions are common regressions. Verify `NavigationSplitViewVisibility` and column widths against HIG "Split Views."
- **Portfolio Snapshot review screen (#131, #132):** Decide push vs. modal sheet vs. full-screen cover. HIG modal guidance: a sheet is for a self-contained side task; a navigation push is for a deeper drill-in within the same hierarchy. A snapshot **review** is most likely a navigation push from Portfolio Detail (it's part of the same flow), not a sheet. Audit and lock this in writing.
- **Settings surface (#133):** HIG Settings convention is a presented sheet from the root or a pushed screen reachable from a toolbar gear. Full-screen cover is wrong here. Also: `⌘,` opens Settings on iPad with a hardware keyboard. Local-reset destructive action needs `.destructive` role + confirmation `.alert` (HIG: confirming destructive actions).
- **Ticker typeahead (#126):** Typeahead pattern must use `.searchable` or a `Menu`/`List` of suggestions, not a custom popover. On iPhone keyboard appearance + result list scroll behavior must obey HIG search guidance; on iPad, suggestions should be reachable by arrow keys + return.
- **Swift Charts conformance (#132):** Per-ticker charts must respect HIG Charts guidance — proper axes/labels (not color-only), Dynamic Type for chart labels, dark-mode aware tints from `appPositive`/`appNegative` (paired with sign labels per design-system rule 3), and accessible chart descriptors (`.accessibilityChartDescriptor`) — co-sign with Yen.
- **Hardware-keyboard support on iPad:** `⌘N` (new portfolio), `⌘W` (close current sheet), `⌘,` (settings), `⌘F` (search/typeahead), `Return` to commit forms, `Esc` to dismiss sheets, arrow-key + `Space`/`Return` for list navigation. Must declare via `.keyboardShortcut` modifiers and surface in a `UIMenuBuilder`/`commands { }` menu so Discoverability (long-press ⌘) shows them.
- **Stage Manager + multitasking behavior:** Every screen must remain usable across the four characteristic widths — Slide Over (~320pt), iPhone-equivalent compact, iPad regular, and Stage Manager resized. No fixed widths, no horizontal scroll fallbacks for primary content. Snapshot/charts screens are highest-risk.
- **Onboarding disclaimer gate (#124):** First-run disclaimer should be a **full-screen cover with no swipe-to-dismiss** until acknowledged (it's a gate, not optional info). Re-display from Settings should use a regular sheet. These two presentations look similar in code — easy to get wrong.
- **App icon + SF Symbols:** App icon must ship as a single 1024 universal asset, no transparency, no pre-applied corner mask, contents within HIG safe area. SF Symbols should use semantic names and weights consistent with surrounding text; no custom-rendered glyphs where a system symbol exists (e.g., favor `chart.line.uptrend.xyaxis`, `arrow.up.arrow.down`, `gear`).

### 6. Open questions for Tess / Danny
- **Snapshot review presentation (#132):** Push vs. modal sheet? My reading is push (same hierarchy), but Tess may be designing it as a presented detail. Need a decision logged in `.squad/decisions.md`.
- **Settings entry point on iPad (#133):** Toolbar gear button on Portfolio List sidebar, *or* a pure `⌘,` keyboard-shortcut entry, *or* both? HIG allows either; pick one for v1.
- **Typography deviation (#126, #132):** Existing user directive (2026-05-12) permits Manrope / Work Sans / IBM Plex Sans for scaffolding instead of SF Pro. HIG defaults to system fonts for legibility + Dynamic Type behavior. Need Tess to confirm whether non-SF fonts persist into the shipped MVP, and how Dynamic Type scaling is handled — this becomes an explicit HIG deviation entry I will need to document.
- **Empty-state CTA wording on Portfolio List:** Spec says "Create Your First Portfolio." HIG prefers concise verb-led labels. Tess to confirm copy stays at this length on compact widths.
- **Forced-update screen (`ForcedUpdateView`/`ForcedUpdateFeature`):** Not in any v1 issue I can see — what triggers it, and how is it presented? If it's a hard gate, full-screen cover is correct; if it's advisory, an alert/banner. Need clarification from Danny on intended UX.
- **Charts color semantics in dark mode (#132):** `appPositive` / `appNegative` resolve to lighter pastel tones in dark mode for contrast — need Tess to confirm those are the chart series colors (vs. system green/red) and that chart legends carry text labels (HIG: "Don't rely on color alone").
- **TCA migration impact on review cadence (#145):** When child issues land, every Feature file in `app/Sources/App/AppFeature/**` will churn. Coordinate with Danny on whether HIG re-audit is per-feature or one sweep at the end of the migration.

---

## Cycle #41 — 2026-05-16T00:47:17Z (Specialist Parallel Loop)

**Window:** `98424f0..9ba571e` (prior anchor → HEAD at cycle start). Commits in window: 2 — `9e344ad` (saul cycle #40 history), `9ba571e` (nagel cycle #40 history). Both are `.squad/agents/*/history.md` appends only.

### Window scan — CLEAN
- `git --no-pager diff --stat 98424f0..HEAD` → 3 files, all under `.squad/agents/{frank,nagel,saul}/`. **Zero touches** under `app/` or `docs/`.
- `git --no-pager diff 98424f0..HEAD -- app/ docs/` → empty (0 bytes).
- Therefore no new modality, navigation, toolbar, SF Symbol, app-icon, or `Info.plist` delta in window.

### Roster reconciliation — 16 → 15 (delta −1)
- Cycle #39 close: 16 open `squad:turk`. Current `gh issue list --label squad:turk --state open` → 15 open.
- **Closed in window:** **#328** `hig(alerts): ContributionResultView uses a modal alert to confirm a successful save`.
  - Closed at 2026-05-16T00:45:46Z by **PR #509** (`hig(alerts): replace ContributionResultView success modal with inline 'Saved' badge + AT announcement`), merged 00:45:45Z onto `main` (merge commit `f5cba107`).
  - Note: PR #509 merge commit is **not yet fetched** into this worktree's main (still at 9ba571e); the closure is visible on GitHub but the new "inline Saved badge" code is not yet in window-diff scope. Will re-audit the post-#509 code path in the next cycle once main advances.
- #459 (launch screen) was already attributed to cycle #39 closure (closed 00:03:53Z, pre-cycle-39-log timestamp 00:22:37Z) — not double-counted here.
- Remaining 15 open: #222, #231, #234, #259, #291, #300, #319, #320, #323, #341, #358, #360, #373, #376, #403.

### Four-issue regression watchlist — 4/4 PASS

| # | Concern | HIG section | Evidence (file:line at HEAD 9ba571e) | Result |
|---|---|---|---|---|
| #389 | Destructive delete uses `.confirmationDialog` (not `.alert`) | HIG → Alerts ("use alerts sparingly"; destructive confirmations use action sheets / confirmation dialogs) | `app/Sources/Features/ContributionHistoryView.swift:92` `.confirmationDialog(…)`; reducer plumb at `PortfolioListFeature.swift:28` and `SettingsFeature.swift:78` doc-comments | **PASS** |
| #361 | Sheet roots pinned to `.inline` title | HIG → Navigation Bars (sheets present compact context; inline title preserves vertical space) | `app/Sources/Features/PortfolioEditorView.swift:50` + `HoldingsEditorView.swift:491` both `.navigationBarTitleDisplayMode(.inline)` | **PASS** |
| #426 | `readableContentMaxWidth` cap on iPad detail body | HIG → Layout (cap measure at readable width on wide canvases) | `app/Sources/App/DesignSystem.swift:31` `static let readableContentMaxWidth: CGFloat = 600`; consumed at `ContributionResultView.swift:43` + `PortfolioDetailView.swift:71` via `.frame(maxWidth: AppLayoutMetrics.readableContentMaxWidth, alignment: .leading)` | **PASS** |
| #471 | Settings → Erase All My Data reroutes **in-process** (no force-quit instruction) | HIG → Launching → Quitting ("never tell people to quit or relaunch") | `app/Sources/App/AppFeature/AppFeature.swift:100-106` intercepts `.destination(.main(.settings(.delegate(.dataErased))))` and reroutes to welcome; `SettingsAccessibility.swift:39-42` documents post-#471/PR #475 swap of force-quit copy; `SettingsFeature.swift:126-129` doc-comment confirms `dataErased` programmatic dispatch | **PASS** |

### Adjacent-surface scan — clean (as expected for history-only window)
- `git --no-pager diff 98424f0..HEAD -- app/` → empty. No new `.confirmationDialog`, `.alert`, `.sheet`, `.fullScreenCover`, `.navigationBarTitleDisplayMode`, `.toolbar`, SF Symbol substitution, app-icon variant, or `Info.plist` mutation introduced in window. Verified by inspection: window diff touches only `.squad/agents/{frank,nagel,saul}/`.
- Total `.confirmationDialog | .alert( | .sheet( | .fullScreenCover | navigationBarTitleDisplayMode` occurrences across `app/Sources` at HEAD = 21 — same set audited in cycle #39; no delta.

### Deferred raster `AppLogoMark` — still OUT-OF-LANE
- `AppLogoMark` remains a SwiftUI gradient vector at `app/Sources/App/AppBrand.swift:7` (consumed at line 84 by `AppBrandHeader`); no migration to raster asset.
- Issue search `gh issue list --state all --search "AppLogoMark in:title,body"` returns only #346 (closed, Yen lane — smart-invert), #326 (closed, Yen lane — brand-header subtitle), #366 (open, Yen lane — increase-contrast), #459 (closed, Turk lane — launch screen). **No open issue carrying the deferred raster decision exists on the Turk lane** — correctly sitting with Tess (design system) / Basher (asset catalog). Not filing under `squad:turk`.

### Duplicate-check — N/A (NO_OP cycle)
- No new finding to file (window is history-only, watchlist 4/4 PASS, adjacent scan clean). Duplicate-check normally required only before filing; documented here for completeness:
  - Watchlist coverage probed with `grep -RIn` in `app/Sources` for `confirmationDialog`, `navigationBarTitleDisplayMode`, `readable`, `Erase|forceQuit|relaunch|reopen` — all evidence still present.
  - AppLogoMark probe via `gh issue list --search "AppLogoMark in:title,body"` confirmed no Turk-lane duplicate would be needed even hypothetically.

### Filing decision: **NO_OP**
- Rationale: window diff is empty for `app/` and `docs/`; the only behavioral movement (#328 → PR #509) closed cleanly with no Turk-lane regression and the merge commit hasn't yet entered this worktree's main, so any audit of the post-PR-#509 inline-saved-badge surface is deferred to the next cycle when HEAD advances past `f5cba107`. No new HIG finding warranted.

### Carry-forward to cycle #42
1. Re-audit `ContributionResultView` post-PR-#509: confirm the "Saved" inline badge is `Label`-shaped (icon+text, not color-only), respects Dynamic Type, and is announced via `AccessibilityNotification.Announcement` (co-sign with Yen) — HIG → Feedback ("communicate state changes without interrupting").
2. Watchlist now 4 items — all PASSing as of cycle #41. Continue per-cycle.
3. Deferred raster `AppLogoMark` decision: still Tess/Basher-owned; revisit only if they file a design-system issue tagging `squad:turk`.

### New learning
When a PR merges on GitHub between orchestrator anchor and cycle spawn but the merge commit hasn't been pulled into the local worktree, `gh issue list` will report the issue as closed while `git diff` against the orchestrator anchor will show no code delta. Reconcile both views explicitly — count the closure against the GitHub-side roster, but defer code-side regression audit to the next cycle when the merge commit enters HEAD.
