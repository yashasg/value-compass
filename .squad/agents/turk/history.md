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

---

## Cycle #42 — 2026-05-16T01:20:31Z (Specialist Parallel Loop)

**HEAD at cycle spawn:** `1662b32` (`chore(turk): cycle #41 history`).

**Window picked:** `1662b32..HEAD` — Turk's prior-cycle anchor → HEAD. Rationale: chose the tightest evidence-backed window. The orchestrator-anchor window `98424f0..HEAD` was also considered; it contains 4 commits but all are `.squad/agents/{saul,nagel,yen,turk}/history.md` appends — already audited for code impact at cycle #41. No need to re-scan.

### Window scan — EMPTY (0 commits)
- `git --no-pager log 1662b32..HEAD --oneline` → empty.
- `git --no-pager diff --stat 1662b32..HEAD` → empty.
- HEAD is exactly at `1662b32` (Turk's own cycle #41 commit). No UI / `Info.plist` / `Assets.xcassets` / SF Symbol delta to classify.

### Off-window GitHub-side movement (roster reconciliation, not window-audit)
Two PRs merged on `origin/main` between cycle #41 spawn and cycle #42 spawn, but their merge commits are **not yet ancestors of local HEAD** (`git merge-base --is-ancestor` returns false for both):
- **PR #512** `hig(context-menus): mirror swipe Edit/Delete as .contextMenu on PortfolioList + ContributionHistory rows (closes #341)` — merged 2026-05-16T01:03:06Z, merge commit `ec23e07`. → closed #341.
- **PR #507** `hig(motion): animate OnboardingView disclaimer→setup-intro swap with forward-navigation transition (closes #360)` — merged 2026-05-16T00:53:25Z, merge commit `2e69ed0`. → closed #360.
- Cycle #41's deferred audit (PR #509 `f5cba10` — ContributionResultView inline 'Saved' badge) is **still off-HEAD** (`git merge-base --is-ancestor f5cba107 HEAD` = false). No code-side regression audit possible this cycle either.

### Roster reconciliation — 15 → 13 (delta −2)
- Cycle #41 close: 15 open `squad:turk`. Live `gh issue list --label squad:turk --state open --limit 200` → 13 open.
- **Closed in window:** #341 (PR #512, completed), #360 (PR #507, completed) — confirmed via `gh issue view {n} --json closedAt,stateReason`.
- **Remaining 13 open:** #222, #231, #234, #259, #291, #300, #319, #320, #323, #358, #373, #376, #403.

### Four-issue regression watchlist — 4/4 PASS at HEAD `1662b32`

| # | Concern | HIG section | Evidence (file:line at HEAD 1662b32) | Result |
|---|---|---|---|---|
| #389 | Destructive delete uses `.confirmationDialog` (not `.alert`) | HIG → Alerts ("use alerts sparingly"; destructive confirmations belong in confirmation dialogs / action sheets) | `app/Sources/Features/SettingsView.swift:76` `.confirmationDialog(`; `app/Sources/Features/HoldingsEditorView.swift:551` `.confirmationDialog(`; companion site `app/Sources/Features/ContributionHistoryView.swift:92` `.confirmationDialog(` (PR #488 closure) | **PASS** |
| #361 | Sheet roots pinned to `.inline` title | HIG → Navigation Bars (sheets present compact context; inline title preserves vertical space) | `app/Sources/Features/PortfolioEditorView.swift:50` + `HoldingsEditorView.swift:491` both `.navigationBarTitleDisplayMode(.inline)` | **PASS** |
| #426 | `readableContentMaxWidth` cap on iPad detail body | HIG → Layout (cap measure at readable width on wide canvases) | `app/Sources/App/DesignSystem.swift:31` `static let readableContentMaxWidth: CGFloat = 600`; consumed at `ContributionResultView.swift:43` + `PortfolioDetailView.swift:71` via `.frame(maxWidth: AppLayoutMetrics.readableContentMaxWidth, alignment: .leading)` | **PASS** |
| #471 | Settings → Erase All My Data reroutes **in-process** (no force-quit instruction) | HIG → Launching → Quitting ("never tell people to quit or relaunch") | `app/Sources/App/AppFeature/AppFeature.swift:100-101` intercepts both `.destination(.main(.settings(.delegate(.dataErased))))` and the `MainFeature.path` element variant; `MainFeature.swift:25-27` + `:168` doc-confirm path-scoped propagation (PR #482 #480 closure); `SettingsFeature.swift:392` emits `.send(.delegate(.dataErased))` after Keychain wipe (file moved to `app/Sources/App/AppFeature/SettingsFeature.swift` since spawn-prompt citation — same evidence, current path) | **PASS** |

### Adjacent HIG-surface regression scan — N/A in window
- Window diff is empty (0 commits). No new `.confirmationDialog`, `.alert`, `.sheet`, `.fullScreenCover`, `.navigationBarTitleDisplayMode`, `.toolbar`, SF Symbol substitution, app-icon variant, launch screen change, or `Info.plist` mutation introduced. Confirmed by inspection.

### Dedup search — N/A (no candidate finding)
No new finding to file: window is empty, watchlist 4/4 PASS, no adjacent code mutation to scan. Per cycle #41 carry-forward, the deferred `ContributionResultView` post-PR-#509 audit (Label-shape / Dynamic Type / `AccessibilityNotification.Announcement` co-sign with Yen) is **still deferred** because merge commit `f5cba107` has not entered local HEAD.

### Filing decision: **NO_OP**
- Rationale: zero code delta in window; watchlist 4/4 PASS; two off-HEAD closures (#341, #360) provide roster movement only, no Turk-lane regression evidence; one deferred audit (PR #509 → #328) still awaiting HEAD advance.

### Carry-forward to cycle #43
1. **Post-PR-#509 audit (still deferred):** Re-audit `ContributionResultView` once merge commit `f5cba107` enters local HEAD. Verify the new "Saved" badge is `Label`-shaped (icon + text, not color-only), respects Dynamic Type, and is announced via `AccessibilityNotification.Announcement` — HIG → Feedback ("communicate state changes without interrupting"). Co-sign with Yen.
2. **Post-PR-#512 audit (new this cycle):** Once `ec23e07` enters HEAD, verify the new `.contextMenu` on `PortfolioListView` + `ContributionHistoryView` rows mirrors `.swipeActions` semantics (Edit + Delete with destructive role), is reachable via pointer hover + long-press, and doesn't break pre-existing pointer-interaction work pending in #234 — HIG → Context Menus ("mirror swipe actions; provide consistent affordance across pointer and touch").
3. **Post-PR-#507 audit (new this cycle):** Once `2e69ed0` enters HEAD, verify the `OnboardingView` disclaimer→setup-intro transition uses a forward-direction motion (push/asymmetric slide), respects `accessibilityReduceMotion`, and doesn't conflict with the disclaimer-as-gate `fullScreenCover` pattern (#124) — HIG → Motion ("use motion to clarify navigation; honor Reduce Motion").
4. Watchlist remains 4 items (#389, #361, #426, #471) — all PASSing. Continue per-cycle.
5. Deferred raster `AppLogoMark` decision: still Tess/Basher-owned; revisit only if a design-system issue tagging `squad:turk` is filed.

### New learning
Off-HEAD merges accumulate when the local worktree's `main` lags origin between cycles. Track them by roster movement (gh-side) but defer code-side regression audit until the merge commit becomes an ancestor of HEAD — verified with `git merge-base --is-ancestor <merge-oid> HEAD`. This avoids citing line numbers against a tree we haven't seen, and avoids double-counting closures when the worktree finally catches up.

### Forward watch / handoff
Pipeline of 3 deferred post-merge audits (PR #509, #512, #507) — all stalled on local HEAD advance. Watchlist intact. No file requests.

(end Turk cycle #42)

---

## Cycle #43 — 2026-05-16T01:40:16Z (Specialist Parallel Loop)

**HEAD at cycle spawn:** `54d9df5` (`aso(frank): cycle #42 — full 6-peer probe restored ...`).
**Window:** `1662b32..54d9df5` (Turk cycle #42 anchor → HEAD) per orchestrator spawn instructions.

### Window scan — HISTORY-ONLY (6 commits, 0 code delta)
`git --no-pager log --oneline 1662b32..54d9df5`:
- `54d9df5` aso(frank): cycle #42 history
- `5e58594` research(saul): cycle #42 history
- `5f7e774` compliance(reuben): cycle #42 history
- `4eba7dd` chore(yen): cycle #42 history
- `5dd6585` chore(turk): cycle #42 history
- `0928cf8` chore(nagel): cycle #42 history

`git --no-pager diff --stat 1662b32..54d9df5` → 7 files, 677 insertions — **all** under `.squad/agents/{frank,nagel,reuben,saul,turk,yen}/`. Zero touches to `app/Sources/**`, `Info.plist`, `Assets.xcassets`, design-system primitives, or any HIG surface. No code-side regression possible by construction.

### Off-HEAD deferred audits — still stalled
All 3 carry-forwards from cycle #42 remain not-yet-ancestors of HEAD:
- `f5cba107` (PR #509, ContributionResultView 'Saved' badge → #328) — `git merge-base --is-ancestor` = NO.
- `ec23e07` (PR #512, `.contextMenu` mirror → #341) — NO.
- `2e69ed0` (PR #507, OnboardingView motion → #360) — NO.

Local worktree still lags origin/main on these three merges. Audits remain deferred; no line-number citations possible against a tree that's not in HEAD.

### Four-issue regression watchlist — 4/4 PASS at HEAD `54d9df5`

| # | Concern | HIG section | Evidence (file:line at HEAD 54d9df5) | Result |
|---|---|---|---|---|
| #389 | Destructive delete uses `.confirmationDialog` (not `.alert`) | HIG → Alerts (destructive confirmations belong in confirmation dialogs / action sheets) | `app/Sources/Features/SettingsView.swift:76` `.confirmationDialog("Erase All My Data?",`; `app/Sources/Features/HoldingsEditorView.swift:551` `.confirmationDialog("Discard Changes?",` | **PASS** |
| #361 | Sheet roots pinned to `.inline` title | HIG → Navigation Bars (sheet compact context) | `app/Sources/Features/PortfolioEditorView.swift:50` `.navigationBarTitleDisplayMode(.inline)`; `app/Sources/Features/HoldingsEditorView.swift:491` `.navigationBarTitleDisplayMode(.inline)` | **PASS** |
| #426 | `readableContentMaxWidth` cap on iPad detail body | HIG → Layout (cap measure at readable width) | `app/Sources/Features/ContributionResultView.swift:43` `.frame(maxWidth: AppLayoutMetrics.readableContentMaxWidth, alignment: .leading)` | **PASS** |
| #471 | Settings → Erase routes in-process (no force-quit instruction) | HIG → Launching → Quitting ("never tell people to quit or relaunch") | `app/Sources/App/AppFeature/AppFeature.swift:100–101` intercepts `.destination(.main(.settings(.delegate(.dataErased))))` + `MainFeature.path` element variant; `app/Sources/App/AppFeature/MainFeature.swift:25–27` doc-confirms compact toolbar path-scoping, `:168` `state.path.append(.settings(...))` for iPhone entry point; `app/Sources/App/AppFeature/SettingsFeature.swift:392` `return .send(.delegate(.dataErased))` after Keychain wipe | **PASS** |

### Adjacent HIG-surface regression scan — N/A in window
Window diff touches only `.squad/agents/**/history.md`. No `.confirmationDialog`, `.alert`, `.sheet`, `.fullScreenCover`, `.navigationBarTitleDisplayMode`, `.toolbar`, SF Symbol substitution, app-icon variant, launch screen change, or `Info.plist` mutation introduced. No new HIG surface to scan.

### Duplicate-check evidence (mandatory pre-filing audit, performed even though no candidate)
- `gh issue list --label "squad:turk" --state open --limit 200 --json number,title` → 13 open: #222, #231, #234, #259, #291, #300, #319, #320, #323, #358, #373, #376, #403.
- `gh issue list --label "squad:turk" --state closed --limit 20` → most-recent closures #486 (2026-05-15T23:05:56Z), #480, #471, #462, #459, #426, #414, #389, #361, #360. No new closures since cycle #42 close (#341/#360 already booked there).
- Roster delta vs cycle #42 close: **0** (13 → 13).

### Filing decision: **NO_OP**
- Rationale: window is pure cross-specialist history append; zero `app/Sources/**` delta; watchlist 4/4 PASS; roster unchanged; three deferred post-merge audits still stalled on local HEAD lag. No candidate finding → no `gh issue create` and no targeted dedup queries needed beyond the standing roster sweep.

### Carry-forward to cycle #44
1. **Three deferred post-merge audits** (all still off-HEAD): PR #509 (`f5cba107` → #328 'Saved' badge), PR #512 (`ec23e07` → context-menu mirror), PR #507 (`2e69ed0` → onboarding motion). Re-check ancestry at top of #44; perform whichever has entered HEAD.
2. Watchlist remains 4 items (#389, #361, #426, #471) — all PASSing. Continue per-cycle.
3. Deferred raster `AppLogoMark` decision: still Tess/Basher-owned.

### New learning
Three consecutive cycles (#41 history-only-window, #42 empty-window, #43 history-only-window) have produced NO_OP for Turk while origin/main has accepted at least 3 HIG-surface PRs. The local-worktree-lag pattern is now a stable signal, not noise: orchestrator-driven cycles increment faster than the worktree pulls. Tracking deferred audits by merge-oid (rather than issue number) ensures audits resume the moment HEAD advances, without needing a fresh dedup pass.

### Forward watch / handoff
Roster 13 stable. Three deferred PR audits queued. Watchlist 4/4 PASS. No file requests, no engineer routing.

(end Turk cycle #43)

---

## Cycle #44 — 2026-05-16T01:47:00Z (Specialist Parallel Loop)

**HEAD at cycle spawn:** `1110b0b` (`aso(frank): cycle #43 — full 6-peer probe LIVE …`).
**Window:** `c75460d..1110b0b` (cycle-#43 spawn-window oldest commit → HEAD) per orchestrator spawn instructions.

### Window scan — HISTORY-ONLY (6 commits, 0 product delta)
`git --no-pager log c75460d..1110b0b --oneline`:
- `1110b0b` aso(frank): cycle #43 history
- `9b9242c` research(saul): cycle #43 history
- `591ec81` compliance(reuben): cycle #43 history
- `f25c0ce` chore(turk): cycle #43 history (self)
- `cd4fecc` chore(yen): cycle #43 history
- `c75460d` chore(nagel): cycle #43 history *(window-inclusive at lower bound; same diff)*

`git --no-pager diff --stat c75460d..1110b0b` → 6 files, 425 insertions — **all** `.squad/agents/{frank,reuben,saul,turk,yen}/history.md` + one `.squad/agents/frank/inbox-saul-cycle-43.md`. Zero touches to `app/Sources/**`, `Info.plist`, `Assets.xcassets`, design-system primitives, SF Symbols, app icon, or any HIG surface. `git --no-pager diff c75460d..1110b0b -- 'app/Sources/**/*.swift' 'app/Sources/App/Info.plist'` → empty. No code-side regression possible by construction.

### Off-window: deferred post-merge audits now reachable
All three carry-forwards from cycle #43 are now ancestors of HEAD (`git merge-base --is-ancestor` = YES for all):
- `f5cba107` (PR #509, ContributionResultView 'Saved' badge → #328) ✅ ancestor
- `ec23e07` (PR #512, `.contextMenu` mirror → #341) ✅ ancestor
- `2e69ed0` (PR #507, OnboardingView motion → #360) ✅ ancestor

Audits performed below (one-time clearance pass; results then folded into the standing watchlist).

#### Deferred audit 1 — PR #509 / #328 (ContributionResultView 'Saved' badge): **PASS**
- `app/Sources/Features/ContributionResultView.swift:102-115` `private func savedBadge(_ summary:)` renders `Label(summary, systemImage: "checkmark.circle.fill")` (icon + text, *not* color-only) tinted with `Color.appPositive` inside an elevated `RoundedRectangle(cornerRadius: 12)`, identified `contribution.result.savedBadge`. **HIG → Feedback** — "communicate state changes without interrupting"; **HIG → Alerts** — "Avoid using an alert to communicate routine information."
- Site call at `:32-33` `if let savedSummary = store.saveConfirmation { savedBadge(savedSummary) }` — persistent inline cue replaces the dismissed `.alert("Result Saved", …)` modal.
- VoiceOver announcement parity (`appAnnounceOnChange(of: store.saveConfirmation)` at `:72-74`) is Yen-lane scope (#330 family); cited here for completeness, not re-graded.
- Verdict: **HIG-compliant from Turk lane.** Carry-forward cleared.

#### Deferred audit 2 — PR #512 / #341 (`.contextMenu` mirror): **PASS**
- `app/Sources/Features/PortfolioListView.swift:47-86` — every row pairs `.swipeActions(edge: .trailing, allowsFullSwipe: false) { Delete (destructive) / Edit }` with `.contextMenu { Edit / Delete (destructive) }`, both pulling titles + `systemImage` + role from `PortfolioRowContextActions` so swipe and pointer strings cannot drift.
- `app/Sources/Features/ContributionHistoryView.swift:52-86` — same pattern for the single `Delete` destructive action.
- **HIG → Context menus**: "When you provide a context menu for a list row, use the same actions you offer with swipe gestures so that people who can't perform a swipe gesture — for example, when using a pointer — can still access the actions." ✅ Mirror requirement met. Pointer (right-click / Control-click) + long-press touch users reach Edit/Delete parity with swipe.
- Adjacent watch: pointer hover effects on the rows themselves (#234) remain open; the context-menu mirror does not regress or substitute for that work.
- Verdict: **HIG-compliant from Turk lane.** Carry-forward cleared.

#### Deferred audit 3 — PR #507 / #360 (OnboardingView motion): **PASS**
- `app/Sources/Features/OnboardingView.swift:38` `@Environment(\.accessibilityReduceMotion) private var reduceMotion`; `:93-101` `stepTransition` returns `.opacity` when Reduce Motion is on, else `.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))` — the HIG-canonical forward-navigation direction.
- `:52, :54` both conditional branches apply `.transition(stepTransition)`; enclosing `.animation(.easeInOut(duration: 0.3), value: store.hasAcknowledgedDisclaimer)` drives the swap (≤ 0.35 s, within HIG short-transition guidance).
- **HIG → Foundations → Motion**: "Use motion to clarify navigation" + "Honor the Reduce Motion accessibility setting." ✅ Both prongs met (forward-direction slide + reduce-motion fallback to cross-fade).
- No conflict with the disclaimer-as-gate `fullScreenCover` pattern (#124): the transition is *intra*-cover (between two child views), not a cover dismissal.
- Verdict: **HIG-compliant from Turk lane.** Carry-forward cleared.

### Standing watchlist — 5/5 PASS at HEAD `1110b0b`
(Added #459 — launch-screen — to the standing set now that its anchor is stable on `main`.)

| # | Concern | HIG section | Evidence (file:line at HEAD 1110b0b) | Result |
|---|---|---|---|---|
| #389 | Destructive delete uses `.confirmationDialog` (not `.alert`) | HIG → Alerts (destructive confirmations belong in confirmation dialogs / action sheets) | `app/Sources/Features/SettingsView.swift:76` `.confirmationDialog(`; `app/Sources/Features/HoldingsEditorView.swift:551` `.confirmationDialog(`; `app/Sources/Features/ContributionHistoryView.swift:118` `.confirmationDialog(` | **PASS** |
| #361 | Sheet roots pinned to `.inline` title | HIG → Navigation Bars (sheet compact context) | `app/Sources/Features/PortfolioEditorView.swift:50` `.navigationBarTitleDisplayMode(.inline)`; `app/Sources/Features/HoldingsEditorView.swift:491` `.navigationBarTitleDisplayMode(.inline)` | **PASS** |
| #426 | `readableContentMaxWidth` cap on iPad detail body | HIG → Layout (cap measure at readable width) | `app/Sources/App/DesignSystem.swift:31` `static let readableContentMaxWidth: CGFloat = 600`; consumed at `ContributionResultView.swift:46` + `PortfolioDetailView.swift:71` via `.frame(maxWidth: AppLayoutMetrics.readableContentMaxWidth, alignment: .leading)` (CRV citation shifted 43→46 vs cycle #43 due to PR #509 Saved-badge insertion — same anchor, same modifier) | **PASS** |
| #471 | Settings → Erase routes in-process (no force-quit instruction) | HIG → Launching → Quitting ("never tell people to quit or relaunch") | `app/Sources/App/AppFeature/AppFeature.swift:100-101` intercepts `.destination(.main(.settings(.delegate(.dataErased))))` + `MainFeature.path` element variant; `app/Sources/App/AppFeature/MainFeature.swift:27, :168` doc-confirm compact-toolbar path-scoping; `app/Sources/App/AppFeature/SettingsFeature.swift:392` `return .send(.delegate(.dataErased))` after Keychain wipe | **PASS** |
| #459 | `UILaunchScreen` populated (non-empty dict so cold start renders brand color) | HIG → Launching → Launch Screens ("design a launch screen that looks like the first screen of your app") | `app/Sources/App/Info.plist:38-42` `<key>UILaunchScreen</key><dict><key>UIColorName</key><string>AppBackground</string></dict>`; asset `app/Sources/Assets/Assets.xcassets/AppBackground.colorset` exists | **PASS** |

### Adjacent HIG-surface regression scan — N/A in window
Window diff is pure cross-specialist `.squad/agents/**/history.md` + one inbox markdown. No `.confirmationDialog`, `.alert`, `.sheet`, `.fullScreenCover`, `.navigationBarTitleDisplayMode`, `.toolbar`, SF Symbol substitution, app-icon variant, launch-screen change, `Info.plist` mutation, sheet-detents change, navigation push/pop, or raster-vs-SF-Symbol swap introduced. No new HIG surface to scan.

### Duplicate-check evidence (standing roster sweep; no candidate to file)
- `gh issue list --label squad:turk --state open --limit 200 --json number` → 13 open: `[222, 231, 234, 259, 291, 300, 319, 320, 323, 358, 373, 376, 403]`. Identical to cycle #43 close.
- `gh issue list --label squad:turk --state closed --limit 12 --json number,title,closedAt` → most-recent closures (post cycle #42 booking): #486, #480, #471, #462, #459, #426, #414, #389, #361, #360, #341, #328. No new closures since cycle #43 close — #341/#360/#328 already booked off-HEAD at cycle #42; everything older already booked.
- Roster delta vs cycle #43 close: **0** (13 → 13).
- No candidate finding generated this cycle (window product-empty + deferred audits all PASS). Per loop strategy, ≥ 3 keyword sweeps are required *when considering filing*; not triggered here.

### Filing decision: **NO_OP**
- Rationale: window is pure cross-specialist history append (0 `app/Sources/**` delta); three previously-deferred post-merge audits all PASS with high-quality HIG-compliant fixes; standing watchlist now 5/5 PASS (adding #459 launch-screen anchor); roster steady at 13. No code regression evidence anywhere. No `gh issue create` and no `gh issue comment` warranted.

### Carry-forward to cycle #45
1. **All three cycle-#43 deferred audits cleared** (PR #509/#328, PR #512/#341, PR #507/#360 — each one PASS at HEAD 1110b0b). Drop them from the queue.
2. **Standing watchlist expanded to 5 items**: #389, #361, #426, #471, **#459** (added). Continue per-cycle ancestor grep.
3. **PR #514** (`7f1622c` — ProgressView a11y labels → #371) — explicitly Yen-lane scope; Turk does not audit. Noted for Yen handoff only.
4. Deferred raster `AppLogoMark` decision: still Tess/Basher-owned; revisit only if a design-system issue tagging `squad:turk` is filed.

### New learning
The local-worktree-lag pattern (cycle #41–#43 NO_OPs on history-only windows while origin/main quietly accepted HIG-surface PRs) self-resolved at cycle #44: orchestrator advanced HEAD past the three queued merge commits in one step, and the deferred audit queue cleared in a single cycle. Validates the cycle-#42 learning — "track deferred audits by merge-oid, not issue number" — because three different issue numbers (#328/#341/#360) cleared via a single ancestry recheck at cycle top, with zero need to re-derive line citations from scratch.

### Forward watch / handoff
Roster 13 stable. Standing watchlist 5/5 PASS. Deferred-audit queue empty. No file requests, no engineer routing, no cross-lane co-signs needed.

(end Turk cycle #44)
