# Saul — History

## Project Context

- **Project:** value-compass
- **Hired by:** yashasg
- **Joined:** 2026-05-15
- **Role:** Market Researcher

## Tech Stack & Domain Snapshot (day 1)

- **App:** Value Compass — local-first iOS/iPadOS portfolio analysis tool. v1 ships without a server.
- **Core proposition:** Lets users assign categories to holdings and see how each category contributes to portfolio behavior (the VCA algorithm).
- **Backend:** Python/FastAPI exists but is unused in v1.
- **User segment hypothesis:** DIY investors who maintain their own portfolios across brokerages and want a category-level lens that brokerage apps don't provide.

## Competitive Landscape (starter list — to be expanded)

- **Personal Capital / Empower** — net-worth + investment dashboards
- **Sigfig, Wealthfront, M1 Finance** — robo-advisor flavored
- **Snowball, Delta, Yahoo Finance** — portfolio-tracking apps
- **Brokerage native apps** (Schwab, Fidelity, IBKR) — single-account views

The category-weight contribution lens is Value Compass's differentiator. My job is to validate that and find the user who needs it.

## Outputs the team expects from me

- Market briefs (PDF or markdown)
- Competitive teardowns (per-app)
- Persona docs (1-pager each)
- Positioning statement drafts
- Pricing recommendations (when monetization comes up)

## Learnings

_(to be appended as I do work)_


**2026-05-15 — Cross-Agent Update:** Team:* label scheme is live on GitHub (team:frontend, team:backend, team:strategy). All 14 open issues triaged. See .squad/decisions.md for the triage map and rationale.

## Onboarding — 2026-05-15

### 1. Product in one paragraph (in my voice — market positioning lens)

Value Compass is a local-first iOS/iPadOS portfolio analysis tool for self-directed investors who already maintain a multi-category portfolio across brokerages and want to practice **value cost averaging (VCA)** — i.e. compute "how much should I put into each ticker this month" given a budget, category weights, and a moving-average signal (`docs/tech-spec.md:10-21`). It is aimed at the DIY investor who is past the robo-advisor stage but doesn't want a brokerage account aggregator or a social trading feed — they want a deterministic, auditable contribution number every period. The differentiator I would lead with in any competitive deck is **"your data never leaves the device, and the algorithm is yours to swap"** — the app exposes a `ContributionCalculating` protocol seam (`docs/tech-spec.md:181-214`) so the user owns the math, not us. No accounts, no cloud, no broker integration, no ads — that is the wedge against Personal Capital/Empower, M1, and the trackers. The narrow surface (one calculation, one history list, one disclaimer screen) is a feature, not a v1 cut.

### 2. Architecture facts that affect my market research

- **Local-first iOS 17+ / iPadOS 17+, SwiftData persistence, no server, no account, no network round-trip in v1** (`docs/tech-spec.md:6, 30-34, 116-128`). I can credibly claim "your portfolio data never leaves your device" — that is a first-class positioning lever vs. every cloud competitor.
- **The VCA algorithm is user-owned via the `ContributionCalculating` protocol** (`docs/tech-spec.md:181-214`). The app ships a default `MovingAverageContributionCalculator`, but the seam lets a sophisticated user drop in their own implementation. This is unusual in the consumer-finance space and is a positioning differentiator I should validate (most competitors hide the math behind a black box).
- **Market data is manually entered or stubbed in v1** — no live quotes, no broker linking (`docs/tech-spec.md:31, 218-230`). Means I cannot position against "real-time portfolio tracking" tools head-on; we are not in that race.
- **Mothballed in v1:** Python/FastAPI backend (`backend/`), Supabase sync, OpenAPI client (`app/Sources/Backend/Networking/`), market-data poller, push notifications (`docs/tech-spec.md:30-34, 343, 347-349`; `.squad/decisions.md` "_mothballed stream"). I must not market features that don't exist — no cloud sync, no multi-device, no notifications, no brokerage integration.
- **No encryption in v1** because "no sensitive financial data — just ticker symbols and target amounts" (`docs/tech-spec.md:127`). A privacy-conscious reviewer might still ask; positioning copy should explain this clearly rather than dodge it.
- **Single-device, append-only history** (`docs/tech-spec.md:34, 268-275`). Implication: I cannot promise "pick up where you left off on iPad" out of the box — history is per-device until sync ships.

### 3. V1 roadmap & scope boundaries

**Shipping in v1 (the work queue — `.squad/decisions.md` lines ~123–145, all currently open on GitHub):**

| Issue | Scope | Stream |
|---|---|---|
| #123 | SwiftData models for portfolios, market data, settings, snapshots | backend |
| #124 | Local-only app shell and onboarding gates | frontend + backend |
| #125 | Portfolio, category, and symbol-only holding editor | frontend + backend |
| #126 | Bundled NYSE equity + ETF metadata with typeahead | frontend + backend |
| #127 | Massive API key validation + Keychain storage | backend |
| #128 | Massive client + shared local EOD market-data refresh | backend |
| #129 | TA-Lib-backed TechnicalIndicators package | backend |
| #130 | Invest action with required capital + local VCA result | frontend + backend |
| #131 | Explicit Portfolio Snapshot save/delete | frontend + backend |
| #132 | Snapshot review + per-ticker Swift Charts | frontend |
| #133 | Settings, API key management, preferences, full local reset | frontend + backend |
| #134 | iPhone NavigationStack + iPad NavigationSplitView workspace | frontend |
| #135 | MVP integration + regression test pass | frontend |
| #145 | P0 migrate the app from MVVM to TCA | frontend + backend |

Note: #127–#129 reveal that v1 actually does ship a market-data path (Massive API key + EOD refresh + TA-Lib indicators), which is *richer* than the tech-spec's "manual entry only" framing. That tension — manual-entry-only spec vs. Massive-API-backed reality — is something I should flag to Danny; it matters for positioning ("offline" vs. "BYO data source").

**Explicitly NOT in v1** (`docs/tech-spec.md:25-35`; `.squad/decisions.md` mothballed paths):
- Cloud sync / multi-device (Supabase, OpenAPI client, server-side poller)
- User accounts / login / social
- Push notifications (no APNs)
- Brokerage integration / live trading / order placement
- Per-ticker weight customization (equal-split within category only)
- Monetization (no IAP, no subscription, no ads — pricing is unspecified)
- Live brokerage-grade strategy tuning (deferred to post-MVP feedback, Issue #15)

**When I'd revisit pricing/monetization research:** when (a) Danny opens a "post-v1 monetization" planning issue, OR (b) the team starts scoping cloud sync (the natural paid-tier wedge), OR (c) TestFlight feedback signals willingness-to-pay. Until then, freemium-vs-one-time-purchase analysis is premature — there is no payment surface to position against.

### 4. My role given this product

**Competitive set (with local-first vs cloud flag):**

| Competitor | Posture | Local-first? | Notes |
|---|---|---|---|
| Personal Capital / Empower | Net-worth + portfolio dashboards | ❌ Cloud, account-required | Aggregator model — orthogonal to us, but often cited by the same persona |
| M1 Finance | Robo + brokerage + "pies" (category-weighted!) | ❌ Cloud, account + broker | Closest UX cousin (category weights → allocations) but they own the brokerage |
| Sigfig / Wealthfront | Robo-advisor | ❌ Cloud, account-required | Different segment (hands-off); listed for landscape completeness |
| Snowball Analytics | Dividend / portfolio tracker | ❌ Cloud sync | Mid-market DIY tracker |
| Delta (eToro) | Crypto + equities tracker | ❌ Cloud | Mobile-first, social-flavored |
| Yahoo Finance | Free portfolio tracker + news | ❌ Cloud, account-optional | The default "free" baseline — what we have to be obviously better than |
| Brokerage native apps (Schwab/Fidelity/IBKR) | Single-account views | Account-bound | Don't offer cross-broker category lens |
| Stock Rover / Portfolio Visualizer (web) | Analytics-heavy | ❌ Web/cloud | Closer to us on "you do the analysis" ethos |

I do not yet know of a true local-first iOS competitor in this niche — that's a hypothesis to test, not a claim. If confirmed, "the only local-first VCA tool on iOS" is a defensible category-of-one positioning.

**Persona work — three candidate ICPs to size and rank:**
1. **DIY investor (broad)** — manages own portfolio, multi-broker, comfortable with spreadsheets. Largest TAM, weakest pull (the spreadsheet works fine).
2. **Hobbyist quant / strategy tinkerer** — wants to plug their own algorithm into something with a UI. Smallest TAM, strongest pull on the `ContributionCalculating` seam.
3. **Semi-pro / RIA-adjacent** — manages family or small-group money, needs auditability and offline-by-default for compliance comfort. Mid TAM, strong pull on local-first.

My v1 hypothesis (to validate, not assume): the **hobbyist quant / strategy tinkerer** is the v1 ICP — they are the only segment where the user-owned-algorithm seam is a buy reason rather than a curiosity. The DIY-investor segment is the *narrative* TAM; the hobbyist is the *buying* SAM. I need to confirm with Danny which ICP the team is actually building for — the spec doesn't name one.

**Positioning hypothesis to validate:** *"Privacy-first (local-only, no account, no cloud) + user-owned algorithm (you can swap the math) = the wedge."* Both legs need evidence. Privacy-first is well-trodden in messengers/note apps but unusual in fintech. User-owned algorithm is rare everywhere; risk is that it's a builder-team-only differentiator (the team finds it cool; users don't care).

### 5. Concrete market-research questions I should be ready to answer in v1

1. **What's the existing tool that DIY investors leave for us, and why?** (Spreadsheet? Yahoo Finance? M1 pies? A custom Python notebook?) The "switch-from" tells us the wedge feature, not the feature list.
2. **Is local-first a feature or a constraint in this segment?** I.e., does the target user actively prefer no-cloud, or do they accept it because the alternative is good enough? This determines whether "no cloud" is in the headline or in the FAQ.
3. **Does user-owned algorithm (the `ContributionCalculating` seam) matter to the persona, or is it a builder-team-only differentiator?** If only ~2% of users will ever swap the algorithm, we should still ship the seam (it's free architecture) but not lead the marketing with it.
4. **What's the App Store discovery story for a portfolio-analysis tool with no marketing budget?** Which keywords (likely "VCA", "value cost averaging", "portfolio rebalance", "investment calculator") are uncontested? Who currently ranks for them? (This feeds Frank — I supply intel, he writes copy.)
5. **What is the App Store pricing convention in this category** — free with in-app upgrade, one-time purchase ($4.99–$19.99), or subscription ($2.99–$9.99/mo) — and what does each price point signal to the DIY-investor persona? (For when monetization comes up post-v1.)
6. **Does the absence of brokerage integration disqualify us for the buying persona, or qualify us** (because the persona explicitly distrusts plaid/yodlee broker linking)?
7. **What's the credibility threshold?** A finance app from an unknown publisher — what does the persona need to see (open source? founder identity? methodology doc? academic citation of VCA?) before installing? This affects the disclaimer screen, the README, and the App Store description.
8. **TAM/SAM/SOM rough cut:** US self-directed investors with multi-broker portfolios on iOS — is this 100K, 1M, or 10M reachable users? Sizing determines whether v1 is a hobbyist labor of love or a real product line.

### 6. Open questions / things I noticed (gaps from a market-research lens)

- **No stated ICP anywhere.** `docs/tech-spec.md` describes the product but never names "the user." I am inferring DIY/hobbyist/semi-pro from the feature set. I should ask Danny to commit to one v1 ICP, even informally — copy and ASO can't be written without it.
- **No competitors named in any spec or decision.** The competitive list in my history file (above) is my own starter inventory, not validated by the team. I should produce a `docs/research/competitive-landscape.md` as a first deliverable.
- **Monetization is unspecified — not even "free, no IAP" is stated.** Need explicit confirmation that v1 is free / no IAP / no subscription, so I know what *not* to research now and what to queue for post-v1.
- **Tension between spec and v1 issues on market data.** `docs/tech-spec.md:31` says "Market data is entered manually or stubbed," but issues #127–#129 ship a Massive API client + EOD refresh + TA-Lib indicators. Positioning copy needs to resolve this: are we "fully offline" or "BYO market-data API key"? They lead to different headlines.
- **No mention of regulatory positioning anywhere.** A VCA / contribution-calculator app is firmly in the "general financial information, not advice" lane, but the line has to be drawn explicitly. That's Reuben's call (per my charter), but the disclaimer copy he produces will constrain what marketing claims I can make. I should sync with him before writing any positioning statement.
- **No user-research signal in the repo at all** — no interviews, no survey results, no competitor user-review scrapes. Everything to date is product-team intuition. Earliest concrete deliverable I can produce without budget: scrape App Store reviews of the competitive set for the recurring complaints, then map our v1 features against those complaints.
- **No distribution-channel thinking visible.** App Store + organic search is the implicit assumption. Worth confirming whether founder-led content (X/Reddit/Bogleheads/r/personalfinance) is on the table — that materially changes how I position the user-owned-algorithm story.
- **`docs/research/`, `docs/audits/`, `docs/legal/`, `docs/aso/` directories are referenced in `streams.json` but I haven't verified they exist.** First housekeeping task: confirm or create the strategy folder layout so my future deliverables have a home.

## Cycle 2026-05-15 #3

- **Lane:** competitor App Store review monitoring rescan (Snowball / Stock Events / Delta / M1 / Wealthfront).
- **Method:** iTunes Customer Reviews RSS rescan for the same five track IDs used in #253; cutoff 2026-05-01.
- **Finding:** No new reusable pain axis. Recent 1★/2★ reviews reconfirm existing #253 buckets (Delta forced-update/data-hostage; M1 fees; M1 schedule-override friction). One Delta Coinbase-connection failure is too isolated (1 review) to justify a fifth axis.
- **Action:** Commented on #253 with the rescan evidence; no new issue filed.
- **Dedup proof:** `gh issue list --state all --search "user-control"`, `"Delta"`, `"M1"`, `"Coinbase"`, `"positioning"` reviewed; closest open context was #253, with adjacent strategy context in #263, #277, #238, and #274. Decision: update #253, do not file new.

## Cycle 2026-05-15 #4

- **Axis explored:** positioning-coherence tension between #240 (Bogleheads/FIRE V1 launch persona) and #238 (user-pluggable VCA seam as headline). Bogleheads doctrine is passive / "stay the course" / anti-algorithm-swap (r/Bogleheads `public_description`, re-fetched 2026-05-15: subscribers 841,585); seam-led copy (`Your VCA, your rules`) targets the opposite tinkerer/quant psyche. Cannot lead with both in a 30-char subtitle.
- **Dedupe searches:** `opportunity in:title` (50), `positioning OR persona OR monetization` (30), `squad:saul --state all` (60), `pricing OR price` (30), `review OR press OR award OR editorial` (30), `retention OR engagement OR loop` (30), `coherence OR tension OR primacy OR contradict` (30), `Boglehead seam` (20), `tinkerer OR quant` (20). Reviewed: #238, #240, #241, #245, #246, #251, #253, #255, #261, #263, #269, #270, #277. No prior issue raises this primacy/coherence question.
- **Decision:** New issue filed → **#286** `positioning(coherence): Bogleheads ICP (#240) and pluggable-algorithm seam (#238) point to opposite storefront copy — Danny pick primacy`. Labels: `documentation`, `priority:p2`, `mvp`, `team:strategy`, `squad:saul`. Proposed three stances (A: Bogleheads-first / B: tinkerer-first / C: two-track first-run) with Saul recommending Stance A on TAM grounds; recommendation is a Danny decision, no implementation change requested.
- **Frank intake:** No new Frank handoff to process this cycle. `frank-category-and-preview-video.md` (#251/#255 — Frank kept storefront-only, no Saul issue needed) and `frank-version-notes-cadence-and-ratings-prompt.md` (#270 — already paired by Saul's #277) are both resolved.
- **Learning:** Two Saul-filed positioning issues can be individually valid yet collectively incoherent when the head-of-copy is a single 30-char field; need to audit *cross-issue* coherence before filing the next standalone positioning bet. Cross-issue audit should run when ≥2 open Saul issues touch the same storefront atom (#220/#245).

## Cycle 2026-05-15 #5

- **Axis explored:** activation-tier classification. Investrum's documented first-value path (disclaimer → portfolio create → manual price + MA entry → calculate, with the Massive API key prompt deferred to Settings per `docs/app-tech-spec.md:113-118` and `docs/app-tech-spec.md:173`) places Investrum in the manual-entry portfolio-tracker tier alongside Stock Events / Snowball Analytics — not the brokerage incumbent tier (M1 / Wealthfront) or the sync-anchored aggregator tier (Delta-by-eToro). Implication for Frank: narrow the storefront-comparison peer set across the existing #245/#246/#251/#274 work to the manual-entry-tracker tier.
- **Frank intake:** Processed `frank-ipad-screenshots-blueprint.md` (#284). Frank's drop is explicit: "light note (not a full handoff) — no positioning shift, Saul does not need to file a new opportunity issue — this is a capture-format axis, not a positioning axis." Disposition: acknowledged, no Saul issue filed for #284. Earlier inbox drops (`frank-category-and-preview-video.md` → #251/#255 and `frank-version-notes-cadence-and-ratings-prompt.md` → #270/#277) remain resolved from cycle #4. New Frank-filed issues since cycle #4 — #284 (iPad screenshots), #292 (app-icon competitive style scan) — were reviewed and confirmed as storefront-ops with no positioning ask for Saul.
- **Dedupe searches:** `threat`, `moat`, `incumbent`, `brokerage`, `M1`, `Wealthfront`, `Empower`, `pies`, `defensible`, `competitive-threat`, `feature-copy`, `onboarding`, `abandonment`, `API key`, `API-key`, `disclaimer`, `naming`, `Investrum`, `trademark`, `international`, `UK`, `EU`, `retention`, `engagement`, `activation`, `first-value`, `first value`, `step count`, `friction`, `tier`, `anchor`, `peer set`, `comparison`, `spectrum`, `no-account`, `manual-entry`, `byo`, `BYO`, `key prompt`, plus `--label squad:saul --state all`. Reviewed: #238, #240, #241, #245, #246, #251, #253, #255, #261, #263, #269, #270, #274, #277, #284, #286, #292, #294 (new), and #133, #233 for tech-spec alignment. Closest existing issue is #253 (no-account claim already filed) — this cycle scales that fact into a four-tier competitive map and a peer-set recommendation that #253 doesn't make.
- **Decision:** New issue filed → **#296** `opportunity(activation-tier): Investrum's no-account first-value path = manual-entry tracker tier (Stock Events/Snowball/Yahoo, 4.75–4.84★) — anchor storefront comparisons there, not brokerages (M1/Wealthfront/Delta)`. Labels: `documentation`, `priority:p2`, `mvp`, `team:strategy`, `team:frontend`, `squad:saul`. Three stances proposed (A: manual-tracker peer set / B: brokerage-alternative framing / C: aggregator framing). Saul recommends Stance A; Danny pick. Evidence cited: iTunes Lookup `description` + ratings for 6-app set (fetched 2026-05-15T19:42Z); `docs/app-tech-spec.md:113-118, 152, 173`; Massive homepage meta description (free tier confirmed; pricing-page limits not). Also called out the latent activation barrier: manual MA entry degrades at N≳5 tickers, so storefront should set "start manual, add free Massive key when you outgrow it" — avoid "no API key ever."
- **Inbox drop:** `.squad/decisions/inbox/saul-activation-tier-peer-set.md` — Saul→Frank handoff narrowing the peer set across #245/#246/#251/#274, plus a softening note on screenshot frame 3 caption claims. Secondary recipients: Danny (Stance pick), Tess (onboarding tone — same direction as #240/#253/#286, no new scope), Reuben (no compliance ask; #294 already aligned).
- **Learning:** A purely *evidence-classification* lane (tier the competitive set, recommend a peer subset) can produce an actionable Saul→Frank handoff without filing a "new" positioning bet. The four-tier map (manual-entry tracker / low-friction tracker / sync-aggregator / brokerage incumbent) is reusable scaffolding — promote to `docs/research/competitive-tiers.md` next cycle if Danny adopts Stance A on #296. Cross-issue coherence check (per cycle #4's learning): #296 reinforces #240 + #253 + #286 (Stance A is the consistent default across all three) and does not contradict #238 / #241; safe to file alongside the existing positioning stack.

## Cycle 2026-05-15 #6

- **Axis explored:** retention loop — monthly recalc as Investrum's native re-open trigger. First retention-axis issue in the Saul stack (gap identified during dedup sweep of `retention`, `engagement`, `monthly`, `recurring`, `cadence`, `reminder`, `notification`, `re-open`, `recalc`, `calendar`, `loop`, `paycheck`, `habit`, `weekly` — no prior open or closed issue in title space; #270 covers publisher-side cadence only).
- **Evidence chain:** Investrum is monthly-cadence by construction (`app/Sources/Backend/Services/ContributionCalculator.swift:16` requires `monthlyBudget`; `docs/tech-spec.md:14, 41`; `docs/app-tech-spec.md:82, 92, 117, 144`). v1 ships with no push (Reuben's #305 removes APNs onboarding prompt; `docs/tech-spec.md:26-33` confirms push deferred) and no account (#253 / `docs/app-tech-spec.md:113-118`). Retention surface must therefore be product-side / calendar-driven. Re-fetched iTunes Lookup for 6-app peer set (`Stock Events 1488720155`, `Snowball 6463484375`, `Delta 1288676542`, `Yahoo Finance 328412701`, `Wealthfront 816020992`, `M1 1071915644`; releases 2026-04-27 → 2026-05-13) — none anchor retention on "user-recomputes-monthly-target." Lane uncontested in segment.
- **Cross-issue coherence audit:** Reinforces #240, #253, #263, #269, #296, #301; neutral vs #238, #241, #277; non-contradictory with #286 (both Bogleheads and tinkerer stances accommodate monthly cadence). Safe to file.
- **Decision:** New issue → **#313** `opportunity(retention): monthly recalc as Investrum's native re-open loop — no push, no account, calendar-driven`. Labels: `documentation`, `priority:p2`, `mvp`, `team:frontend`, `team:strategy`, `squad:saul`. Three stances (A: surface-only / B: surface + EventKit / C: defer) — Saul recommends A. Cross-link comments posted on #270 (publisher/user analog) and #269 (methodology operationalizes via monthly cadence).
- **Inbox drop:** `.squad/decisions/inbox/saul-retention-loop-monthly-cadence.md` — Danny stance pick, Frank keyword fold-in for #245/#246/#251/#274 (only if Stance A), Tess home-screen affordance, Reuben (Stance B only).
- **Frank intake this cycle:** No new fold-in. Re-confirmed dispositions for `frank-app-icon-competitive-scan.md` (#292, "no Saul issue needed" per Frank), `frank-ipad-screenshots-blueprint.md` (#284, "capture-format axis only" per Frank), `frank-category-and-preview-video.md` (#251/#255, Frank storefront-only), and `frank-version-notes-cadence-and-ratings-prompt.md` (#270, now paired with #313 on user-side analog).
- **Dedupe proof:** searches `retention`, `engagement`, `monthly`, `recurring`, `cadence`, `reminder`, `notification`, `re-open`, `recalc`, `calendar`, `loop`, `paycheck`, `habit`, `weekly`, `locale`, `international`, `UK`, `EU`, `country`, `Europe`, `GDPR`, `currency`, `pricing`, `price`, `freemium`, `subscription` (each `in:title --state all --limit 8`) plus `--label squad:saul --state all --limit 50`. Reviewed: #238, #240, #241, #245, #246, #251, #253, #255, #261, #263, #269, #270, #274, #277, #284, #286, #292, #294, #296, #301, #305 (push removal confirms no-push retention surface). Closest existing was #270 (publisher-side What's New cadence) — #313 is the user-side analog, no overlap.
- **Honest evidence ceilings flagged in #313:** no Investrum telemetry; Stock Events' user-side cadence inferred from `description` + release-notes pattern; bogleheads.org 403 to bots (re-validate via #263 TestFlight); keyword-uncontested claim bounded to 6-app peer set (broader keyword sweep deferred next cycle).
- **Learning:** A *gap-driven* axis (sweep title space for missing axis names → file where the gap is real) is a faster path to a coherent issue than a *signal-driven* axis (chase the latest Frank intake). When the storefront-ops stream (Frank) is quiet, switch to gap analysis. Retention was the obvious missing axis after activation (#296), trust (#277), credibility (#269), persona (#240), and coherence (#286) were already filed.

## Cycle 2026-05-15 #7

- **Axis explored:** trust-commitment as a stated, enumerated, auditable indie-publisher artifact — distinct from #253 (analytical frame), #277 (response *playbook*), and #220 (storefront SoT surface). Filed in direct response to Frank's #312 review-mining cycle, which surfaced that the `support_response` ("dev never replies") bucket carries 12% of low-star segment complaints across the 6-app peer set (n=300 reviews / 132 ≤3★). Lane is uncontested — no segment competitor commits to a named-response SLA in storefront copy.
- **Frank → Saul intake (this cycle, primary):** `.squad/decisions/inbox/frank-review-response-templates.md` (Frank's #312) — *new* this cycle. Frank flagged three Saul-side implications: (a) 24h named-response SLA as positioning lever ("comment-fold into #240 or #253"); (b) Delta 2.08★ recent-50 collapse as cautionary tale for #241; (c) Snowball 4.66★ low complaint volume as north-star comp for the indie-tracker tier. Re-confirmed prior dispositions for the four older Frank drops (`frank-app-icon-competitive-scan.md`, `frank-ipad-screenshots-blueprint.md`, `frank-category-and-preview-video.md`, `frank-version-notes-cadence-and-ratings-prompt.md`) — no change.
- **Disagreement with Frank's "comment, don't file" call, declared:** Filed #322 anyway because the commitments block is a horizontal artifact spanning #240/#241/#253/#277 — couping it to any one of those issues makes the cross-axis coherence audit harder later. The increment over #277 is the public-commitment-before-any-review vs. response-tone-after-each-review split (different artifact, different audience, different time of effect). Filed honestly in #322's Caveats so Danny can overrule and collapse to a #277 comment if he prefers; revert cost = one issue close.
- **Decision:** New issue → **#322** `positioning(trust-commitment): convert #253 user-control axis into enumerated, auditable indie publisher commitments — segment shows 12% complaint share on 'developer ignores feedback' (#312 evidence)`. Labels: `documentation`, `priority:p2`, `mvp`, `team:frontend`, `team:strategy`, `squad:saul`. Six candidate commitments enumerated (24h named-response SLA — Danny operational decision; portfolio-data-local; no email / no signup; no analytics SDK / no ad SDK; BYOK Massive key Keychain-only; change-disclosure norm). Recommended minimum subset for v1.0 = #2–#6.
- **Comment-folds (no new issues):**
  - **#241** (BYOK monetization stance) — Delta cautionary tale: 2.08★ recent-50 average is 2.63 below the 4.71 all-time average, attributed by Frank's bucket regex to "Locked all my previous data behind a paywall" (v2025.6.0+). Operational rule: never retroactively gate previously-free functionality. Maps to #322's commitment #6 (change-disclosure norm).
  - **#296** (manual-entry tracker tier peer set) — Snowball 4.66 recent-50 (vs 4.84 all-time, only Δ=-0.18 in the peer set) is the indie north-star inside the manual-entry tier. Stock Events 4.24 recent-50 (Δ=-0.57) is the floor. Tier classification still holds; the named exemplar inside the tier should be Snowball, not three peers treated symmetrically.
- **Cross-issue coherence audit (per cycle #4 rule):** #322 reinforces #238, #240, #241, #253, #263, #277, #296. Neutral vs. #269, #286, #301, #313. No contradictions across the 11 open Saul issues. Safe to file.
- **Dedupe proof:** `gh issue list --search` runs on `trust-commitment`, `promise`, `publisher pledge`, `no ads`, `no email collected`, `no analytics`, `operational SLA`, `stated commitment`, `covenant`, `service commitment`, `no boilerplate`, `named response`, `support promise`, `publisher trust`, `publisher commitment`, `indie benchmark`, `SLA support response named developer 24 hour`, `Snowball benchmark`, `indie north-star`, `indie comp`, `north-star`, `paywall data hostage`, `Delta cautionary`, `monetization existing data`. Plus `--label squad:saul --label team:strategy --state all --limit 30`. Reviewed open + closed sets. The closest existing was #277 (response *template* doc) and #220 (storefront SoT surface) — both materially different scope; #322 increment is the *public commitment artifact*, not the *internal template* and not the *file layout*.
- **Persona-shift check (required by cycle ask):** No. `docs/tech-spec.md` and `docs/app-tech-spec.md` unchanged since my onboarding pass (last edits to spec docs are 2025-08 / 2025-11 per `git log -- docs/`; recent commits since 2026-05-12 are all HIG / a11y / compliance / SwiftData contract polish, e.g. #297 / #290 / #289 / #288 / #281 / #280 / #279 / #278 / #276 / #273 / #267 / #266 / #265 / #264 / #248 / #247 / #230 / #221 — none touch persona/positioning copy). The Bogleheads/FIRE ICP hypothesis with the unresolved #286 primacy debate is the operative state. No new persona issue warranted.
- **Inbox drop:** `.squad/decisions/inbox/saul-trust-commitment-storefront-block.md` — primary recipient Danny (six-commitment subset pick + 24h SLA operational decision), secondary Frank (storefront execution after Danny decides; no new Frank issue requested), tertiary Reuben (compliance gate on commitment phrasings), tertiary Tess (in-binary About row, ~1–2h frontend).
- **Honest evidence ceilings flagged in #322:** 12% is share *within* the ≤3★ bucket (not share of all reviews; not a causal install-conversion estimate); "no segment competitor commits to a named SLA" is inferred from review absence (iTunes RSS lacks developer responses); no commitment user-tested (validation via #263 TestFlight); recent-50 window is ~3–6 months only.
- **Cycle cap:** Exactly 1 new Saul issue (#322), 1 inbox drop, 2 comment-folds (#241, #296), 0 code changes. Total Saul stack: 12 open issues.
- **Learning:** When Frank's review-mining cycle flags a finding as "worth Saul amplifying," the decision to file-vs-comment depends on the *shape* of the finding. (a) Horizontal positioning artifact spanning multiple existing axes → file new (trust-commitment, this cycle). (b) New data point reinforcing or qualifying an existing axis → comment-fold (Delta cautionary on #241; Snowball refinement on #296). The shape test is: "would folding this into an existing axis couple it to that axis's evidence base and obscure its cross-axis applicability?" If yes, file; if no, comment.

## Cycle 2026-05-15 #8

- **Axis explored:** cross-issue coherence audit of the 12-open-issue Saul stack after Frank's two newest handoffs (localization / geographic TAM and Blossom awards-positioning). Question tested: do either signals justify a new positioning issue, or do they only refine existing monetization / credibility work?
- **Frank intake summary + dispositions:**
  - `.squad/decisions/inbox/frank-localization-storefront-sequencing.md` / Frank #324 — disposition: **no new Saul issue**. Signal 1 (global indie-tracker TAM ≈16k ratings lower bound vs. US-brokerage ≈90k ratings using M1 72k + Wealthfront 17k) was already folded into #241 in the 2026-05-15T13:21:41Z comment; it reinforces #296's peer-set discipline and does not alter #286's primacy debate.
  - `.squad/decisions/inbox/frank-handoff-2026-05-15-saul.md` — disposition: **defer post-launch**. Re-verified via iTunes Lookup at 2026-05-15T13:39:37Z that Blossom (`1592237485`) opens its US description with `***Named a Top 25 App of 2025 by Apple***` and sits at 4.74322 / 2547 ratings. Useful credibility-ladder signal, but Investrum cannot truthfully operationalize awards copy pre-launch.
  - Re-confirmed prior inbox drops remain resolved: `frank-review-response-templates.md` is already represented in #322 / #241 / #296, and the older four storefront drops remain non-Saul-actionable.
- **Cross-issue coherence audit:** Reviewed #238, #240, #241, #253, #263, #269, #277, #286, #296, #301, #313, and #322 in full. Result: #296 (manual-entry tier), #301 (local CSV/paste import), #313 (monthly recalc), and #322 (enumerated trust commitments) all either reinforce **Stance A** in #286 (Bogleheads / manual-entry / disciplined monthly / indie trust commitments) or stay neutral. The only unresolved contradiction remains the original one documented in #286: #238 seam-led headline vs. #240 Bogleheads-led headline. Localization TAM belongs under #241 and awards belong in the post-launch credibility layer (#269 / #322), so neither creates a second pre-launch copy-primacy issue.
- **Dedupe proof:** `gh issue list --state all --search` runs on `localization`, `locale`, `geography`, `global`, `tam`, `monetization`, `awards`, `recognition`, `credibility`, and `coherence`. Top near matches read in full: #241, #269, #286, #296, #322 (plus full-stack audit of #238, #240, #253, #263, #277, #301, #313). `awards` / `recognition` returned no existing issue; `credibility` resolved to #269 / #322; `localization` / `geography` / `tam` resolved to #324 and #241. Decision: update existing coherence issue, do not file new.
- **Decision:** Comment-folded the cycle-#8 audit onto **#286** (`https://github.com/yashasg/value-compass/issues/286#issuecomment-4460244198`). **No new Saul issue filed. No new inbox drop.** #241 already contained the localization TAM fold; Blossom awards signal was parked as post-launch evidence only.
- **Honest evidence ceilings:** Blossom is n=1 competitor and iTunes Lookup is silent on award-driven conversion lift. Frank's localization TAM read is a 10-storefront sample (`us, gb, de, fr, es, it, nl, jp, ca, au`), not a 175-storefront census. The coherence result is an internal reasoning audit, not user validation — Danny still must resolve #286's primacy choice explicitly.
- **Learning:** Once the Saul stack is saturated, the right move is usually to tighten the graph, not add another node. New external signals should clear a high bar: either they overturn the current primacy map or they stay as comment-folds / deferred notes. This cycle's signals did neither.

## Cycle 2026-05-15 #9

- **Axis explored:** positioning-coherence — narrowing the #286 primacy answer using Frank's new Search API keyword-competition evidence. Constraint-evidence pass, not a new positioning bet.
- **Frank intake summary + dispositions:**
  - `.squad/decisions/inbox/frank-keyword-competition-refresh.md` (06:41, **new this cycle**) — Frank's iTunes Search API refresh on the term set already posted to #245 at 2026-05-15T13:41:44Z. Frank explicit verdict: "Positioning shift required of Saul? NO — fold into #240 / #269 / #286; no new Saul issue needed." Disposition: **comment-fold on #286** with cross-link folds noted for #240 / #269 / #238 / #245 inside the same comment (no additional comments filed elsewhere — avoid noise).
  - Older Frank drops (`frank-handoff-2026-05-15-saul.md` Blossom awards, `frank-localization-storefront-sequencing.md` global TAM, `frank-review-response-templates.md` SLA, `frank-app-icon-competitive-scan.md`, `frank-ipad-screenshots-blueprint.md`, `frank-category-and-preview-video.md`, `frank-version-notes-cadence-and-ratings-prompt.md`) — re-confirmed dispositions from cycles #4–#8. No change. New Frank-filed GH issues since cycle #8 (#327 description-body scope-honesty) reviewed; #327 is a Frank-lane storefront atom that complements #322's commitments block without re-opening any Saul axis.
- **Independent re-verification (this cycle, my own pulls):** Apple iTunes Search API `entity=software&limit=10&country=us`, fetched 2026-05-15 in-cycle. Results: `value cost averaging` 0/8 investing apps in top-10 (Shopping/Business/Productivity); `value averaging` 0/9 method-specific (Seeking Alpha / Morningstar / Jitta match `value` token only); `vca` 0/8 investing (myVCA Medical, VCA Eagles Education, VCA Millbrook Education, VCA Construtora Finance-construction, VCA Portal Education); `bogleheads` 0/10 investing (TodayTix, lottery scratcher, NBC news). All four Frank claims confirmed at the top-10 layer this cycle.
- **Constraint-evidence finding:** All three #286 stances now converge on a **spelled-out-methodology headline** (`Value Cost Averaging …`) as the only search-coherent + trademark-safe + acronym-clean lane. The persona-led Stance A still works for description body / channel-validation (#263), but cannot carry the headline keyword. The seam-led Stance B is weakened — `VCA` standalone is polluted by Medical/Education/Construction apps; Stance B has to spell out the methodology or accept zero search at the headline. Stance C converges on the same headline by symmetry. Result: Danny's primacy decision narrows from "headline-and-body together" to "body persona framing only" — the headline lane is now fixed by search evidence.
- **Cross-issue coherence audit:** Comment-fold on #286 reinforces #269 (Edleson `value averaging` wording is the cleanest secondary lane), refines #240 (Bogleheads → narrative-only, not metadata candidate), weakens-but-doesn't-kill #238 (seam can live in body, not headline). Neutral vs. #241, #253, #263, #277, #296, #301, #313, #322. No contradictions introduced across the 12 open Saul issues.
- **Dedupe proof:** `gh issue list --state all --search` runs on `keyword competition`, `search API`, `value cost averaging keyword`, `acronym pollution`, `headline ownability`, `metadata lane`, `spelled-out methodology`, `search-safe`. Top near-matches reviewed in full: #245 (Frank's keyword surface — already carries raw evidence at 2026-05-15T13:41:44Z), #220 (storefront SoT), #269 (Edleson methodology), #238 (seam), #286 (coherence). No existing issue raises "headline ownability by search-competition constraint." Closest is #245 (Frank ASO surface) which holds the raw data but does not perform the Saul-side primacy-graph fold. Decision: comment-fold on #286 (the integrative coherence issue), with cross-link folds noted inside the same comment for #240 / #269 / #238 / #245. No new issue filed.
- **Decision:** Comment-folded the cycle-#9 keyword-competition constraint onto **#286** (`https://github.com/yashasg/value-compass/issues/286#issuecomment-4460324252`). **No new Saul issue filed. No new inbox drop** — primacy decision is still Danny's call on the body persona framing; the headline narrowing is a consequence the comment surfaces, not a new decision artifact.
- **Honest evidence ceilings flagged in the #286 comment:** Apple Search API exposes ranking only (no search-volume / impression-share / conversion); `0/N` in top results = zero supply at public-ranking layer, not zero demand; fuzzy tokenization understates the `value averaging` opening (lane is more open under the caveat, not less); convergence-on-methodology-headline does not prove conversion lift vs. persona-headline (gated to ASC Analytics + #263); Bogleheads-as-noise is current and should be re-spot-checked pre-launch.
- **Cycle cap:** Exactly 1 comment-fold (#286), 0 new issues, 0 inbox drops, 0 code changes. Total Saul stack: 12 open issues (unchanged).
- **Learning:** Two consecutive cycles (#8, #9) have terminated in a #286-comment-fold. That is now a pattern, not a coincidence: #286 is functioning as the integrative *audit log* of the Saul positioning graph — each new Frank cross-axis signal that doesn't justify a new node gets folded onto #286 so the primacy decision Danny eventually makes can be read with the full evidence trail attached. Worth flagging to Danny that #286's comment thread is the canonical history if/when he renders a primacy call. If a future Frank cycle produces a signal that *contradicts* (rather than narrows) the convergence above, the right move would be a new issue rather than another #286 fold — that's the line for next time.

## Cycle 2026-05-15 #10

- **Lane:** measurement-without-analytics — the under-covered axis from the charter ask. After two consecutive #286 comment-folds (cycles #8, #9), the cycle-#9 learning was explicit: file new when the next signal *adds a node* rather than narrows a primacy decision. Frank's #342 promo-text playbook this cycle did the latter (it operationalizes existing positioning), so the new issue this cycle is on a different axis entirely — the measurement counterpart to #322 commitment #4 ("no analytics SDK").
- **Signals consumed:**
  - `.squad/decisions/inbox/frank-promo-text-launch-playbook.md` (Frank cycle #9, **new this cycle**) — Frank's #342 explicitly states "no new Saul opportunity issue needed; three fold options: (a) #277, (b) #286, (c) consolidation note." Disposition: **fold (a) executed as a comment on #277; fold (b) declined per cycle #9 learning (don't fold onto #286 unless contradictory); fold (c) subsumed into the new #347 audit table.** Frank's underlying #342 evidence: iTunes Lookup sorted-keys probe at 2026-05-15T13:52:16Z confirmed no Apple surface exposes competitor promo-text; six 153–166-char variants drafted across #245/#253/#269/#312/#322 evidence; rotation cadence (Variant A day-0 → B/C day-15 → D/E lock day-60 contingent on #286 primacy → F immediate if #241 ships paywall).
  - Independent verification this cycle (my own pulls): `app/Sources/App/PrivacyInfo.xcprivacy` — `NSPrivacyTracking=false`, `NSPrivacyTrackingDomains` empty, only `DeviceID` declared with `AppFunctionality` purpose and `Tracking=false`. `grep -r -iE "analytics|firebase|mixpanel|amplitude|segment|appsflyer|adjust|sentry|crashlytics|posthog" app/Sources` returns zero hits (substring noise: `.tracking()` SwiftUI letter-spacing only). `grep -nE "analytics|telemetry|tracking|metric" docs/tech-spec.md docs/app-tech-spec.md` returns zero positioning-relevant hits. `app/Sources/Features/SettingsView.swift:52-56` confirms Settings → About currently has only Version + Device ID (no Support/mailto row today). The architectural state today already supports the seven channels listed in the new issue, save the one-line mailto addition (channel 4).
  - Older Frank drops (cycle #1–#8): re-confirmed all prior dispositions. `frank-handoff-2026-05-15-saul.md` (Blossom awards) still deferred post-launch; `frank-localization-storefront-sequencing.md` still folded into #241; `frank-keyword-competition-refresh.md` still represented in #286 cycle #9 comment; `frank-review-response-templates.md` already represented in #322 / #277 / #312 / #241 / #296.
- **Findings:**
  - **Validated:** The seven observable-signal channels under the no-SDK constraint (ASC Analytics, App Store ratings, TestFlight Feedback, inbound `mailto:`, community sampling, version-over-version review delta, Apple Search Ads opt-in) are all Apple-aggregated or public or user-initiated; none require a third-party SDK or new PII collection beyond the declared `DeviceID`. This converts #322 commitment #4 from "we measure nothing" to "we measure these seven, none of which need an SDK." The architectural state already supports six of seven channels; channel 4 is a one-line `mailto:` row in Settings → About (1–2h frontend, no new collection per #322 commitment #3 because user-initiated mail is not collection).
  - **Validated:** Frank's #342 + #277 are paired conversion-side levers — both editable-without-release, both not search-indexed, both work on post-landing visitors. The voice convergence rule is forced: at day-60 in the #342 rotation, whichever variant locks (D for #286 user-control primacy, E for seam primacy, F if #241 ships paywall) binds the #277 response-template register. The two surfaces cannot diverge without the persona reading dissonance as marketing.
  - **Validated:** The three #312 pain clusters (broker_connection 14%, missing_feature 13%, pricing_paywall 13%) are now pre-empted across three independent surfaces simultaneously — #327 (install-decision-point), #277 (post-review-reading-point), #342 (170-char swap-point). The defense-in-depth pattern is intentional and now documented in the #277 fold.
  - **Duplicate-check result:** None of the 13 prior Saul-owned positioning issues (#238, #240, #241, #253, #263, #269, #277, #286, #296, #301, #313, #322, plus closed) cover measurement-side signal taxonomy. #274 is Frank-lane external observable; #263 prescribes channel sequencing without signal extraction; #313 names the retention pattern without saying how to know it works. Lane uncontested.
  - **Dropped (none).**
- **Issue actions:**
  - **New issue → #347** `opportunity(measurement): observable-signal taxonomy for evaluating positioning under the #322 no-analytics-SDK commitment`. Labels applied: `documentation`, `priority:p2`, `mvp`, `team:frontend`, `team:strategy`, `squad:saul` (exactly one routing label — `team:frontend` — plus `team:strategy` as secondary per the labels already in use across #240/#286/#322 etc.). Body: signal source (PrivacyInfo.xcprivacy + tech-specs + dedupe sweep + Frank #342 measurement gap), hypothesis (v1 indie publisher can evaluate every open Saul positioning claim under no-SDK), evidence (seven-channel table mapping channel → first-party source → falsifiable signal → positioning issue), strategic axis (measurement counterpart to #322 commitment #4), proposed action (`docs/research/positioning-evaluation-plan.md` + `mailto:` row in Settings → About + don't suppress ASCA opt-in prompt), owner suggestion (Saul authors, Tess/Basher implements mailto, Danny opts ASCA, Reuben sign-off), AC (six checklists), open questions (ASC access, mailto target, day-30 baseline, community sampling automation), honest evidence ceilings (6 stated), cross-issue coherence audit (12 issues — all reinforce or neutral, no contradictions).
  - **Comment-fold on #277** (`https://github.com/yashasg/value-compass/issues/277#issuecomment-4460481721`) — operational pairing of #342 with #277 as paired conversion-side levers; voice convergence rule at day-60 binding #277 register to #342 Variant D/E/F lock; defense-in-depth pain-cluster preemption documented across #327/#277/#342; cross-link to #347 as the measurement counterpart that reads out the response-cycle effect via channel 2 + 6.
- **Duplicate-check proof:**
  - `gh issue list --state all --search "<term> in:title"` runs on: `measurement`, `telemetry`, `analytics`, `observable`, `signal`, `metric`, `KPI`, `tracking`, `no analytics`, `evidence`, `validation`, `feedback`, `channel test`, `testflight`, `bogleheads`, `reddit`, `App Store Connect`, `no-analytics`, `no SDK`, `no-SDK`, `success metric`, `north star`, `evaluation`, `instrument`, `measurement-without-analytics`, `measurement without`, `observable signal`, `signal taxonomy`, `evaluation plan`, `App Store Connect Analytics`, `ASCA`, `post-launch evidence`, `post-launch measurement`, `post-launch signal`, `evidence channel`, `feedback loop`.
  - `gh issue list --label squad:saul --state all --limit 50` — reviewed all 12 open Saul-owned positioning issues in full (#238/#240/#241/#253/#263/#269/#277/#286/#296/#301/#313/#322).
  - Top near-matches read in full: #274 (Frank — external observable; different lane), #263 (channel sequencing without signal taxonomy; different scope), #322 (commitment artifact; #347 is its measurement counterpart), #313 (retention pattern without measurement surface).
  - Decision: **lane is uncontested in Saul stack; new issue justified.** #347 is the measurement counterpart to #322 — analogous to how #322 itself was filed as horizontal artifact across #240/#241/#253/#277.
- **Cross-issue coherence audit:** #347 reinforces #240, #241, #253, #263, #269, #277, #286, #296, #313, #322; neutral vs #238, #301. No contradictions across the 12 open Saul issues. Safe to file (consistent with the cycle #4 rule).
- **Honest evidence ceilings flagged in #347:** ASC Analytics is opt-in and aggregate (read directional, not population); iTunes RSS surfaces user reviews only, not developer responses; community sampling is manual; channel 4 mailto produces inbound only (release-over-release delta, not peer comparison); no channel measures conversion-to-install by source (cost of the no-SDK commitment, stated); channel 6 confounds release content with seasonal effects.
- **Handoffs:**
  - **Saul → Danny:** four operational decisions surfaced in #347 — (1) opt the build into Apple's "Share with App Developers" ASCA prompt at first launch (no SDK, no suppress); (2) `mailto:support@<TBD>` target pick (alias recommended for #322 commitment #6 stability); (3) day-30 retention baseline — recommend Investrum-own v1.0 cohort vs. v1.1 release as the only honest comparable since competitor retention curves are not public; (4) acceptance of the day-30/60/90 re-evaluation cadence.
  - **Saul → Tess/Basher:** ~1–2h frontend addition to `app/Sources/Features/SettingsView.swift:52-56` — add a `Support` row with a `mailto:` link. No new collection. Pair with #322's in-binary About / Commitments row if Danny adopts #322's minimum subset.
  - **Saul → Reuben:** sign-off on channel 4 `mailto:` phrasing consistency with #322 commitment #3 (user-initiated mail is not collection — confirm phrasing). Verify ASCA opt-in prompt copy aligns with `PrivacyInfo.xcprivacy` declarations.
  - **Saul → Frank:** #347 references #274 (external observable) as the paired Frank-side counterpart. No new Frank work asked; #347 is the Investrum-side complement. The #277 comment-fold subsumes Frank's recommended folds (a) on #277, (b) on #286 (declined per cycle #9 learning), and (c) consolidation note (now in #347 audit table).
  - **No inbox drop this cycle.** The #347 issue body + #277 comment-fold carry the full operational ask; an inbox drop would duplicate. If Danny needs a one-page summary for the operational-decision call, the `## Open questions` section of #347 already structures it.
- **Cycle cap:** Exactly 1 new Saul issue (#347), 1 comment-fold (#277), 0 inbox drops, 0 code changes. Total Saul stack: 13 open issues.
- **Learning:** When the cycle ask offers two paths (merge Frank vs. advance under-covered axis) and Frank's signal is explicitly "no new opportunity issue needed," the second path is the right one **iff** the under-covered axis is *forced* by an existing commitment. The measurement axis was forced by #322 commitment #4: the team committed to "no analytics SDK" without saying what would be measured instead. That gap was the right shape for a new horizontal artifact (across #240/#241/#253/#263/#269/#277/#286/#296/#313/#322) rather than another comment-fold. Heuristic for next cycle: when filing new, prefer axes that complete a previously-filed commitment than axes that open a new bet — the coherence audit is cleaner.

## Cycle 2026-05-15 #11

- **Lane:** ingest Frank's newest decisions-inbox handoff — `.squad/decisions/inbox/frank-ratings-prompt-trigger-spec.md` (Frank's #345 `SKStoreReviewController` trigger spec, the in-binary acquisition counterpart to #270 release-notes CTA and #312 developer-response templates). Frank's explicit verdict: "no new Saul opportunity issue needed; three folds recommended — #277 trust-cycle, #313 monthly-cadence T1, #296/#240 manual-entry tier rating-density."
- **State delta since cycle #10:** Saul stack now at **14 open** (was 13). #354 `positioning(privacy-label): "Data Not Collected" App Store badge…` was filed by yashasg at 2026-05-15T14:24:48Z — the privacy-label storefront-differentiator axis is now covered. Frank shipped #345 (07:09 inbox drop), #351 (App Store URLs spec), #353 (privacy-label conversion side) since cycle #10. The frank-promo-text-launch-playbook.md (cycle #10) drop remains resolved per the existing #277 comment-fold at 2026-05-15T14:10:15Z.
- **Findings (validated, three Frank-side surfaces converge):**
  - **Trust cycle closes end-to-end.** #345 in-binary prompt = acquisition partner to #312 outgoing/response. The post-launch trust cycle this issue authors (positive moment → in-binary prompt #345 → rating → developer response #312 → SLA per #322 commitment #1) is now operationalizable. Voice convergence is forced: anti-pattern list in #345 enforces #322 commitments #2/#3/#4; pain-cluster preemption is now defense-in-depth across **four** surfaces (#327 install-decision, #277/#312 review-reading, #342 promo-text, #345 trigger-context).
  - **Monthly cadence is the operational primitive.** #345 Trigger T1 (≥3 saved Portfolio Snapshots) reads the SAME SwiftData state (`PortfolioSnapshot` count + `Portfolio.lastSnapshotDate`) that #313 Stance A reads for the "Last calculated: N days ago" home-screen cue. One observable, two product surfaces. If Danny adopts #313 Stance A, the build cost is partially shared with the #345 build-team implementation issue (yet to be opened). Adds a fourth surface to the monthly-cadence convergence Frank named (retention #313 + rating prompt #345 + storefront keyword #245 + measurement channel #347 ch.1+ch.6).
  - **Manual-entry tier is triple-cross-referenced.** #245 description-language frequency, #312 complaint-bucket distribution, and #345 rating-density target converge on the same four-tier peer-set classification. **Snowball is now the indie north-star comp on three independent Frank-side lanes** (description copy, complaint-bucket share <5%, recent-50 rating 4.84). Stock Events floor-drift (v9.35.4 sync connections, 2026-04-30 — comment #296 2026-05-15T14:25:19Z) confirms the manual-entry tier is unstable in 2026; Snowball is the *only* sustained-manual-entry peer.
  - **Duplicate-check result:** lane is *consumption of Frank handoff*, not a new positioning bet. No new issue justified.
- **Issue actions:**
  - **Comment-fold on #277** (`https://github.com/yashasg/value-compass/issues/277#issuecomment-4460721170`) — trust-cycle three-leg surface table; voice convergence with #322 / #312 / #342; in-binary-vs-ASC-editable asymmetry flagged; four-surface pain-cluster preemption pattern named explicitly.
  - **Comment-fold on #313** (`https://github.com/yashasg/value-compass/issues/313#issuecomment-4460721333`) — T1 / Stance-A same-observable mapping; Danny's primacy call should pair #313 + #345 build-team scope; monthly-cadence convergence reinforced from a fourth lane.
  - **Comment-fold on #296** (`https://github.com/yashasg/value-compass/issues/296#issuecomment-4460721498`) — three-surface convergence table (#245 × #312 × #345) on the manual-entry tier classification; Snowball-as-north-star tripled-down; promotion of `docs/research/competitive-tiers.md` flagged as overdue; Stock Events floor-drift cross-link to the 14:25:19Z comment.
- **Duplicate-check proof:**
  - `gh issue list --state all --search "<term> in:title"` runs on: `ratings tripod`, `ratings acquisition`, `rating channel`, `defense in depth`, `trigger spec`, `positive moment`, `acquisition surface`, `cross-channel`, `SKStoreReviewController`, `rating prompt`, `in-app prompt`, `snapshot trigger`, `monthly cadence`, `operational primitive`, `convergence`.
  - `gh issue list --label squad:saul --label squad:frank --state open --limit 80` — reviewed all 14 open Saul-owned issues plus the new #345/#351/#353/#354 from Frank/Saul cycle #10+.
  - Top near-matches read in full: #277, #313, #296, #345 (in full), #240 (latest comment), #354 (privacy-label — verified non-overlap).
  - Decision: **no new issue; three comment-folds per Frank's explicit recommendations.** All three folds are uncontested in their target issue's comment threads (no prior fold of #345 anywhere; #277's only prior fold is the cycle-#10 #342 promo-text drop, which this fold cross-links rather than duplicates).
- **Cross-issue coherence audit (per cycle #4 rule):** Folds on #277 / #313 / #296 reinforce Stance A on #286, reinforce #322 commitments #1/#2/#3/#4/#6, reinforce #347 channels 1/2/5/6, and stay neutral vs #238 / #241 / #301 / #354. No contradictions introduced across the 14 open Saul issues.
- **Frank intake summary + dispositions:**
  - **NEW this cycle:** `frank-ratings-prompt-trigger-spec.md` → executed all three recommended folds (#277, #313, #296). No new Saul issue (Frank explicit: "no positioning shift required").
  - **Re-confirmed:** `frank-promo-text-launch-playbook.md` (#342) — already represented in #277 cycle-#10 fold; this cycle's #277 fold cross-references rather than duplicates.
  - **Re-confirmed:** `frank-keyword-competition-refresh.md` (#245) — already represented in #286 cycle-#9 fold.
  - **Re-confirmed:** `frank-review-response-templates.md` (#312) — already represented in #322 / #277 / #312 / #241 / #296.
  - **Re-confirmed:** `frank-handoff-2026-05-15-saul.md` (Blossom awards) — deferred post-launch.
  - **Re-confirmed:** `frank-localization-storefront-sequencing.md` (#324) — folded into #241 cycle #8.
  - **Older cycle-#1–#5 Frank drops** (`frank-app-icon-competitive-scan.md`, `frank-ipad-screenshots-blueprint.md`, `frank-category-and-preview-video.md`, `frank-version-notes-cadence-and-ratings-prompt.md`) — all remain non-Saul-actionable per cycles #4–#8.
- **Honest evidence ceilings flagged in the three comment-folds:** (a) No A/B between in-binary prompt and post-review-response surfaces — relative conversion contribution unmeasured; (b) #345 spec is Frank-authored — build-team implementation issue under `team:frontend` not yet opened; (c) T1/T2/T3 thresholds (3 snapshots, 4s dwell, 1 calc post-import) are Frank heuristics, not Investrum-tested; (d) `requestReview` ≠ display — Apple may suppress prompt regardless of trigger fire; (e) Snowball-as-north-star is recent-50-rating outcome, not ratings-per-install (ratings-per-install inferred, not measured); (f) Stock Events sync-connections drift adds tier-classification volatility — re-pull cadence required at v1.0 launch and every 90 days; (g) #354 privacy-label adds a potential fourth Frank-side tier-evidence surface — re-evaluate at #354 implementation; (h) cost of no-analytics-SDK commitment (#322 #4) — no telemetry on snapshot-cadence → re-open correlation, declared.
- **Handoffs:**
  - **Saul → Danny:** when picking #313 Stance A, scope it together with the #345 build-team implementation issue. Both surfaces read from the same SwiftData observable; separate scoping is wasted effort.
  - **Saul → Frank:** no new work asked. The three folds carry Frank's #345 recommendations into the existing Saul stack.
  - **Saul → self (next cycle):** the `docs/research/competitive-tiers.md` artifact promotion is now flagged in three cycles (#5, #7, #11). Next cycle should either write it or surface the blocker to Danny.
- **No inbox drop this cycle.** All three comment-folds carry the operational ask in-thread; an inbox drop would duplicate.
- **Cycle cap:** 0 new Saul issues, 3 comment-folds (#277, #313, #296), 0 inbox drops, 0 code changes. Total Saul stack: 14 open issues (unchanged from #354's filing).
- **Learning:** When a Frank handoff arrives with **explicit fold recommendations**, the cycle-#10 heuristic ("prefer axes that complete a previously-filed commitment than axes that open a new bet") gets a tighter form: **execute Frank's named folds, then audit for over- or under-fold.** This cycle's three folds were exactly Frank's recommendations (no override, no decline), but the cycle's incremental value over a literal Frank-handoff execution is the *cross-axis observation* surfaced in the #313 fold — that monthly cadence is now a four-surface operational primitive. That observation is not in Frank's handoff; it emerges from auditing what Frank's folds imply across the existing Saul stack. Heuristic for next cycle: literal-Frank-fold execution is correct when the handoff is operationally tight; the Saul-side value-add is the cross-axis pattern-recognition that the Frank lane is not staffed for.

## Cycle 2026-05-15 #12

- **Lane:** ingest Frank's newest decisions-inbox handoff — the appended section in `.squad/decisions/inbox/frank-handoff-2026-05-15-saul.md` (timestamp 07:42, **after** cycle #11's 07:09 ratings-prompt-trigger-spec.md) covering Frank's #362 Frame 1 hero caption stack itemization. Frank's explicit verdict: "No new Saul opportunity issue required. Three folds recommended — #286 (Frame 1 Variant cascades from primacy), #253/#322 (`Your <X>` is third Frank-side user-control voice surface), #296 (hero visual is tier anchor)."
- **State delta since cycle #11:** Saul stack unchanged at 14 open. Frank shipped #362 (07:42 inbox section + 14:38:26Z iTunes Lookup probe) since cycle #11. No new Saul/Frank issues filed in the 07:09→07:42 window beyond #362 (`gh issue list --label squad:frank --state open --limit 40` re-confirmed 18-item Frank stack matches cycle #11's count + #362).
- **Findings (validated, three folds emerge from auditing #362's implications across the existing Saul stack):**
  - **Validated:** The `Your <X>` syntax now operates on three storefront surfaces — #322 commitments block, #312 review-response templates, #362 Frame 1 pull-tabs (`Your categories` / `Your budget`). #362 is the **highest-impression** of the three: pull-tab annotations render in App Store search-result thumbnails (~140px) BEFORE users tap into the listing — strictly upstream of #322 (body) and #312 (post-rating). The voice-amplification ladder is now strictly ordered: search thumbnail → above-fold body → below-fold body → post-rating. Voice convergence rule (#277 cycle-#10/#11 folds) extends upward to the discovery-side surface itself.
  - **Validated:** Hero frame visual composition (#362 ASCII layout — populated #125 Portfolio editor with categories + tickers + monthly-budget + Calculate CTA) **visually anchors Investrum to the manual-entry tier even when the headline copy is tier-silent.** This decouples copy-tier-anchor from visual-tier-anchor — the visual anchor survives any of Variant A/B/C's caption choices because all three share the same populated-manual-portfolio base. Adds a fourth orthogonal Frank surface to the #296 tier-classification convergence (alongside #245 description language, #312 complaint buckets, #345 rating density).
  - **Validated:** Variant→Stance mapping under #286 primacy: Variant A surfaces for Stance A (user-control / Bogleheads); Variant C surfaces for Stance B (seam) or methodology-led pivot; Variant B is the post-launch PPO pivot lane (not primacy-gated). **Structural finding: Stance B (seam-led primacy) cannot own the hero frame** because the hero slot is the conversion-job slot per Saul's #246 tiebreak — Variant C is the closest Stance B fit, but it does NOT claim the seam verbatim on Frame 1 (seam claim travels to description body + Frame 2 methodology surface + #347 channel 4 inbound mailto only). This **narrows** the #286 primacy decision: combined with cycle #9's search-keyword constraint (`VCA` standalone polluted), Stance B is now structurally **body-and-below distribution only** — it has no headline-keyword path and no hero-frame path. The remaining live primacy question is Stance A vs. methodology-led pivot (#269 + Stance C hybrid), not Stance A vs. Stance B.
  - **Duplicate-check result:** lane is consumption of Frank handoff, not a new positioning bet. No new issue justified.
  - **Dropped (none).**
- **Issue actions:**
  - **Comment-fold on #253** (`https://github.com/yashasg/value-compass/issues/253#issuecomment-4460811788`) — three-surface user-control voice operationalization table (#322 / #312 / #362), conversion-funnel ordering (search thumbnail → above-fold → below-fold → post-rating), voice-amplification ladder with strict cross-surface convergence requirement, Variant A↔C swap holds the `Your <X>` syntax across primacy outcomes, #245 keyword field is the lone Frank surface intentionally NOT carrying `Your <X>` voice (search-keyword constraint).
  - **Comment-fold on #296** (`https://github.com/yashasg/value-compass/issues/296#issuecomment-4460819697`) — four-Frank-surface tier-classification convergence table (#245 / #312 / #345 / #362-NEW), copy-tier-anchor vs. visual-tier-anchor decoupling, Stock Events floor-drift refinement (copy drifts before visual by 1–2 release cycles), Snowball-as-north-star confirmed from a fourth angle (visual composition — but Snowball has no observable iPhone shots so visual lane is inferred), `docs/research/competitive-tiers.md` promotion overdue (now flagged in four cycles: #5, #7, #11, #12).
  - **Comment-fold on #286** (`https://github.com/yashasg/value-compass/issues/286#issuecomment-4460828027`) — Variant→Stance mapping table (Stance A → Variant A; Stance B → Variant C; Stance C → Variant A; methodology-led pivot → Variant C), Stance B structural narrowing argument (no headline-keyword path + no hero-frame path = body-and-below distribution only), recommendation refinement (Stance A remains recommended; live primacy question is Stance A vs. methodology-led pivot, NOT Stance A vs. Stance B), per cycle #9 fold discipline (this is a *narrowing*, not a contradiction, so #286 fold is appropriate).
- **Duplicate-check proof:**
  - `gh issue list --state all --search "<term> in:title"` runs on: `frame 1`, `hero`, `pull-tab`, `visual anchor`, `amplification surface`, `voice convergence`, `Your X syntax`, `annotation`, `tier-anchor`, `user-control voice`, `user control voice`, `screenshot voice`, `voice consistency`, `voice register`, `operationalize axis`, `syntax pattern`, `amplification`, `visual tier`, `visual differentiation`.
  - `gh issue list --label squad:saul --state all --limit 80` — reviewed all 14 open Saul-owned positioning issues (#238, #240, #241, #253, #263, #269, #277, #286, #296, #301, #313, #322, #347, #354).
  - `gh issue list --label squad:frank --state open --limit 40` — reviewed all 18 open Frank-owned ASO issues (#220, #245, #246, #251, #255, #261, #270, #274, #284, #292, #312, #324, #327, #342, #345, #351, #353, #362).
  - Full read of #362 issue body (~12KB) — confirmed Variant A/B/C copy strings, ASCII layout, cross-team gates, six honest evidence ceilings, three explicit Frank → Saul folds.
  - Latest comments inspected: #253 (5 comments; latest is the 2026-05-15 RSS rescan note), #296 (4 comments; latest is the 14:25:19Z + 15:11Z folds for Stock Events drift + #345 ratings-density), #286 (multiple prior folds from cycles #8/#9 — no prior fold of #362).
  - Top near-matches read in full: #362, #246, #253, #296, #286. No existing issue raises the cross-surface `Your <X>` voice amplification observation or the visual-tier-anchor distinction.
  - Decision: **no new issue; three comment-folds per Frank's explicit recommendations.** All three folds are uncontested in their target issue's comment threads (no prior fold of #362 anywhere).
- **Cross-issue coherence audit (per cycle #4 rule):** Folds on #253 / #296 / #286 reinforce Stance A on #286, reinforce #322 commitments amplification, reinforce #347 measurement channels 1+2+6, weaken #238 seam-led primacy (structural narrowing — but #238's body-and-below distribution claim remains intact), and stay neutral vs #240 / #241 / #263 / #269 / #277 / #301 / #313 / #354. No contradictions across the 14 open Saul issues.
- **Frank intake summary + dispositions:**
  - **NEW this cycle:** appended section in `frank-handoff-2026-05-15-saul.md` (07:42, Frank's #362 cycle #11 work) — executed all three recommended folds (#253, #286, #296). No new Saul issue.
  - **Re-confirmed:** prior section of `frank-handoff-2026-05-15-saul.md` (Blossom awards) — still deferred post-launch.
  - **Re-confirmed:** `frank-ratings-prompt-trigger-spec.md` (#345) — already represented in cycle #11 folds on #277 / #313 / #296.
  - **Re-confirmed:** `frank-promo-text-launch-playbook.md` (#342) — already represented in #277 cycle-#10 fold.
  - **Re-confirmed:** `frank-keyword-competition-refresh.md` (#245) — already represented in #286 cycle-#9 fold.
  - **Re-confirmed:** `frank-review-response-templates.md` (#312) — already represented in #322 / #277 / #312 / #241 / #296.
  - **Re-confirmed:** `frank-localization-storefront-sequencing.md` (#324) — folded into #241 cycle #8.
  - **Re-confirmed:** older cycle-#1–#5 Frank drops — all remain non-Saul-actionable per cycles #4–#8.
- **Honest evidence ceilings flagged in the three comment-folds:** (a) "Highest-impression surface" claim is structural funnel ordering, not measured impression data — Apple does not publish per-surface impression counts; (b) Frame 1 capture is gated on #135 — visual-tier-anchor claim is on the strings + composition spec, not the rendered pixels; (c) Snowball has no observable iPhone shots in iTunes Lookup, so the visual-axis tier-anchor for Snowball is inferred from copy + ratings, not from observed pixels; (d) Variant→Stance mapping is Saul interpretation of #362's frame allocation + Saul tiebreak, not a Frank claim; (e) Stance B-narrowing argument is structural ("hero is conversion-job slot") — could be PPO-tested post-launch but segment evidence (4 of 4 observable competitors front-load value/result, not differentiator) doesn't prioritize it; (f) methodology-led pivot is a refinement of Stance A, not a fourth stance.
- **Handoffs:**
  - **Saul → Danny:** the #286 primacy decision now has cleaner structural framing — Stance B's body-and-below-only distribution makes Stance A vs. methodology-led pivot the live choice, not Stance A vs. Stance B. When picking primacy, the choice cascades to Variant A vs. Variant C at the hero frame (#362) — Variant B is PPO-only and not primacy-gated.
  - **Saul → Frank:** no new work asked. The three folds carry Frank's #362 implications into the existing Saul stack. The `docs/research/competitive-tiers.md` artifact is overdue (flagged four cycles) — when Frank's bandwidth permits, the four-Frank-surface convergence table from the #296 fold is the seed.
  - **Saul → self (next cycle):** if Danny resolves #286 (or signals direction), the next cycle should produce the locked Variant string set for Frank to seed into #220 (storefront SoT) + `app/AppStore/en-US/screenshots.md`. If #286 stays open, continue gap-driven axes per cycle #6 learning.
- **No inbox drop this cycle.** All three comment-folds carry the operational ask in-thread; an inbox drop would duplicate.
- **Cycle cap:** 0 new Saul issues, 3 comment-folds (#253, #286, #296), 0 inbox drops, 0 code changes. Total Saul stack: 14 open issues (unchanged).
- **Learning:** Two consecutive Frank handoffs (cycle #11 ratings-trigger-spec, cycle #12 hero-caption-stack) have arrived with **explicit fold recommendations** that map 1:1 onto Saul-stack issues, and both cycles executed literal-Frank-fold + cross-axis observation per cycle #11's heuristic. The pattern is now stable: when Frank ships an operationally-tight handoff with named folds, Saul's value-add is **the cross-axis observation that emerges from auditing the implication graph**, not net-new positioning. This cycle's cross-axis observations were (a) the user-control voice now occupies the highest-impression storefront surface via #362 pull-tabs, (b) visual-tier-anchor decouples from copy-tier-anchor — a distinction that Stance B's seam-led primacy cannot recruit. Both observations refined Stance A's case without requiring a new issue. The Saul stack at 14 issues is saturated on positioning axes; net-new axes will require either a forced commitment (per cycle #10 — measurement #347 was forced by #322 #4) or an external signal that overturns rather than narrows the current primacy map.

## Cycle 2026-05-15 #13

- **Lane:** ingest Frank's newest decisions-inbox handoff — the third (07:56-appended) section of `.squad/decisions/inbox/frank-handoff-2026-05-15-saul.md` covering Frank's **#370 Frame 2 numeric-methodology hero caption stack itemization** (Frank's cycle #12 work, appended after Saul cycle #12 closed at 07:42). Frank's explicit verdict: "No new Saul opportunity issue required. Three folds recommended (#286, #253/#322, #296)."
- **State delta since cycle #12:** Saul stack unchanged at 14 open. Frank shipped #370 (07:56 inbox appendix + 14:38:26Z iTunes Lookup probe re-use) and #377 (`aso(subtitle): free-first positioning` — 15:12:22Z, squad:frank, no inbox drop). Re-confirmed 14 open Saul issues + 19 open Frank issues via `gh issue list --label squad:saul --state open --limit 80` and `gh issue list --label squad:frank --state open --limit 40`.
- **Findings (Saul-side cross-axis observation that's NOT in Frank's handoff):**
  - **The #286 primacy cascade is asymmetric across Frame 1 vs Frame 2.** Cycle #12's #286 fold mapped Frame 1 #362 to a symmetric Variant A under both Stance A and the methodology-led pivot. Frame 2 #370 introduces **asymmetric** behavior: Frame 1 stays Variant A under both, but Frame 2 *swaps* — Variant A under Stance A vs Variant B under methodology-led pivot. Variant B's `Edleson method` 14-char pull-tab is the **only above-fold, listing-thumbnail-visible, non-search-indexed storefront surface** available to the methodology-led pivot, because cycle #9's keyword-competition fold blocked methodology-keyword headlines (`VCA` acronym-polluted) and #342 confirmed promo text isn't search-indexed.
  - **Cycle #9 ↔ Frame 2 closes a loop on the methodology axis discovery surfaces.** Search-side methodology-keyword pollution (cycle #9) + screenshot-pull-tab methodology-keyword availability (Frame 2 Variant B) bracket the methodology axis cleanly across the discovery funnel. If Danny picks methodology-led pivot at #286, Frame 2 Variant B is the *only* mechanism converting #269's Edleson-provenance evidence into a discovery-side conversion signal.
  - **Frank-side cost asymmetry is small.** Stance A → Frame 1 A + Frame 2 A (zero post-pick string changes). Methodology-led pivot → Frame 1 A + Frame 2 B (one-string swap on Frame 2 subhead + pull-tab). The asymmetry favors Stance A's operational tightness by the smallest possible margin — *not* a primacy input, just a sequencing observation.
  - **Skipped folds (deliberate, per cycle #12 over-fold discipline):** #253 (5-surface user-control voice count-up is incremental refinement of cycle #12's 3-surface fold — no new structural insight) and #296 (Frame 2 visual tier-anchor mirrors Frame 1's #296 fold mechanics — adds a fourth lane but no new convergence pattern). Frank's three recommended folds are not equally novel; the #286 asymmetric-cascade is the only one with genuinely new cross-axis observation.
  - **Duplicate-check result:** lane is consumption of Frank handoff + cross-axis pattern recognition, not a new positioning bet. No new issue justified.
- **Issue actions:**
  - **Comment-fold on #286** (`https://github.com/yashasg/value-compass/issues/286#issuecomment-4461051020`) — Frame 2 asymmetric primacy cascade table; methodology-led pivot now has cycle #9 ↔ Frame 2 closed-loop discovery-surface analysis; Stance B structural narrowing extends to Frame 2 (no methodology-keyword path beyond body-and-below); Frank-side post-pick string-swap cost asymmetry quantified (zero vs one); status confirms Stance A remains recommended; honest evidence ceiling on thumbnail-visibility, capture-gated #135, and variant-mapping interpretation.
- **Duplicate-check proof:**
  - `gh issue list --state open --search "opportunity OR positioning in:title" --limit 100` and `gh issue list --state closed --search "opportunity OR positioning in:title" --limit 50` — re-confirmed 14 open Saul positioning/opportunity issues; latest cycle-#12 fold on #286 (4460828027) is the only prior fold of the Frank Frame-stack work on this issue, so the Frame 2 fold is non-duplicative.
  - `gh issue view 370 --json title,labels,body` — verified Frame 2 caption stack content, three explicit Frank → Saul folds, Variant B `Edleson method` pull-tab as methodology-axis surface.
  - `gh issue view 377` — verified squad:frank, not a Saul-side new bet; subtitle-real-estate observation noted as cycle #14+ candidate (free-first as fourth headline-candidate axis competing for the 30-char slot — depends on #241 Danny pick, not new positioning).
  - Top near-matches read in full: #286 (latest 3 comments), #370 (full), #377 (body + labels).
  - Decision: **no new issue; one comment-fold on #286.** Two of Frank's three named folds (#253, #296) deliberately skipped per cycle #12 over-fold discipline.
- **Cross-issue coherence audit (per cycle #4 rule):** Fold on #286 reinforces Stance A primacy without weakening #269's methodology axis viability; closes cycle #9 ↔ Frame 2 discovery-surface loop; extends cycle #12 Stance B structural narrowing to Frame 2; stays neutral vs #238 / #240 / #241 / #253 / #263 / #277 / #296 / #301 / #313 / #322 / #347 / #354. No contradictions across the 14 open Saul issues.
- **Frank intake summary + dispositions:**
  - **NEW this cycle:** third (07:56) appended section of `frank-handoff-2026-05-15-saul.md` (Frank #370 Frame 2) → executed ONE recommended fold (#286). Two skipped (#253, #296) per discipline; tracked here for transparency.
  - **NEW this cycle (no inbox drop):** Frank #377 free-first subtitle filing — Saul-side observation deferred to cycle #14+ (subtitle real-estate coherence question depends on Danny's #241 monetization pick, not a new Saul positioning bet).
  - **Re-confirmed:** prior section of `frank-handoff-2026-05-15-saul.md` (Blossom awards) — still deferred post-launch.
  - **Re-confirmed:** all earlier Frank inbox drops — already represented per cycle #8/#11/#12 folds.
- **Honest evidence ceilings flagged in the #286 fold:** (a) "Only above-fold thumbnail-visible non-search-indexed surface" is structural funnel claim — no measured Apple-side impression attribution per discovery surface; (b) Pull-tab thumbnail visibility at ~140px is heuristic, capture gated on #135 + Tess #143; (c) "Methodology-led pivot's only visible-keyword surface" claim is conditional on locked subtitle staying on the user-control / scope-honest lane (cycle #9); (d) Variant→Stance mapping is Saul interpretation, not a Frank claim; (e) Asymmetric-cascade observation extends Frank's explicit verdict with the methodology-keyword-surface implication.
- **Handoffs:**
  - **Saul → Danny:** #286 primacy call now has a fourth cross-axis input — Frame 2 #370 asymmetric cascade. Stance A vs methodology-led pivot decision should consider whether Frame 2 Variant B's `Edleson method` pull-tab is valuable enough to override full-stack user-control voice consistency. PPO-testable post-launch per #370's working spec + #347 channels 1+2.
  - **Saul → Frank:** no new work asked. The single fold carries Frank's #370 implications into the #286 thread. Cost asymmetry quantified (Stance A: 0 string changes post-pick; methodology-led pivot: 1 swap on Frame 2 subhead + pull-tab) for Frank's planning.
  - **Saul → self (next cycle):** (1) the `docs/research/competitive-tiers.md` artifact promotion is now flagged in **five** cycles (#5, #7, #11, #12, #13) — next cycle should either write it or surface the blocker to Danny; (2) Frank #377 free-first subtitle observation — assess whether subtitle real-estate now has a four-way contestant problem (user-control, methodology, free-first, manual-entry-tier-anchor) that warrants a Saul-side coherence comment on #286 or a new positioning bet on the free-first axis; (3) re-evaluate #253/#296 fold-skips if Frame 3+ caption stacks land in a future Frank cycle and a true 4-or-more-surface convergence emerges.
- **No inbox drop this cycle.** The single comment-fold carries the operational ask in-thread; an inbox drop would duplicate.
- **Cycle cap:** 0 new Saul issues, 1 comment-fold (#286), 0 inbox drops, 0 code changes. Total Saul stack: 14 open issues (unchanged).
- **Learning:** When Frank's handoff recommends N folds, the cycle-#12 heuristic ("execute Frank's named folds") needs a **novelty filter**: count-up refinements (3→5 surfaces) and mirror-pattern restatements (Frame 1 #296 → Frame 2 #296) are not equally valuable to a structural new-mechanism fold (Frame 2 asymmetric cascade exposes a previously-invisible methodology-keyword surface). Cycle #13 produces ONE fold rather than three, trading volume for novelty. Heuristic for next cycle: when Frank-named folds are not equally novel, prefer ONE structural fold over N count-up folds — same total "consolidation work" output, higher Saul-side cross-axis value-add per fold.

## Cycle 2026-05-15 #14

- **Lane:** ingest the two newest appended sections in `.squad/decisions/inbox/frank-handoff-2026-05-15-saul.md` (Frame 3 #387 at line 99 and Frame 4 #400 at line 140 — both Frank cycle #13 work appended *after* my cycle #13 closed) AND surface the 5-cycle-overdue `docs/research/competitive-tiers.md` artifact-promotion blocker to Danny per cycle #13's "Saul → self (next cycle)" note. Apply cycle #13's novelty filter strictly: ONE structural new-mechanism fold over the 6 Frank-named folds (#354/#286/#296 from #387 + #246/#286/#296 from #400).
- **State delta since cycle #13:**
  - Saul stack grew from 14 → 17 open issues. Three filings landed between cycle #13's #286 fold and now: **#378** (`opportunity(cold-start-path)` invite-only beta, p1, 15:06:37Z), **#393** (`positioning(spreadsheet-competitor)` Bogleheads/FIRE spreadsheet barrier, p2, 16:02:59Z, has matching `saul-spreadsheet-objection-brief.md` inbox drop), and **#399** (`opportunity(subtitle-primacy)` 4-axis 30-char composite, p1, 15:59:29Z — closes #377 AC #1, addresses cycle #13's "Saul → self" item 2). All 17 open Saul issues verified via `gh issue list --label squad:saul --state open --limit 30`.
  - Frank stack grew with #400 (15:47:28Z) Frame 4 caption stack + #387 (15:22:48Z) Frame 3 caption stack + #390 (15:31:53Z) CPP variants + #377 (15:59:28Z) free-first subtitle. Re-confirmed 22 open Frank issues via `gh issue list --label squad:frank --state open --limit 30`.
- **Findings (Saul-side structural observation that's NOT in Frank's handoff verbatim):**
  - **Frank #400's `NYSE & ETFs` Frame 4 pull-tab introduces a THIRD positioning differentiator to the storefront stack.** The first two — Privacy (Data Not Collected, #354/#353/#387) and Manual-entry tier anchor (#296/#327/#362) — are the cycle #11/#12/#13 fold-line. The new third differentiator is **offline ticker lookup** (#126 bundled NYSE+ETF metadata, surfaced via Frame 4 Variant A pull-tab). Frank flagged this as "third differentiator surface" in the Frame 4 appended section; the Saul-side cross-axis observation is that this **stratifies the manual-entry tier itself** into a sub-tier split (offline-bundle vs network-dependent) that #296's current tier table does not show.
  - **#296's manual-entry-tier framing is now INCOMPLETE without an intra-tier specifier.** Investrum is in the manual-entry tier (Stock Events / Snowball / Yahoo neighborhood per cycle #9 + #11 Lookup probes), but on the ticker-lookup axis Investrum is alone — Frank infers (from #246 segment scan) that the four observable manual-entry peers all rely on network ticker lookup. This is a **structural refinement of #296**, not a contradiction: the tier-anchor recommendation stands, but the tier table needs a new column (`Ticker lookup mechanism: offline-bundle | network`) and a "differentiator surfaces operationalized in storefront" count where Investrum's three (privacy + tier anchor + offline lookup) exceeds peers' one-each.
  - **Frame 3 (#387) is the first segment-novel above-fold frame** — closes the differentiator-slot operationalization loop. Six segment peers use Frame 3 for feature-explainer content; none for privacy. Frame 3 Variant A (`No account. No tracking.` / `Your portfolio stays on your device.`) is mechanically un-mirrorable by peers without architectural change (4/6 require signup; 6/6 declare tracking per #354). Segment-novel by construction.
  - **Coherence with newly-filed Saul issues:** #393 (spreadsheet-competitor) is *reinforced* by the offline-typeahead observation (a spreadsheet has no ticker typeahead at all). #399 (subtitle-primacy composite) is unaffected (offline-typeahead is on Frame 4 pull-tab, not subtitle). #378 (cold-start-path invite-only beta) is unaffected (independent positioning axis). #286 primacy remains the live Stance A vs methodology-led-pivot question — Frame 4 is #286-decoupled per Frank, second decoupled frame after #387 (sequencing observation, not primacy input).
  - **Duplicate-check result:** ≥10 search terms run; no open issue covers offline-ticker-lookup / #126-bundle / network-vs-offline sub-tier framing. The closest open neighbors are #296 (tier anchor, where the structural refinement belongs) and #126 (the implementation issue, not positioning). No new issue justified.
  - **Skipped folds (deliberate per novelty filter):** #354 fold (Frame 3 satisfies AC #2 — narrow one-line operational note, can be carried at #354 implementation); #286 fold (#286-decoupled-cohort = sequencing/de-block observation for Frank/Tess capture scheduling, not a primacy input — count-up of cycle #13's asymmetric-cascade fold); #246 fold (Frames 5–7 sequencing — Frank-owned issue, mostly Frank's planning). All three would have been valid count-up folds; none introduces a previously-invisible positioning mechanism.
- **Issue actions:**
  - **Comment-fold on #296** (`https://github.com/yashasg/value-compass/issues/296#issuecomment-4461417606`) — three-differentiator-surface table (privacy / tier anchor / offline ticker lookup NEW); manual-entry intra-tier sub-tier split (offline-bundle vs network); Frame 3 segment-novel observation; coherence with #393/#399/#286/#354 noted; deliberate-skip statement on the three non-folded Frank-named folds per novelty filter; cross-link to Danny inbox drop; honest evidence ceilings (a–e).
- **Duplicate-check proof:**
  - `gh issue list --state all --search "<term>"` runs on: `offline ticker`, `offline lookup`, `NYSE ETF`, `typeahead`, `bundled metadata`, `sub-tier`, `differentiator surface`, `ticker search`, `#126 bundle`, `network lookup`. Top neighbors returned: #126 (implementation issue, not positioning), #245 (keyword gap), #400 (Frank operationalization), #387 (Frank operationalization), #353 (privacy posture), #269 (Edleson provenance). No open Saul issue covers the offline-vs-network sub-tier framing.
  - `gh issue list --label squad:saul --state open --limit 30` — re-confirmed 17 open Saul issues (#238, #240, #241, #253, #263, #269, #277, #286, #296, #301, #313, #322, #347, #354, #378, #393, #399).
  - `gh issue list --label squad:frank --state open --limit 30` — re-confirmed 22 open Frank issues, all Frame 1–4 captures filed.
  - `gh issue view 296 --json comments` — verified 4 prior human folds (13:10:34Z Snowball-north-star, 14:25:19Z Stock Events floor-drift, 14:41:48Z #345 fold, 14:54:08Z Frame 1 fold). No prior #296 fold covers offline-ticker-lookup, sub-tier split, or Frame 3/Frame 4 — fold is structurally non-duplicative.
  - `gh issue view 393 --json body` — verified #393 spreadsheet-competitor framing is consistent with this cycle's offline-typeahead observation (mutual reinforcement, not contradiction).
  - Decision: **no new issue; one comment-fold on #296.** Three Frank-named folds (#354, #286, #246) deliberately skipped per novelty filter; tracked in this cycle's findings for transparency.
- **Cross-issue coherence audit (per cycle #4 rule):** Fold on #296 reinforces Stance A user-control voice (now ~6 surfaces per Frank), refines #296 tier framing with intra-tier offline-vs-network sub-tier split, mutually reinforces #393 spreadsheet-competitor (no typeahead in a spreadsheet), stays neutral vs #238 / #240 / #241 / #253 / #263 / #269 / #277 / #286 / #301 / #313 / #322 / #347 / #354 / #378 / #399. No contradictions across the 17 open Saul issues.
- **Frank intake summary + dispositions:**
  - **NEW this cycle:** Frame 3 (#387, line 99) appended section + Frame 4 (#400, line 140) appended section in `frank-handoff-2026-05-15-saul.md` → executed ONE structural fold on #296. Three Frank-named folds skipped per novelty filter (#354 / #286 / #246) with explicit rationale in the #296 comment + this history entry.
  - **Re-confirmed:** all earlier Frank inbox drops + earlier appended sections (Blossom awards, Frame 1 #362, Frame 2 #370) — already represented per cycles #8/#11/#12/#13 folds.
  - **No new Frank-side inbox drops to ingest.**
- **Honest evidence ceilings flagged in the #296 fold:** (a) Network-dependent ticker lookup for Stock Events / Snowball / Yahoo / Delta / DivTracker is Frank inference from #246 segment scan, not directly observable in iTunes Lookup; (b) sub-tier split table is 2-axis (Investrum vs peers) because Investrum is the only segment app known to ship bundled metadata — if any peer also bundles, the split collapses to a sub-tier of one; (c) Frame 3 segment-novel claim is on slot allocation, not on privacy-claim text; (d) `NYSE & ETFs` pull-tab visibility at ~140px is heuristic, capture-gated on #135 + Tess #143; (e) "Third differentiator surface" framing is storefront-side only, not product-mechanism inventory.
- **Handoffs:**
  - **Saul → Danny:** inbox drop `saul-competitive-tiers-md-escalation.md` filed this cycle. Options 1–4 with recommendation (option 1 or 3). 6-cycle-overdue artifact promotion; cycle #14's third-differentiator finding seeded into the drop as content the artifact must absorb. If no reply by cycle #16, I will assume option 4 (defer indefinitely) and stop pushing.
  - **Saul → Frank:** no new work asked. The single fold on #296 carries Frank's #400 Bonus Signal + #387 segment-novel observation as Saul-side cross-axis consolidation. Cycle #13's "Saul → self" item 2 (Frank #377 subtitle real-estate) was closed by #399 between cycles — no separate Saul action needed.
  - **Saul → self (next cycle):** (1) `docs/research/competitive-tiers.md` is now in Danny's court; do not re-flag until cycle #16 disposition; (2) when Frank files Frames 5–7 caption stacks, expect another novelty-filter pass — the user-control `Your <X>` voice will hit 8+ surfaces and the brand-style-rule observation will be a structural fold candidate ONLY if Frames 5–7 break the convention or introduce a NEW surface mechanism; (3) re-evaluate the third-differentiator-surface table at v1.0 launch — if Stock Events / Snowball / Yahoo are observed to also ship bundled metadata, the sub-tier split collapses and the #296 fold should be amended; (4) #286 primacy remains the largest unresolved Saul-side gate — Stance A vs methodology-led pivot decision should land before Frame 5+ captures lock.
- **One inbox drop this cycle.** `.squad/decisions/inbox/saul-competitive-tiers-md-escalation.md` — Danny disposition request, options 1–4, with cycle #14 structural finding seeded as artifact content. The drop is to Danny, not Frank; the #296 fold is the in-thread carrier for Frank's audience.
- **Cycle cap:** 0 new Saul issues, 1 comment-fold (#296), 1 inbox drop (Danny escalation), 0 code changes. Total Saul stack: 17 open issues (unchanged from filings between cycle #13 and now).
- **Learning:** Cycle #13's novelty filter ("ONE structural fold over N count-up folds") composes cleanly with a previously-implicit rule: **when an inbox-drop blocker has aged ≥ N cycles and the current cycle surfaces seed content for it, the cycle-N+1 fold should carry forward the seed AND escalate the blocker simultaneously.** The escalation drop (`saul-competitive-tiers-md-escalation.md`) is not a duplicate of the #296 fold — they target different audiences (Danny vs. the issue's reading audience). The #296 fold has to stand alone as positioning; the inbox drop has to stand alone as a scope-decision request. Cost: one extra inbox-drop file. Benefit: the seed content survives in two locations, so if Danny picks option 1/3 and the artifact gets written, the drop's tier table + differentiator inventory + honest evidence ceilings are ready-to-paste — minimal extra ramp cost. Heuristic for next cycle: when surfacing a long-aged blocker, **bundle the surface with the cycle's structural finding** so the escalation has fresh seed material rather than just a re-flag of a known-deferred ask. Re-flag-only escalations are noise; seed-bundled escalations are signal.

## Cycle 2026-05-17 #1

- **Lane:** ingest the newest appended section in `.squad/decisions/inbox/frank-handoff-2026-05-15-saul.md` (Frame 5 #409, **2026-05-17 cycle #1** at line 192 — Frank's first 2026-05-17 cycle, landed after my cycle #14 closed). Apply cycle #13/#14 novelty filter strictly: ONE structural new-mechanism fold over Frank's three named folds (#246 / #286 / #296). The structural mechanism crossing this cycle: `Your <X>` user-control voice has reached 9 surfaces — a **phase change from "convention" (3 surfaces, cycle #12 fold on #253) to "brand-style rule"** — and `segment-structure-mirror + scope-honest-divergence` is now a **two-instance pattern** (Frames 4 + 5), i.e. a design principle, not coincidence.
- **State delta since cycle #14:**
  - Saul stack unchanged at 17 open issues (#238, #240, #241, #253, #263, #269, #277, #286, #296, #301, #313, #322, #347, #354, #378, #393, #399). Verified via `gh issue list --label squad:saul --state open --limit 30`.
  - Frank stack grew by 1: #409 (Frame 5 caption stack) filed cycle 2026-05-17 #1. Frank's other cycle-#14-window filings (#377 subtitle, #387 Frame 3, #390 CPP, #400 Frame 4) are still open and absorbed.
  - Inbox: cycle #14's `saul-competitive-tiers-md-escalation.md` to Danny is still pending — no Danny response yet (do not re-flag until cycle #16 per cycle #14 rule).
- **Findings (Saul-side structural observations NOT in Frank's #409 handoff verbatim):**
  - **The `Your <X>` user-control voice has crossed the convention → brand-style-rule phase boundary.** Cycle #12 fold on #253 documented 3 surfaces (#322 / #312 / #362). With #370 / #387 / #400 / #409 caption stacks now itemized, the total is **9 independent storefront expressions**: 5 screenshot pull-tabs (`Your categories`, `Your budget`, `Your numbers`, `Your portfolio`, `Your device`, `Your tickers`, `Your history` — 7 tokens across 5 frames) + #322 commitments block + #327 description body + #342 promo text + #312 response templates. 9 surfaces clears the "rule, not coincidence" bar. Practical consequence: Frank's forecasted Frame 6 (`Your method`) and Frame 7 (`Your desk` / `Your workspace`) become **prediction tests** the rule must pass; if either pull-tab breaks convention, the storefront reads disjointed across the bottom band. My fold also forecasts Frame 7 should pick `Your workspace` (14 ch) over `Your desk` because `desk` is the headline anchor — `workspace` keeps the pull-tab on the user-control axis rather than echoing the headline noun. The single exempt Frank surface remains the #245 keyword field (per cycle #9 search-keyword ownership constraint).
  - **`segment-structure-mirror + scope-honest-divergence` is now a two-instance design principle.** Frame 4 mirrors the segment's portfolio-editor visual (live ticker prices + connected-broker badges in Snowball / Stock Events) but diverges in copy by surfacing NYSE/ETF *typeahead* (offline metadata, #126) — no live-quote claim. Frame 5 mirrors the segment's chart-frame visual (yield/dividend numerics in Snowball / Stock Events / Wealthfront — qualitative pixel reads per cycle #9 adjacent-evidence learning) but diverges in copy by leading with user-recorded snapshots + per-ticker time series — no yield/dividend claim. Two instances clear "pattern, not coincidence." Named the principle (`mirror-the-converting-visual; diverge-the-copy-to-stay-scope-honest`) as the Frame 4–7 design rule. Counterpart to the `Your <X>` voice rule above — together they constrain below-fold composition on both axes (visual + copy).
  - **Skipped folds (deliberate per cycle #13/#14 novelty filter):**
    - **#286 fold (Frank-named).** Pure count-up — Frame 5 as "third #286-decoupled frame" repeats the cycle #13 asymmetric-cascade observation pattern (Frame 3 was first, Frame 4 was second). No new structural mechanism; skipping to avoid count-up noise.
    - **#296 fold (Frank-named).** On-device chart rendering as fourth differentiator-surface candidate. Frank himself flags this as "intentionally implicit in v1.0, post-launch differentiator candidate only." Cycle #14's three-differentiator-surface fold on #296 stands; the fourth differentiator is a post-launch question that should re-open *after* launch evidence per cycle #14 "Saul → self" item 3.
    - **#246 fold (Frank-named) deliberately re-routed to #253.** Frank's recommended fold target was the Frank-owned #246 (master 7-frame blueprint). The brand-style-rule observation is a **positioning voice claim on the user-control axis** — it belongs structurally on the Saul-owned #253 (persona-pain → user-control axis), with #246 as a cross-link. Folding on #253 puts the rule in the Saul-stack's voice-axis canonical issue rather than buried in Frank's planning issue. The Frame 6/7 forecast and `mirror-and-diverge` principle are cross-linked back to #246 in the #253 comment for Frank's audience.
  - **Duplicate-check result:** no open issue covers the convention → brand-style-rule phase change OR the two-instance `mirror-and-diverge` design principle. Closest neighbors are #253 (where the fold lands) and Frank-owned #246 (cross-linked). No new issue justified.
- **Issue actions:**
  - **Comment-fold on #253** (`https://github.com/yashasg/value-compass/issues/253#issuecomment-4461527497`) — 9-surface `Your <X>` rule table; Frame 6 (`Your method`) / Frame 7 (`Your workspace` preferred over `Your desk`) prediction tests; `mirror-and-diverge` two-instance design principle table (Frame 4 + Frame 5); coherence cross-check across the 17-issue Saul stack; explicit skip rationale for #286 + #296 + #246 (with #246 re-routed to #253); five honest evidence ceilings.
- **Duplicate-check proof:**
  - `gh issue list --state all --search "Your X voice convention rule"` — top 5 results: #409, #400, #370, #387, #399. No open issue raises the convention → brand-style-rule phase change.
  - `gh issue list --state all --search "segment mirror copy diverge"` — top 3 results: #409, #400, #277. No open issue raises the two-instance design-principle observation.
  - `gh issue list --state all --search "on-device chart rendering differentiator"` — top 2 results: #409, #284. No open issue raises the fourth-differentiator-surface question (consistent with Frank's "kept implicit in v1.0" position).
  - `gh issue list --state all --search "brand style rule Your in:title,body" --limit 10` — top 5: #399, #393, #378, #354, #347 (Saul stack header sweep — none cover the brand-style-rule formalization).
  - `gh issue list --label squad:saul --state open --limit 30` — re-confirmed 17 open Saul issues unchanged from cycle #14.
  - `gh issue view 253 --json comments` — verified 6 prior comments (10:23:47Z github-actions, 10:37:37Z Frank handoff #261, 11:22:46Z RSS rescan, 11:34:32Z 30-day pass, 11:53:54Z cutoff rescan, 14:53:18Z cycle #12 Frame 1 fold). No prior comment covers the 9-surface phase change, Frame 6/7 prediction tests, or `mirror-and-diverge` two-instance principle. Fold is non-duplicative.
  - `gh issue view 409 --json title,labels,state` — verified squad:frank scope + Frame 5 caption stack content + Variant A `See how your plan plays out` / `Snapshots over time. Per-ticker charts.` / `Your history` / `Per-ticker`.
  - Decision: **no new issue; one comment-fold on #253.** Three Frank-named folds (#246 / #286 / #296) skipped or re-routed with explicit rationale; #246 absorbed by re-routing the brand-style-rule observation to #253 with #246 as cross-link.
- **Cross-issue coherence audit (per cycle #4 rule):** Fold on #253 reinforces #322 (commitments amplification — voice surface #6), reinforces #277 (voice convergence rule extends to 9 surfaces), reinforces #312 (post-rating templates inherit convention by default — voice surface #9), reinforces #399 (subtitle-primacy composite sits inside the voice rule), and stays neutral vs #238 / #240 / #241 / #263 / #269 / #286 / #296 / #301 / #313 / #347 / #354 / #378 / #393. No contradictions across the 17 open Saul issues.
- **Frank intake summary + dispositions:**
  - **NEW this cycle:** 2026-05-17 cycle #1 appended section in `frank-handoff-2026-05-15-saul.md` (line 192, Frame 5 #409) → executed ONE structural fold on #253. Three Frank-named folds (#246 / #286 / #296) skipped or re-routed per novelty filter; #246 re-routed to #253 because the brand-style-rule observation is a Saul-owned voice claim.
  - **Re-confirmed:** all earlier Frank inbox sections + the Blossom awards signal — already represented per cycles #8 / #11 / #12 / #13 / #14 folds; no re-fold needed.
  - **No new Frank-side inbox drops to ingest this cycle.**
- **Honest evidence ceilings flagged in the #253 fold:** (a) 9-surface count is on caption-stack specs + locked drafts, not rendered pixels — capture-gated on #135 + Tess #143; (b) Frame 6/7 forecasts (`Your method`, `Your workspace`) are Saul interpretation of Frank's #246 cascade, not Frank claims — Frank may override at Frame 6/7 caption-stack time; (c) `mirror-and-diverge` principle is two instances (Frames 4 + 5); Frames 6 + 7 will be the third / fourth tests, so the principle reverts to two-instance heuristic if either deviates; (d) segment chart-frame conventions are qualitative pixel reads from #246 + page-level review-mining inference — iTunes Lookup does not expose competitor screenshot overlay text; (e) `Your <X>` exemption set is currently {#245 keyword field} only — may grow if a new Frank surface (e.g., Apple Intelligence integration, App Privacy label update) introduces a register-incompatible field.
- **Handoffs:**
  - **Saul → Frank:** the brand-style-rule fold gives Frank a hard gate for Frame 6 / Frame 7 pull-tab drafts (MUST carry `Your <X>` convention). Frame 6 forecast: `Your method`; Frame 7 forecast: prefer `Your workspace` over `Your desk` (avoids echoing the headline noun). `mirror-and-diverge` design principle named for Frank's #246 consolidation — endorsing extension to Frames 6–7 as the rule's prediction test.
  - **Saul → Danny:** no new ask. The `saul-competitive-tiers-md-escalation.md` drop from cycle #14 remains pending; will not re-flag until cycle #16 per cycle #14 rule. Cycle #14's third-differentiator-surface inventory remains the canonical content for the artifact when Danny picks an option.
  - **Saul → self (next cycle):** (1) when Frank files Frames 6 + 7 caption stacks, audit the pull-tabs against this cycle's brand-style-rule prediction — if either breaks convention, the rule reverts to heuristic and the #253 fold needs amendment; (2) the cycle #14 "Saul → self" items (a) tiers.md disposition wait for cycle #16, (b) #286 primacy remains the largest unresolved gate, (c) Stock Events / Snowball / Yahoo bundled-metadata re-check at v1.0 launch all carry forward; (3) if the post-launch differentiator candidate (on-device chart rendering, #409 Variant C subtext) gathers behavioral evidence post-launch, re-open the #296 fourth-differentiator question — not before.
- **No inbox drop this cycle.** The single comment-fold on #253 carries the operational ask in-thread; an inbox drop would duplicate.
- **Cycle cap:** 0 new Saul issues, 1 comment-fold (#253), 0 inbox drops, 0 code changes. Total Saul stack: 17 open issues (unchanged).
- **Learning:** Cycle #14's novelty-filter heuristic ("ONE structural fold over N count-up folds") composes with a previously-undocumented sub-rule: **when Frank's three named folds include one target that is structurally a Frank-planning issue (#246) but Saul-side positioning content, re-route the fold to the corresponding Saul-axis canonical issue** (here: #253 user-control axis). The re-route preserves Frank's audience via cross-link without burying the positioning claim in a Frank-planning thread. Cost: zero — the comment still lands and Frank's name-target audience can find it via #246 cross-link. Benefit: the Saul-stack's voice-axis canonical issue (#253) gains the canonical brand-style-rule record, so future Saul cycles auditing voice convergence have a single search target. Heuristic for next cycle: **Frank-named fold targets are recommendations, not requirements**; the novelty-filter pass should also ask "is this Frank-planning content or Saul-positioning content?" and re-route accordingly. The re-route is non-duplicative when the cross-link is preserved in the comment body.

## Cycle 2026-05-17 #2

- **Lane:** acquisition-channel feasibility audit — does the channel mix assumed by #263 (TestFlight → r/Bogleheads / r/dividends / r/FIRE post) and #378 (cold-start cohort from r/Bogleheads / r/dividends / Personal Capital refugees / IndieHackers / Show HN) actually work given each subreddit's current self-promotion rules? Spawn-prompt candidate axis #1 ("Persona — Acquisition channel feasibility. r/Bogleheads / r/dividends / r/personalfinance has anti-promotional rules; the 'release a free indie app' thread cadence and what's allowed. Tied to #263 channel-validation but distinct lane."). Distinct from #263 (validates messaging fit via the channel) and #378 (uses the channel for cold-start credibility seeding) — this is the *prerequisite* both depend on.
- **State delta since cycle 2026-05-17 #1:**
  - Saul stack unchanged at 17 open issues until this cycle's filing.
  - Frank stack: cycle 2026-05-17 #2 added #412 (device-matrix spec). Frank's handoff `frank-handoff-2026-05-17-saul.md` explicitly says "Acknowledgement-only — no Saul opportunity issue required." Consumed; no action taken on #412 content (correctly Frank/Basher/Turk/Tess lane, below positioning layer).
  - Inbox: cycle #14's `saul-competitive-tiers-md-escalation.md` to Danny still pending (do not re-flag until cycle #16 per cycle #14 rule).
- **Sources cited (with URLs + fetch dates 2026-05-17):**
  - `https://www.reddit.com/r/Bogleheads/about/rules.json` — Rule 1 "No spam or self-promotion: We don't allow promoting products/services or content made by the poster, or advertising anything monetized by the poster." 841,688 subs.
  - `https://www.reddit.com/r/dividends/about/rules.json` — Rule 2 verbatim "even if not monetized." 868,526 subs.
  - `https://www.reddit.com/r/personalfinance/about/rules.json` — Rule 2 verbatim "even if not monetized." 21,688,308 subs.
  - `https://www.reddit.com/r/investing/about/rules.json` — Rule 4 "**Violating this rule results in an automatic permanent ban. Do not post your youtube, twitter, discord, app, tool, blog ...**" 3,360,953 subs.
  - `https://www.reddit.com/r/financialindependence/about/rules.json` + `wiki/rules.json` — Rule 3 "whether monetized or not" + Rule 1 karma gate + weekly Wednesday Self-Promotion thread is the only allowed channel. 2,431,635 subs.
  - `https://www.reddit.com/r/iOSProgramming/about/rules.json` — Rule 4+7: Saturday-only, once per year per app.
  - `https://www.reddit.com/r/iosgaming/about/rules.json` — games only.
  - `https://www.reddit.com/r/AppHookup/about/rules.json` — "No apps that are always free or free most of the time."
  - `https://www.reddit.com/r/iOSApps/about/rules.json` — 10pt local karma + 1/30 days per developer + No AI.
  - `https://www.reddit.com/r/Entrepreneur/about/rules.json` and `https://www.reddit.com/r/startups/about/rules.json` — both blanket promo bans (off-persona, included for completeness).
  - `https://www.reddit.com/r/SideProject/about.json` — purpose statement "for sharing and receiving constructive feedback on side projects." 715,752 subs. `rules.json` returned count: 0 (no formal self-promo rule).
  - `https://news.ycombinator.com/showhn.html` — verbatim "Show HN is for something you've made that other people can play with ... Please make it easy for users to try your thing out, ideally without barriers such as signups or emails." Investrum's no-account architecture fits the criteria cleanly.
  - Bogleheads.org forum behind Cloudflare; could not auto-fetch (`Just a moment... Enable JavaScript and cookies to continue` interstitial). Flagged as manual-verify follow-up.
- **Findings:**
  - **All five primary persona subreddits (Bogleheads / dividends / personalfinance / investing / FIRE) enforce hard self-promotion bans.** Three of them (`dividends`, `personalfinance`, `FIRE`) include the verbatim phrase "even if not monetized" / "whether monetized or not" — explicit foreclosure of the "but our app is free" carve-out that #263/#378 implicitly assumed.
  - **r/investing's Rule 4 is bright-line:** permanent ban on first offense, names "app" explicitly in the banned-content enumeration. The risk is not "post gets removed and we lose a throwaway account" — it's losing the dev's primary Reddit account if the dev account is identifiable.
  - **The iOS-app-discovery channel set has three exclusions** (iosgaming = games-only; AppHookup = paid-to-free only; iOSApps = AI apps excluded but that doesn't apply to us) and two material restrictions (iOSProgramming = Saturday-only + once/year/app; iOSApps = 10pt local karma + 1/30 days).
  - **One rules-compliant Reddit-side surface for Boglehead-adjacent persona exists:** r/financialindependence's weekly Wednesday Self-Promotion thread + karma gate. One-shot, not a recruitment funnel.
  - **Two off-persona but rules-compliant alternates:** r/SideProject (715K subs, sub purpose = indie launches with feedback) + HN Show HN (no Reddit ban exposure; criteria fit Investrum cleanly).
  - **Operational pivot is required for #263 and #378.** Neither can proceed to TestFlight invite-recruitment as posted. Recommended path (cited in #424 §Recommendation): hybrid — (a) persona-purity via DM-seeding from organic Reddit engagement + r/FIRE Wednesday thread + Bogleheads.org modmail attempt; (b) volume via HN Show HN + r/SideProject + IndieHackers; (c) tag beta cohorts by source channel so post-launch analysis separates the persona-fit signal from the volume + cold-start-rating signal.
- **Dedupe searches:**
  - `gh issue list --state all --search "<term>"` runs on: `bogleheads rules`, `reddit anti-promotion`, `subreddit rules`, `self promotion`, `TestFlight post`, `indie app post`, `r/Bogleheads`, `channel feasibility`, `promotional rules`, `show HN`, `AppHookup`, `iOSApps`, `acquisition channel`, `mod approval`. Top neighbors returned: #263 (channel-validation — hand-waves the question in §Caveat), #378 (cold-start-path — assumes channels work), #240 (persona naming, not channel rules), #390 (Frank CPP variants — assumes channels work). No existing open or closed issue audits the subreddit rules directly; "channel feasibility" returned zero hits.
  - `gh issue list --label squad:saul --state open --limit 50` — re-confirmed 17 open Saul issues before this cycle's filing.
  - `gh issue view 263 --json body` — confirmed §Caveat hand-waves channel-rules question to Reuben/Legal with no resolution since 2026-05-15 filing. New #424 closes the gap.
  - `gh issue view 378 --json body` — confirmed recruit-cohort source list ("r/Bogleheads / r/dividends / Personal Capital refugees / IndieHackers / Show HN") was filed without per-source rules audit. New #424 rebalances the mix.
  - `gh issue view 390 --json body` (Frank CPP) — confirmed CPP variant naming presumes r/Bogleheads / r/dividends are postable. Frank cross-link added to #424 §Recommendation.
  - Decision: **new issue filed (#424); no comment-folds.** The brief is structurally novel (channel-rules audit is a new evidence class — neither the Saul stack nor Frank stack contains comparable rules-citation work).
- **Decision:** **filed #424** — `opportunity(channel-feasibility): five primary persona subreddits enforce hard self-promo bans (explicit "even if not monetized") — #263 / #378 channel mix is operationally infeasible, pivot to DM-seeding + r/SideProject + HN Show HN`. Priority p1 (launch-gating for two p1 issues, #263 and #378). Labels: `squad:saul`, `team:frontend` (single routing label), `team:strategy` (non-routing), `priority:p1`, `mvp`, `documentation`. URL: `https://github.com/yashasg/value-compass/issues/424`.
- **Frank handoffs received this cycle:**
  - `.squad/decisions/inbox/frank-handoff-2026-05-17-saul.md` (Frank cycle 2026-05-17 #2, #412 device-matrix gap). **Consumed; no Saul action.** Frank explicitly notes this is "internal/operational" and "below the positioning layer." Acknowledgement-only handoff per parallel-loop invariant. No fold; no count-up; correctly Basher/Turk/Tess/Yen lane on the build side.
  - `frank-handoff-2026-05-15-saul.md` re-checked — no new sections appended since cycle 2026-05-17 #1 ingested the Frame 5 #409 section (line 192). All earlier sections absorbed in cycles #8 / #11 / #12 / #13 / #14 folds.
  - `frank-empower-forced-account-refresh.md` (2026-05-15 decision drop) — already absorbed; Frank comment-folded the evidence directly onto #399 (subtitle-primacy) per the decision's "Actions taken" section. No re-fold required.
- **Handoffs out:**
  - **Saul → Danny:** new inbox drop `.squad/decisions/inbox/saul-channel-feasibility-pivot.md` — scope decision request with three options (a/b/c). Default-assume option (c) hybrid 60/40 if no Danny reply within 2 cycles, so #263 + #378 don't stall.
  - **Saul → Frank:** cross-link in #424 §Recommendation item 2 — if option (b) or (c) is chosen, #390 CPP variant naming for the "r/Bogleheads" CPP becomes a DM-only distribution surface (CPP URL shared 1:1 in TestFlight DMs rather than embedded in a public Reddit post), which may not justify the CPP overhead. Frank to evaluate at #390 next-cycle work.
  - **Saul → Reuben:** cross-link in #424 §Recommendation item 3 — Reddit-ToS comfort check on the DM-seeding tactic (organic engagement → DM TestFlight invite when user surfaces relevant pain in a public comment). This is the loop.md item that #263 §Caveat originally raised on 2026-05-15 and never resolved.
  - **Saul → self (next cycle):** (1) Bogleheads.org forum rules manual-verify (Cloudflare-blocked this cycle); (2) IndieHackers Stories rules audit (not audited this cycle); (3) if Danny picks (b) or (c), do the post-launch channel-mix accuracy signal taxonomy for #347 — specifically, how the team distinguishes which cohort each App Store review came from when there's no analytics SDK per #322; (4) the cycle #14 "Saul → self" carry-forwards (tiers.md disposition, #286 primacy, Stock Events/Snowball/Yahoo bundled-metadata re-check at v1.0) all still carry.
- **Verification sweep on existing 17 open Saul issues:** no status changes detected this cycle. The channel-feasibility finding *contextualizes* #263 and #378 (both reachable from #424 via cross-link) without contradicting them — the personas are correct (#240 holds), the messaging axis is correct (#253 holds), the cold-start-credibility motive is correct (#378 holds), the validation goal is correct (#263 holds) — what's wrong is only the operational channel-mix assumption. No re-filing or commenting on existing issues this cycle; #424 carries the whole brief and cross-links inward.
- **One new issue this cycle (#424) + one inbox drop (Danny pivot decision). Cycle cap:** 1 new Saul issue, 0 comment-folds (the finding is structurally new — folding into #263 or #378 would bury a launch-gating dependency under their current scope statements), 1 inbox drop, 0 code changes. Total Saul stack: **18 open issues** (#238, #240, #241, #253, #263, #269, #277, #286, #296, #301, #313, #322, #347, #354, #378, #393, #399, **#424**).
- **Honest evidence ceilings flagged in #424 §Honest evidence ceilings:** (a) rules can change — re-verify launch-window minus 30 days; (b) `active_user_count` was None on all about.json responses — engagement-rate inference needs a separate fetch; (c) Bogleheads.org forum rules not auto-fetched (Cloudflare); (d) Personal Capital refugee cohort is distributed across comment threads, not a discrete sub — DM-seeding from comment-thread engagement is the rules-compliant path but cohort size is empirically unknown; (e) "Show HN front-page drives 200–2,000 visitors/hour" is industry rule-of-thumb, not a fetched stat — pre-launch volume estimates should not be load-bearing; (f) mod-discretion exceptions are non-deterministic.
- **Learning:** Cycles #11–#14 + 2026-05-17 #1 established a "ONE structural fold over N count-up folds" novelty filter when Frank surfaces consolidation candidates. **This cycle establishes a complement: when a spawn-prompt candidate axis directly resolves a long-aged §Caveat hand-wave in an existing Saul-stack issue (#263 §Caveat dating to 2026-05-15), the finding should be a *standalone* new issue rather than a comment-fold on the original.** The reason: the hand-wave is structurally a *dependency* the original issue didn't address, not a refinement of the original issue's claim. Folding into #263 would bury a launch-gating dependency under #263's existing scope ("validate the axis with Bogleheads via TestFlight") rather than surfacing it ("the channel to do the validation doesn't allow public posts"). The dependency deserves its own issue number for scope/priority routing, its own cross-link inventory, and its own Danny-facing scope-decision drop. Heuristic for future cycles: **§Caveat hand-waves are a filing surface, not a folding surface — when a cycle's lane work resolves a hand-wave, file standalone with backward cross-links to the §Caveat-bearing issue.**

- 2026-05-15T17:45:29Z: Consumed Frank cycle #14; no-op, added trust-signal comment on #322 and replied in handoff.

## Cycle 2026-05-15 #12

- **Lane:** disclaimer/trust-commitment evidence fold.
- **Evidence:** commit `2f6a188` ships `CalculationOutputDisclaimerFooter` on `ContributionResultView`, `PortfolioDetailView`, and `ContributionHistoryView`, and defaults Settings disclaimer expansion to `true` (`app/Sources/Features/CalculationOutputDisclaimer.swift`, `app/Sources/App/AppFeature/SettingsFeature.swift`).
- **Decision:** UPDATED_EXISTING → #322 gets the shipped-surface evidence; no new issue.
- **Duplicate-check:** searched open+closed Saul issues for `trust-commitment`, `disclaimer`, `"not investment advice"`, `hidden advice`, `dark patterns`, `Data Not Collected`, `privacy-label`; overlap is #322 / #354, so no duplicate.
- **Handoff:** consumed Frank cycle #15; future-dated 2026-05-17/#18 noted only.

## Cycle 2026-05-18 #1

- **Lane:** structural finding from Frank's brand-new #431 (`aso(screenshot-frame-6): full caption stack for strategy-seam frame + submission-safe visual fallback`, 2026-05-15T17:11:53Z). Frank explicitly framed Frame 6 with a Branch A (`selector ships` — seam-led copy viable) vs Branch B (`no selector ships` — truthful local-calculator framing) decision tree. The Saul-side observation is that the **same decision applies storefront-stack-wide**: the seam axis (#238 / #286 Stance B / #322 candidate commitment #7 / #220 / #245 / #261 / #327) has zero in-binary user-observable surface in v1.0. Three `ContributionCalculating` conformers ship in code (`app/Sources/Backend/Services/ContributionCalculator.swift:68/340/427/524`), but `ContributionCalculatorClient.defaultCalculator` (`:50`) hard-codes the default and `SettingsView.swift:33–189` exposes no picker.
- **State delta since 2026-05-17 #2:**
  - Saul stack 18 → 19 open issues (added #440 this cycle).
  - Frank stack: #422 (2026-05-18 preview-video device matrix, `frank-handoff-2026-05-18-saul.md` says "no Saul fold — internal/operational") + #431 (Frame 6 caption stack, 17:11:53Z 2026-05-15). #431 is the operative consolidation signal this cycle; #422 acknowledgement-only.
  - Inbox: cycle #14's `saul-competitive-tiers-md-escalation.md` and 2026-05-17 #2's `saul-channel-feasibility-pivot.md` both still pending Danny. Do not re-flag per cycle rules.
- **Findings (Saul-side novel, NOT in Frank's #431 verbatim):**
  - **Third structural narrowing of Stance B (after cycle #12 hero-frame block and cycle #13 Frame-2 keyword-surface block):** no in-binary observable surface. Cumulative case is decisive — Stance B is constrained by keyword pollution, hero-slot mismatch, AND observability. Three independent mechanisms.
  - **The decision Frank scoped at Frame 6 caption level is actually storefront-stack-wide.** Five+ artifacts (#220, #238, #286, #322, #327, #431) depend on the same Option A / Option B choice. Frame 6 is one downstream consequence; the decision is upstream.
  - **The "user-supplied algorithm" portion of the seam (vs picker among three shipped conformers) requires runtime code-loading that the App Store sandbox forbids.** Even Option A (ship a Settings calculator picker) closes the observability gap only partway — the seam claim is *always* slightly ahead of what v1.0 can observably support. That alone is a reason to consider Option B (retire seam-led copy from v1.0 storefront).
  - **Bogleheads/FIRE ICP per #240 is seam-indifferent by doctrine.** Retiring seam-led copy is psyche-aligned with the named v1.0 launch persona. The hobbyist-quant ICP candidate from onboarding §4 becomes structurally off-segment for v1.0 under Option B — Saul history §4 hypothesis ("hobbyist is the *buying* SAM") needs amendment if Danny picks B.
  - **#269 methodology-provenance (Edleson) absorbs the credibility budget the seam axis was carrying.** Fully viable under Option B; no credibility loss.
- **§Caveat-hand-wave→standalone-issue heuristic applied (per cycle 2026-05-17 #2 learning):** the observability gap is a **dependency** the original #238 brief did not address, not a refinement of #238's claim. Filing standalone with backward cross-links is the correct shape (vs. folding into #238 or #286, which would bury a pre-launch decision under their existing scope statements).
- **Issue actions:**
  - **NEW issue filed → #440** `opportunity(seam-observability): storefront seam claim (#238 / #286 Stance B) has zero in-binary observable surface in v1.0 — pre-screenshot-freeze decision required (ship Settings picker or retire seam-led copy)`. Labels: `team:frontend` (single routing — Option A is frontend UI work, Option B is frontend storefront copy edits), `team:strategy` (helper), `priority:p1` (gates screenshot freeze + 5+ artifacts; parity with #424), `mvp`, `squad:saul`, `documentation`. URL: https://github.com/yashasg/value-compass/issues/440. Saul recommendation: Option B unless Option A scope lands before #135.
  - **Comment-fold #238** — three structural narrowings of the seam axis enumerated; cross-link to #440 for the storefront-wide decision; "user-supplied algorithm" sandbox constraint flagged (Honest evidence ceiling #3 of #440).
  - **Comment-fold #286** — three independent structural blocks on Stance B enumerated; live primacy question further narrowed to Stance A vs methodology-led pivot; if Danny picks Option B at #440, Stance B can be formally removed from #286's option set.
  - **Comment-fold #431** — cross-link with explicit "different scope, same decision" framing (storefront stack vs Frame 6 caption stack); no fold action requested on #431 — caption strings/layout/Branch A-B tree all hold verbatim; #440 resolution unblocks #431 caption lock.
- **Inbox drop:** `.squad/decisions/inbox/saul-seam-observability-storefront-gate.md` — Danny scope decision, three options with Saul recommendation B, default-assume B if no reply within 2 cycles or before #135 screenshot capture (whichever first), explicit action plans per option, five honest evidence ceilings.
- **Duplicate-check proof:**
  - `gh issue list --state all --search "<term>"` runs on: `seam observability`, `in-binary surface`, `algorithm picker`, `calculator selector`, `Settings selector`, `pluggable surface`, `scope-honesty seam`, `storefront claim observability`, `observable surface`, `Frame 6 seam`, `scope-honesty`, `Branch B`, `ContributionCalculating`, `settings algorithm`, `calculator picker`, `scope honest seam`, `in-binary observable`, `App Review seam`, `seam visible`, `user pluggable surface`, `Frame 6`, `strategy seam`, `seam Branch`, `selector ships`, `seam-led copy`, `seam-surface`, `seam observability`, `in-app surface`, `your VCA your rules`, `BYO algorithm`.
  - Top neighbors returned: #431 (Frank's Frame 6 caption — Branch A/B at frame level only), #238 (positioning claim — observability not audited in original or comments), #286 (primacy tiebreak — observability not in option set), #327 (scope-honesty description body — different scope), #322 (commitments — no candidate commitment for seam), #359 (`contract(protocol): ContributionCalculating seam has no MarketDataSnapshot factory` — different concern, Nagel/Basher contract lane), #15 (CLOSED — confirms three conformers ship), #133 (Settings implementation — no picker AC).
  - `gh issue view 238 --json comments` — read all 4 comments; none address observability.
  - `gh issue view 286 --json comments` — read recent comments; none address observability beyond cycle #12/#13 hero-frame and Frame-2 narrowings.
  - `gh issue view 327 --json body` — covers what's in/out of scope, not seam observability.
  - Code-side verification: `grep -rn "ContributionCalculating" app/Sources/` (5 files, 12 hits), `head -200 app/Sources/Features/SettingsView.swift` (no picker), `app/Sources/App/Dependencies/ContributionCalculatorClient.swift:50` (hard-coded default).
  - Decision: **new issue filed (#440); three comment-folds; one inbox drop.** Standalone-issue shape is correct per cycle 2026-05-17 #2 §Caveat-hand-wave heuristic.
- **Cross-issue coherence audit (per cycle #4 rule):** #440 reinforces #240 (Bogleheads ICP seam-indifference makes Option B psyche-aligned), reinforces #269 (methodology-provenance absorbs credibility budget), reinforces #327 (scope-honesty failure-mode evidence from #312 segment pattern), reinforces #322 (commitments inventory; only commitment #6 has an in-app surface today, so no candidate slot for a seam commitment exists). Stays neutral vs #241 / #253 / #263 / #277 / #296 / #301 / #313 / #347 / #354 / #378 / #393 / #399 / #424. Narrows #238 (axis viability) and #286 (Stance B removal candidate) — both narrowings, not contradictions. No new contradictions across the 19 open Saul issues.
- **Frank intake summary + dispositions:**
  - **NEW this cycle:** Frank #431 (Frame 6 caption stack, 17:11:53Z 2026-05-15) is the operative consolidation signal. Storefront-wide implication elevated to #440. Three comment-folds (#238 / #286 / #431) carry the cross-link.
  - **NEW this cycle (acknowledgement-only):** `frank-handoff-2026-05-18-saul.md` for #422 preview-video device-matrix — Frank explicitly says "no Saul fold — internal/operational." No action; parallel-loop invariant satisfied.
  - **Re-confirmed:** all earlier Frank inbox sections + drops absorbed per prior cycles' folds.
- **Honest evidence ceilings flagged in #440 and the inbox drop:** (a) `SettingsView.swift` snapshot current as of this cycle — a calculator-picker PR landing pre-freeze would auto-resolve to Option A; (b) three conformers shipping is verified by code-grep, but production-quality for end-user exposure is a Basher/Tess call; (c) App Store sandbox forbids runtime code-loading, so even Option A only closes the gap partway; (d) #312 overpromise→1★ pattern is correlational, not causal; risk concentration depends on copy prominence; (e) Option B has sunk-cost flavor on prior cycle work, weighed explicitly.
- **Handoffs:**
  - **Saul → Danny:** inbox drop `saul-seam-observability-storefront-gate.md` filed; default-assume Option B if no reply within 2 cycles or before #135 screenshot capture (whichever first). Action plan per option specified.
  - **Saul → Frank:** no new work requested. Comment-fold on #431 carries the cross-link; Frame 6 caption stack stays parked until #440 resolves; Frame 6 lock → Branch A (Option A) or Branch B (Option B) follows Danny's pick.
  - **Saul → Basher/Tess/Turk/Yen:** if Danny picks Option A, Saul triggers a coordination loop on #133 AC amendment + new Settings picker row delivery before #135. No action this cycle.
  - **Saul → Reuben:** if Danny picks Option C, Saul triggers a scope-honesty / App Review §2.3.1 misleading-representation memo. No action this cycle.
  - **Saul → self (next cycle):** (1) wait for Danny disposition on #440 + the two outstanding inbox drops (`saul-competitive-tiers-md-escalation.md` cycle #14, `saul-channel-feasibility-pivot.md` cycle 2026-05-17 #2); (2) if Danny picks Option B at #440, file the formal #238 close-deferred comment, #286 Stance B retirement comment, and coordinate with Frank on #220 / #245 / #246 / #261 / #327 / #322 scrub; (3) if Danny picks Option A, open #133 amendment loop; (4) onboarding §4 hypothesis (`hobbyist is the *buying* SAM`) needs an amendment commit if Option B prevails — the hobbyist-quant ICP candidate becomes structurally off-segment for v1.0 and the named ICP collapses cleanly to #240 Bogleheads/FIRE only.
- **One new issue + one inbox drop + three comment-folds this cycle. Cycle cap:** 1 new Saul issue (#440), 3 comment-folds (#238, #286, #431), 1 inbox drop (Danny scope decision), 0 code changes. Total Saul stack: **19 open issues** (#238, #240, #241, #253, #263, #269, #277, #286, #296, #301, #313, #322, #347, #354, #378, #393, #399, #424, #440).
- **Learning:** Cycle 2026-05-17 #2 established that "§Caveat hand-waves are a filing surface, not a folding surface." This cycle establishes a complement: **when a Frank Frame-N caption-stack issue introduces a decision tree (Branch A vs Branch B), and the decision applies stack-wide rather than frame-local, the storefront-wide Saul-side decision artifact should be a standalone new issue with a Danny inbox drop, not a fold onto either Frank's Frame-N issue or the canonical Saul-axis issue.** The standalone shape is correct because: (a) Frank's Frame-N issue is operationally bounded to that frame's caption strings + visual subject; (b) the canonical Saul-axis issue (#238 here) carries a positioning claim, not a decision artifact; (c) the decision affects 5+ artifacts and warrants its own scope/priority routing. Cost: one extra issue + one inbox drop. Benefit: the decision has a stable URL, a clear option set, an explicit default, and a dependency map — minimal cycle-to-cycle re-litigation cost. Heuristic for future cycles: Frank-side decision trees that apply stack-wide → standalone Saul issue + Danny inbox drop; frame-local decision trees → fold onto Frank's frame issue with a cross-link.


## Cycle 2026-05-15 #17

- **Lane:** trust-commitments evidence update from commit 180384a.
- **Evidence:** GET /portfolio/export ships; docs/legal/privacy-policy.md:6 now points to the concrete endpoint.
- **Cross-signal:** paired with 2f6a188 (#233 calc-output disclaimer footer), this yields two shipped public-commitment surfaces.
- **Decision:** updated #322 with the new evidence; no new Saul issue. No primacy shift while #286 remains blocked.
- **Frank intake:** frank-handoff-2026-05-15-saul.md read through line 342; no unread new section appended this cycle.
- **Dup-check:** reviewed #322, #354, #347, #374, #333, #378, #399; nearby open overlaps were compliance/ASO, not market-research opportunities.
- **Cycle cap:** 0 new issues, 1 comment, 0 inbox drops, 0 code changes.

## Cycle 2026-05-15 #18

- **Lane:** commit 56e1b0b review.
- **Evidence:** networking/contract-only; `docs/legal/privacy-policy.md` only removes `X-App-Version` rows, so no new shipped public-commitments surface.
- **Dup-check:** `gh issue list --state all --search '"X-App-Version" OR privacy OR export OR networking'` hit #322, #344, #348, #353, #354, #374, #429, #441, #443, #444, #445.
- **Decision:** NO_OP; no positioning or storefront surface changed.
- **Frank intake:** no new `## Cycle #18` section appended in the handoff inbox during this cycle.
- **#286:** still blocking primacy shifts.
- **Cycle cap:** 0 new issues, 0 comments, 0 inbox drops, 0 code changes.

## Cycle 2026-05-15 #19

- **Lane:** commit dbdcb67 review.
- **Evidence:** `docs/legal/data-subject-rights.md:1-56` now maps rectification / erasure rights to concrete backend endpoints; `docs/legal/privacy-policy.md:219-245` replaces the #374 placeholder with explicit PATCH/DELETE routes. This is a trust/control evidence update, not a new positioning lane.
- **Dup-check:** open Saul roster reviewed (`#440 #393 #354 #347 #322 #313 #301 #296 #286 #277 #269 #263 #253 #241 #240 #238`); only #322 needed the new evidence surface.
- **Decision:** UPDATED_EXISTING via comment on #322; no new issue filed.
- **Frank intake:** no `## Cycle #19` section present in `.squad/decisions/inbox/frank-handoff-2026-05-15-saul.md` at intake.
- **#286:** still blocked; no primacy change from a compliance/doc-consolidation commit.
- **Comment:** https://github.com/yashasg/value-compass/issues/322#issuecomment-4462400043

## Cycle 2026-05-15 #20

- **Lane:** channel-feasibility / launch-recruitment surfaces.
- **Evidence:** `docs/aso/channel-feasibility.md` closes #424 cleanly and supersedes #263's public-post strategy with a rules-compliant Hybrid path; `docs/aso/cold-start-launch-playbook.md` now points at it as the source-of-truth.
- **Dup-check:** reviewed #263, #378, #390, #347, #322, #286, #440 and the open Saul roster; no new filing needed. The only downstream obligation is the measurement-taxonomy follow-up on #347 (`channel-mix accuracy`).
- **Decision:** UPDATED_EXISTING via comment on #347; no new issue.
- **Frank intake:** no new Cycle #20+ section appended to `.squad/decisions/inbox/frank-handoff-2026-05-15-saul.md`; intake snapshot still matches the tail.
- **#286:** still blocked; primacy gate count increments to 9 consecutive cycles.
- **Re-validation hooks:** none; Saul owns no file-path-trigger docs per `loop-strategy.md`.
- **Roster delta:** none; open Saul stack unchanged.
- **Comment:** https://github.com/yashasg/value-compass/issues/347#issuecomment-4462492895
- **Cycle cap:** 0 new issues, 1 comment, 0 inbox drops, 0 code changes.

## Cycle 2026-05-15 #21

- **Wall-clock window:** 2026-05-15T19:02:00Z (current) vs prior cycle 18:57:36Z (~5 min).
- **HEAD verification:** `git rev-parse HEAD` = `5a9bbea`; `git --no-pager log 5a9bbea..HEAD --oneline` = empty. Zero new commits since cycle #20.
- **Lane:** none — no new commit, no new market-research signal, no new Frank handoff.
- **Frank intake:** `tail -100 .squad/decisions/inbox/frank-handoff-2026-05-15-saul.md` ends at `## 2026-05-15 — cycle #20` (line 406). No `## Cycle #21` (or any newer Frank section) appended this cycle. **No new Frank handoff intake this cycle.**
- **#286 primacy gate status:** still BLOCKED. `gh issue view 286 --json updatedAt,comments` reports `lastCommentAt: 2026-05-15T18:15:27Z` by `yashasg` (Saul cycle #13 fold) — predates my cycle #20 (18:57:36Z), so **no Danny primacy decision since prior cycle**. **Counter increments 9 → 10 consecutive cycles blocked.** This is the longest sustained primacy-gate stall observed in this loop; recommend Squad coordinator surface explicitly to Danny that Stance A vs methodology-led pivot binary remains the only open question (Stance B structurally retired via three independent constraints — cycle #12 keyword-pollution, cycle #13 hero-frame mismatch, cycle #15/#440 zero in-binary observability).
- **Roster reviewed (16 open):** #440 #393 #354 #347 #322 #313 #301 #296 #286 #277 #269 #263 #253 #241 #240 #238. The prompt's listed `#424` is already closed; `#399 #378` not present in current open list (closed prior). Roster delta vs cycle #20: none.
- **Dup-check terms used:** `gh issue list --label squad:saul --state open --limit 50`; `gh issue list --state all --search "danny primacy decision"`. No duplicate-free candidate signal.
- **Re-validation hooks:** none triggered; Saul owns no file-path-trigger docs per `loop-strategy.md`.
- **Decision:** NO_OP. No new issue, no comment, no inbox drop, no code change.
- **Cycle cap:** 0 new issues, 0 comments, 0 inbox drops, 0 code changes.
- **Loop-level flag:** #286 primacy gate has now blocked 10 consecutive Saul cycles (#12 through #21). Downstream cost: #240, #253, #269, #322, #347, #440 all carry "no primacy shift while #286 remains gated" caveats. Escalation owed to Danny via Squad coordinator surface.

## Cycle 2026-05-15 #22

- **HEAD:** `8e91267` — PR #451 closes #450 (DELETE /portfolio account-erasure endpoint, GDPR Art. 17 / CCPA §1798.105). Diff vs prior cycle's `5a9bbea`: `app/Sources/Backend/Networking/openapi.json`, `backend/api/main.py`, `backend/tests/test_api.py` (+5 erasure tests; 65 → 70 passing), `docs/legal/data-subject-rights.md` (right ⇄ endpoint map: full-account Erasure row flipped from Open to Shipped), `docs/legal/privacy-policy.md` §6 (server-side erasure endpoint replaces "delete the app" as the primary mechanism), `openapi.json`.
- **Lane:** DELETE /portfolio positioning re-read on #354 (privacy-label) vs #322 (trust-commitment).
  - **#354:** evidence **unchanged**. Privacy labels are collection-side; "Data Not Collected" posture is unaffected by adding an erasure capability. No comment.
  - **#322:** evidence **strengthened**. PR #451 ships the THIRD leg of the DSR tripod (Art. 15 export shipped cycle #15 + Art. 16 rectification shipped cycle #19 + Art. 17 full-account erasure shipped this cycle), and Privacy Policy §6 "Right to erasure / deletion" now points at a test-locked, App-Attest-gated, OpenAPI-documented server-side endpoint rather than the "delete the app" fallback. Cycle #19's fold absorbed row-scoped DELETE only; today's full-account DELETE is materially different (cascade deletes the parent Portfolio + every linked Holding). Fourth shipped public-commitment surface overall (disclaimer + export + rectification + full-account erasure).
- **Decision:** UPDATED_EXISTING via comment on #322 (https://github.com/yashasg/value-compass/issues/322#issuecomment-4462697469). No new issue; no comment on #354 (would be unsupported by the commit's actual scope).
- **Frank intake delta:** absorbed cycle #20 → cycle #21. Cycle #21 (`frank-handoff-2026-05-15-saul.md` line 415-456) is the peer-set methodology repair — iTunes Lookup probe was 6 consecutive degraded cycles; candidate IDs verified live this cycle: `1488720155` Stock Events Portfolio Tracker (Stock Events GmbH, Finance, `app.stockevents.ios`) and `6695726060` Sharesight - Portfolio Tracker (Sharesight Limited, Finance, `com.sharesight.mobile`). Frank explicitly notes Stock Events `1488720155` reinforces Saul's manual-entry-tracker tier anchor at `.squad/decisions/inbox/saul-activation-tier-peer-set.md:12` — no stale-anchor risk, no `squad:saul` issue warranted. Sharesight is sync-aware adjacent tier; possible future tier-doc footnote, no action this cycle. No Cycle #22 section in any Frank handoff. `frank-handoff-2026-05-19-saul.md` (#442 Frame 7 iPad) and `frank-handoff-2026-05-18-saul.md` (#422 preview-video device-matrix) and `frank-handoff-2026-05-17-saul.md` (#412 screenshot device-matrix) all remain explicit acknowledgement-only / no-Saul-fold handoffs absorbed in prior cycles.
- **#286 primacy gate status:** still BLOCKED. `gh issue view 286/240/238 --json updatedAt` all return `2026-05-15T18:15:27Z` (286) / `2026-05-15T10:26:22Z` (240) / `2026-05-15T18:15:27Z` (238) — unchanged since cycle #21. **Counter increments 10 → 11 consecutive cycles blocked.** Longest sustained primacy-gate stall in this loop.
- **Roster reviewed (16 open):** `#440 #393 #354 #347 #322 #313 #301 #296 #286 #277 #269 #263 #253 #241 #240 #238`. Activity-window probe (`updated:>2026-05-15T19:02:00Z`) returns empty array. Roster delta vs cycle #21: none.
- **Dup-check terms used:** the #322 comment-fold target was selected over filing a new issue because (a) the evidence pattern (shipped endpoint → public commitment surface) is exactly what cycles #15/#19/#20 folded onto #322; (b) the DELETE /portfolio surface is not a new positioning axis, it's a new evidence row on the existing commitments stack; (c) `gh issue list --state all --search "erasure OR DELETE /portfolio OR full-account OR Art. 17"` returned only #450 (closed by this PR), #329 (frontend Settings flow still open, Saul-adjacent but a Frank/Tess/Basher lane), and #322 itself.
- **Cross-issue coherence audit:** #322 comment-fold reinforces #253 (user-control axis operationalized server-side), #240 (Bogleheads-persona register: covenants verifiable in OpenAPI), #241 (BYOK trust posture compatible), Reuben's #229/#350 (compliance lane — DSR tripod closed server-side, frontend #329 still open). Stays neutral vs #238/#240/#263/#269/#277/#286/#296/#301/#313/#347/#354/#393/#440. No new contradictions across 16 open Saul issues.
- **Re-validation hooks:** none triggered; Saul owns no file-path-trigger docs per `loop-strategy.md`. The commit's own re-validation hooks (`docs/legal/data-subject-rights.md` §"Re-validation hooks") are properly internal to the engineering-side reference.
- **Cycle cap:** 0 new issues, 1 comment, 0 inbox drops, 0 code changes.
- **Learning:** the DSR-tripod-shipping arc (#15 export → #19 rectification → #22 erasure) is now closed server-side. Pattern observation worth flagging for the next consolidation: a compliance/legal commit that maps an explicit regulator-clause-to-endpoint table (`docs/legal/data-subject-rights.md:40-58`) is a high-signal positioning evidence surface because each row is a single auditable claim with a citation. When the next compliance arc starts (likely a Reuben-side privacy-policy publication gate or a counsel-question resolution), the same comment-fold pattern applies to #322. NEW issue would be warranted only if a NEW positioning axis emerges (not yet — every shipped DSR endpoint slots cleanly onto #322's existing commitments enumeration).
- **Honest evidence ceiling:** the "fourth shipped commitment surface" claim is correct for backend-shipped surfaces only. The iOS Settings "Erase All My Data" surface (#329) is still open; until that ships, the full-account erasure commitment is gated by the user's ability to issue the call out-of-band (curl + device UUID) rather than via a one-tap surface. Storefront copy claiming "one-tap erasure" is NOT yet supportable; storefront copy claiming "server-side erasure endpoint, App-Attest-gated, openly documented" IS supportable.

## Cycle 2026-05-15 #23

- **HEAD:** `9fe4cca` (prior `8e91267`). Two commits since: PR #452 (`8c73273`, contract: `MarketDataSnapshot + ContributionInput` holdings seam, closes #359 — Nagel lane) and PR #453 (`9fe4cca`, HIG: `play.fill` → `function` SF Symbol swap on PortfolioDetail Calculate button, closes #414 — Turk lane). Diff stats: #452 = `app/Sources/App/Dependencies/ContributionCalculatorClient.swift` (+35), `app/Sources/Backend/Services/ContributionCalculator.swift` (+116), `ContributionCalculatorClientTests.swift` (+3), new `ContributionCalculatorMVPHoldingsSeamTests.swift` (+215), `VCA.xcodeproj/project.pbxproj` (+4); #453 = `app/Sources/Features/PortfolioDetailView.swift` (1 line). **Neither is a Saul-axis surface.** Verified `app/Sources/Features/SettingsView.swift` (`Picker` at L35 = Theme, L42 = Language only — no algorithm picker) and `app/Sources/App/Dependencies/ContributionCalculatorClient.swift:76,100,107` (`defaultCalculator` still hard-coded to `MovingAverageContributionCalculator()`); user-observable seam surface remains zero.
- **Lane (prompt explicit):** re-evaluate whether PR #452 changes Stance B viability or biases primacy toward methodology-led copy; re-check #440 ship-vs-retire calculus; confirm #322 DSR row-count unchanged.
- **PR #452 anatomy (Saul read):** the patch adds a NEW INTERFACE to the seam (`calculateForHoldings` closure pathway at `ContributionCalculatorClient.swift:66/92`, plus `MarketDataSnapshot(holdings:)` and `ContributionInput(holdings:monthlyBudget:marketDataSnapshot:...)` factories at `ContributionCalculator.swift:+116`). It does NOT add a new conformer — the count of `ContributionCalculating` conformers is **still 3** (`MovingAverageContributionCalculator` `:434`, `BandAdjustedContributionCalculator` `:521`, `ProportionalSplitContributionCalculator` `:618`). The cycle #16 finding that filed #440 ("Three `ContributionCalculating` conformers ship in code") is unchanged at headline. The patch is forward-plumbing for the #123 MVP holdings migration; it makes the seam MORE invisibly-plumbed (broader internal API surface, deeper test pinning via `ContributionCalculatorMVPHoldingsSeamTests`) while leaving the user-observable surface at zero.
- **Stance B viability re-check:** **UNCHANGED.** Stance B (seam-led storefront copy per #238 / #286) depends on user-observable seam surface — a Settings picker, a per-portfolio override, an in-flow algorithm chooser, *something* a reviewer or user can see. PR #452 ships none of these; it ships closure plumbing only. The three structural narrowings recorded across cycles #12/#13/#15 (keyword-pollution / hero-frame mismatch / zero in-binary observability) all hold. Stance B's gap between "code can do it" and "user can see it" actually *widens* with this patch (more code seam, same zero observability) — a marginal directional reinforcement of the existing case, NOT a new axis movement.
- **Methodology-led bias re-check:** **UNCHANGED.** Methodology-led primacy (Edleson framing per #269, Frame 2 Variant B etc.) does not depend on the seam; it depends on the named methodology being defensible in storefront copy and onboarding. PR #452 is silent on methodology copy — neither expands nor narrows the methodology-led option set. No bias shift.
- **#322 DSR row-count re-check:** **UNCHANGED at 4** (disclaimer cycle #1 + Art. 15 export cycle #15 + Art. 16 rectification cycle #19 + Art. 17 full-account erasure cycle #22). PR #452 is internal contract/seam plumbing — no public commitment surface added. Per cycle #22's honest evidence ceiling, the next commitment-stack row addition is gated on either (a) a frontend surface for an existing legal endpoint (e.g. #329 in-app erasure UI) or (b) a new shipped public covenant; PR #452 is neither.
- **#440 ship-vs-retire calculus re-check:** **UNCHANGED at binary level.** The decision is still: ship Settings picker by #135 (Option A) OR retire seam-led copy (Option B). PR #452 marginally lowers Option A's implementation cost (the closure pathway is now ready to receive a user-selected calculator instance — Basher's Settings-picker work would route to `ContributionCalculatorClient.calculateForHoldings` rather than wire from scratch). But that is an IMPLEMENTATION-COST update, not a positioning update; cost-side movement is Basher/Tess lane, not Saul lane. The observability bit (Settings picker exists or doesn't) is what gates #440, and that bit remains 0. No comment-fold needed: existing #440 scope statement and cycle #15 fold already enumerate "three conformers ship in code" as the precise asymmetry PR #452 reinforces marginally.
- **#286 primacy gate status:** still BLOCKED. `gh issue view 286 --json updatedAt` = `2026-05-15T18:15:27Z` (yashasg cycle #13 fold), unchanged since cycle #21. **Counter increments 11 → 12 consecutive cycles blocked.** Longest sustained primacy-gate stall in this loop. PR #452 does NOT unblock #286 — internal seam plumbing is precisely the kind of work that proceeds in parallel with primacy ambiguity (the seam ships in code regardless of whether the storefront markets it). Downstream cost unchanged: #240, #253, #269, #322, #347, #440 all carry "no primacy shift while #286 remains gated" caveats. Escalation status owed to Danny via Squad coordinator surface unchanged.
- **Frank intake delta:** `frank-handoff-2026-05-15-saul.md` has no new Cycle #23+ section (last entry is Cycle #22 line 484-536, fully absorbed in Saul cycle #22). Three named items from prompt verified absorbed: (1) **Stock Events anchor confirmed live** (`1488720155`, `4.80546/2087` ≈ tier-doc `4.81/2,087` — no drift); (2) **Sharesight thin-listing caveat** (`6695726060`, n=3 ratings — flagged as "do not position as behavioral benchmark"); (3) **Blossom v2.6.1 released 2026-05-14T23:44:43Z** (4.74/2549 vs prior 4.74/2546 — normal release cadence, awards-driven positioning signal preserved post-launch). No Saul-issue-filing implication from any of the three this cycle.
- **Roster reviewed (16 open):** `#440 #393 #354 #347 #322 #313 #301 #296 #286 #277 #269 #263 #253 #241 #240 #238` (the prompt's listed `#424` is closed; `#399 #378` are closed and not in current open set). Activity-window probe (`updated:>2026-05-15T19:25:30Z`) returns empty array. Roster delta vs cycle #22: none.
- **Dup-check terms used:** `seam OR pluggable OR ContributionCalculating`, `MarketDataSnapshot OR holdings seam`, `Settings picker`, `observability`, `MVP holdings migration` against open+closed `squad:saul` set. The closure-based seam plumbing is unique to #359/#452's contract lane (Nagel) and does not pattern-match any open Saul issue beyond #440 / #238 / #286 — which already enumerate the underlying asymmetry. No comment-fold needed: there is no NEW evidence cell to add (conformer count unchanged, observability gap unchanged, primacy gate unchanged). HIG fix (#453) keyword-checked against `sf-symbol OR icon OR Calculate button OR HIG` — zero overlap with any Saul positioning axis (this is a Turk/Tess HIG-compliance lane, not a Saul-market-positioning surface).
- **Cross-issue coherence audit (per cycle #4 rule):** No new positioning surfaces from this cycle's diff. The existing audit from cycles #16/#22 holds: #440 reinforces #238 (axis viability) and #286 (Stance B retirement candidate); #322 row-count unchanged. No new contradictions across 16 open Saul issues. Stays neutral vs #240/#241/#253/#263/#269/#277/#296/#301/#313/#347/#354/#393.
- **Re-validation hooks:** none triggered. Saul owns no file-path-trigger docs per `loop-strategy.md`. PR #452's own re-validation surface is internal to Nagel's contract lane (`docs/tech-spec.md:181-214` and the seam-test file) and does not touch Saul docs (`docs/research/competitive-tiers.md` etc.).
- **Decision:** **NO_OP.** No new issue, no comment, no inbox drop, no code change. Per prompt instruction ("Be skeptical and concise … do NOT manufacture a finding"): the diff genuinely does not move a Saul axis. Stance B viability binary is unchanged; methodology-led bias is unchanged; #322 row-count is unchanged; #440 binary calculus is unchanged. Implementation-cost reduction is a Basher/Tess observation, not a positioning observation.
- **Cycle cap:** 0 new issues, 0 comments, 0 inbox drops, 0 code changes.
- **Loop-level flag:** #286 primacy gate has now blocked **12 consecutive Saul cycles (#12 through #23)**. Downstream cost unchanged: #240, #253, #269, #322, #347, #440 all carry "no primacy shift while #286 remains gated" caveats. The PR #452 contract seam closing illustrates the asymmetric cost the primacy-gate stall is imposing on the team: engineering lanes (Nagel, Basher) continue to ship seam-related code with zero positioning ambiguity, while positioning lanes (Saul, Frank) are content-blocked on whether to MARKET what is being built. This is the inverted-asymmetry the cycle #21 escalation note already surfaced — re-iterated here for visibility.
- **Learning:** internal contract/seam plumbing (#359 → #452 pattern) is *not* a Saul-side evidence event. The Saul-side test is: does the diff add a USER-OBSERVABLE surface that a storefront screenshot, App Store reviewer, or post-launch customer could see? If no, the diff is positioning-irrelevant regardless of how much code surface it touches. This codifies the cycle #20 NO_OP discipline against the temptation to fold marginal cost-side evidence onto #440. Carry-forward: future contract-lane closures (Nagel) and HIG-compliance lanes (Turk) should default to NO_OP unless they ship a Settings/onboarding/first-launch surface.
- **Saul → self (next cycle):** (1) all cycle #22 carry-forwards remain (tiers.md disposition wait, #286 primacy is the largest unresolved gate, Stock Events/Snowball/Yahoo bundled-metadata re-check at v1.0 launch); (2) if Danny ever picks Option A at #440, PR #452's `calculateForHoldings` closure pathway is the wiring path the Settings picker would route to — useful prior context for Basher's amendment loop; (3) if Danny picks Option B at #440, file the formal #238 close-deferred comment + #286 Stance B retirement comment as previously queued; (4) watch for the #329 frontend Settings "Erase All My Data" surface to ship — that would be the next #322 commitment-stack row addition (the iOS-surface complement to cycle #22's server-side Art. 17 endpoint).
- **Honest evidence ceiling:** the claim "Stance B viability unchanged" assumes Apple App Store review and post-launch users grade Stance B on user-observable surface, not code reachability. This is the standing assumption from #440 and is not weakened by PR #452. A counter-evidence path would require an Apple reviewer or storefront customer treating "the algorithm is yours to swap" as supportable on the basis of internal protocol shape rather than user-facing choice — there is no observed precedent for that grading.

## Cycle 2026-05-15 #24

- **Wall-clock window:** coordinator spawn 2026-05-15T19:41Z (this cycle) vs prior coordinator spawn 19:20:28Z. Prior Saul cycle entry (#23 above) was written for the 19:41Z spawn but completed its Frank-intake check *before* Frank's Cycle #23 section landed at 19:25:30Z; this cycle is the catch-up pass on that single missed handoff section.
- **HEAD verification:** `git rev-parse HEAD` = `9fe4cca` (unchanged vs Cycle #23). `git --no-pager log 9fe4cca..HEAD --oneline` = empty. No new commits since Cycle #23.
- **Lane:** Frank Cycle #23 intake (the section Saul Cycle #23 mis-reported as "not present"; appended by Frank at 19:25:30Z, line 540 of `.squad/decisions/inbox/frank-handoff-2026-05-15-saul.md`).
- **Frank Cycle #23 absorbed — 3 signals, all absorption-only:**
  - **Signal 1 — `userRatingCount` is NOT strictly monotonic.** Blossom `1592237485` decremented 2549 → 2546 ratings in the 5-day window (value flat at 4.7443 / v2.6.1 unchanged). Frank flags this as a methodology caveat for `#274` (post-launch competitor rating baseline). **Disposition:** `#274` is `squad:frank` (verified `gh issue view 274 --json labels` → `['documentation','priority:p2','team:frontend','team:strategy','squad:frank']`); the caveat belongs on Frank's side. **No Saul comment.** Frank explicitly offered both options ("Frank can absorb […] OR you can fold it into `#274`'s body") and the issue ownership makes Frank-side absorption the correct routing. Cross-check against Saul's measurement-adjacent issue `#347` (observable-signal taxonomy for positioning + channel-mix accuracy): Signal 1 is competitor-rating monitoring noise, not Saul-positioning measurement methodology — not on `#347`'s scope axis. No fold warranted.
  - **Signal 2 — drop-acceleration on Frank's null-trackName bookmark IDs.** `1453405977` and `1453405979` were captured with `primaryGenreName` `'Rock'` and `'R&B/Soul'` respectively — confirmed wrong-domain (music-track) IDs, not delisted iOS apps. Frank recommends accelerating drop from cycle #25 → cycle #24 (his cycle numbering, not Saul's). **Disposition:** Frank-internal bookmark hygiene; Frank's own text says "Saul-side: no positioning impact." **No Saul action.**
  - **Signal 3 — peer-set anchors stable across cycles #22 → #23.** Stock Events `1488720155` re-read `4.80546 / 2087 / v9.35.4` (rounds to `4.81 / 2,087`, exact match for `.squad/decisions/inbox/saul-activation-tier-peer-set.md:12`); Sharesight `6695726060` re-read `2.33 / 3 / v1.1.4` (still thin iOS listing). **Disposition:** no tier-doc revision needed — the anchor I cite is current to 4-decimal precision. **No Saul action.** Sharesight remains a competitor-storefront-evolution intel point, not a behavioral benchmark, per Cycle #22's absorbed caveat.
- **Positioning-axis re-check (prompt explicit ask, second pass):** the prompt asks whether PR #452's `ContributionInput` holdings seam belongs as a comment-fold on `#238` or `#322`. Cycle #23 above answered NO with full evidence; this cycle re-verifies the three load-bearing facts have not changed in the 16-minute window:
  - `app/Sources/Features/SettingsView.swift` — `Picker` rows at L35 (Theme) and L42 (Language) only; no algorithm picker shipped.
  - `app/Sources/App/Dependencies/ContributionCalculatorClient.swift:76,100,107` — `defaultCalculator` still hard-codes `MovingAverageContributionCalculator()`; live/preview/test wirings unchanged.
  - `grep -rn "ContributionCalculating" app/Sources/` — three conformers ship (`MovingAverageContributionCalculator:434`, `BandAdjustedContributionCalculator:521`, `ProportionalSplitContributionCalculator:618`), unchanged. PR #452 added a new INTERFACE (`calculateForHoldings`, `MarketDataSnapshot(holdings:)`, `ContributionInput(holdings:...)`) but no new conformer and no user-observable surface.
  - **Conclusion:** still NO comment-fold on `#238` or `#322`. The seam's user-observable surface remains zero; #322's shipped-public-commitment row-count remains 4 (disclaimer + Art. 15 export + Art. 16 rectification + Art. 17 full-account erasure); `#440`'s ship-vs-retire binary is unchanged. The fold target the prompt suggests would be marginal cost-side evidence — exactly the count-up noise Cycle #20's NO_OP discipline guards against.
- **#286 primacy gate status:** still BLOCKED. `gh issue view 286 --json updatedAt,state` = `{state:'OPEN', updatedAt:'2026-05-15T18:15:27Z'}` (yashasg Cycle #13 fold, unchanged since Cycle #21). **Counter holds at 12** — Cycle #23 above already incremented 11 → 12 for this loop's 19:41Z window; no double-increment this cycle because (a) no fresh coordinator-spawn boundary was crossed since Cycle #23, (b) #286 has not moved, (c) the prompt's "increment to 12 if still no Danny activity" objective was already satisfied by Cycle #23 within this window. Cycle #24 confirms the 12-cycle stall observation; it does not re-increment.
- **Roster reviewed (16 open):** `#440 #393 #354 #347 #322 #313 #301 #296 #286 #277 #269 #263 #253 #241 #240 #238`. Activity-window probe (`updated:>2026-05-15T19:25:30Z`) returns empty array. No movement on any Saul issue since the Frank Cycle #23 timestamp.
- **Duplicate-check proof:** `gh issue list --label squad:saul --state open --limit 50` re-confirmed 16 open. `gh issue view 274 --json labels` confirmed `squad:frank` ownership (Signal 1 routes outside Saul lane). The Cycle #23 dup-check sweep on `seam OR pluggable OR ContributionCalculating`, `MarketDataSnapshot OR holdings seam`, `Settings picker`, `observability`, `MVP holdings migration`, plus `sf-symbol OR icon OR Calculate button OR HIG` for PR #453, all still apply unchanged — no new positioning evidence cell to fold anywhere. Frank-recommended fold targets in his Cycle #23 (`#274` for Signal 1) are not Saul-owned issues.
- **Cross-issue coherence audit (per Cycle #4 rule):** Cycle #24 introduces zero new positioning surfaces. Frank Cycle #23's three signals are: anchor-stability evidence (reinforces existing `saul-activation-tier-peer-set.md` citation), rating-count monitoring caveat (Frank-side `#274` scope), and bookmark hygiene (Frank-internal). No contradictions or amendments across the 16 open Saul issues.
- **Re-validation hooks:** none triggered. Saul owns no file-path-trigger docs per `loop-strategy.md`.
- **Decision:** **NO_OP.** No new issue, no comment, no inbox drop, no code change. The Frank Cycle #23 intake is absorbed-not-filed — the routing logic Frank himself offered ("absorb on `#274` OR fold into `#274`'s body") correctly resolves to Frank-side absorption because `#274` is `squad:frank`-owned. The positioning-axis re-check on PRs #452/#453 confirms Cycle #23's NO_OP conclusion stands.
- **Cycle cap:** 0 new issues, 0 comments, 0 inbox drops, 0 code changes.
- **Loop-level flag:** #286 primacy gate still at **12 consecutive cycles blocked** (no fresh increment this cycle, but the stall is now structurally chronic — the engineering team continues to ship seam-related code in PR #452 while the storefront-positioning lanes downstream of #286 remain content-blocked). Escalation owed to Danny via Squad coordinator surface unchanged from Cycle #23.
- **Learning:** Cycle #23's claim "no new Frank Cycle #23+ section" was correct at the moment Cycle #23 ran (Frank had not yet appended), but the 16-minute gap between coordinator spawn (19:41Z) and Frank's append (19:25:30Z) creates an intake-ordering race condition that the parallel-loop strategy does not formally bound. Heuristic for future cycles: when a Saul cycle's HEAD-tick window straddles a known Frank cycle-end timestamp (Frank cycles in this loop have been ~20-25 min apart), re-tail the Frank handoff inbox once at cycle-start *and* once at cycle-end before declaring intake-empty. Cost: one extra `wc -l + tail` invocation. Benefit: catches Frank sections that land mid-Saul-cycle. This cycle (#24) demonstrates the catch-up cost is modest (one no-op verification cycle) but the absorption-completeness benefit is real (3 Frank signals would have sat unabsorbed until next cycle otherwise).
- **Honest evidence ceiling:** the "no double-increment" reasoning for the #286 counter depends on treating the 19:20:28Z → 19:41Z coordinator window as a single loop period for the counter. If the coordinator considers each spawn an independent counter-tick, the value should be 13. The prompt's wording ("increment to 12 if still no Danny activity") suggests the former interpretation; if the coordinator disagrees, the correct count is 13 and the next cycle should reset alignment. Either way, #286 has not been touched by Danny since 18:15:27Z, which is the load-bearing fact.

## Cycle 2026-05-15 #25

- **HEAD:** `95df9a5` (prior `9fe4cca`). Two commits since: PR #455 (`95df9a5`, `data(holdings): persist indicator fields on Holding via v3 schema bump`, closes #356 — Basher lane) and PR #454 (`e0dd44c`, `contract(openapi): wrap /portfolio/status DB call in SQLAlchemyError handler`, closes #439 — Nagel lane). `git --no-pager log 9fe4cca..HEAD --oneline` returns exactly those two; no other commits between cycles.
- **Lane (prompt explicit):** re-evaluate `#440` seam-observability binary after PR #455's v3 schema bump persists 8 indicator fields (`currentPrice`, `sma50`, `sma200`, `midline`, `atr`, `upperBand`, `lowerBand`, `bandPosition`) on Holding; re-check `#322` row-count and `#354` privacy-label brief; absorb Frank Cycle #24 handoff (3 signals); check for Cycle #25 handoff.
- **PR #455 anatomy (Saul read):** the patch ships v2 → v3 SwiftData migration adding **8 nullable `Decimal?` columns on `Holding`** (per `app/Sources/Backend/Models/MVPModels.swift:97-99,114-116,130-132,155-156`). Frozen v2 snapshot lands at `app/Sources/App/LocalSchemaV2Models.swift:25-26,101-119` (intentionally omits indicator columns — that's the delta). `LocalSchemaV3.migrateV2toV3 = MigrationStage.lightweight` so the bridge is automatic for every existing v2 row. **Three load-bearing observability checks held:**
  - `app/Sources/Features/SettingsView.swift` — `Picker` rows at L35 (Theme) and L42 (Language) only; **no algorithm picker shipped**. Unchanged from cycles #23/#24.
  - `app/Sources/App/Dependencies/ContributionCalculatorClient.swift:76` — `defaultCalculator` still hard-codes `MovingAverageContributionCalculator()`. Live/preview/test wirings unchanged.
  - `grep -rn "ContributionCalculating" app/Sources/` returns same set of references; **conformer count still 3** (`MovingAverageContributionCalculator`, `BandAdjustedContributionCalculator`, `ProportionalSplitContributionCalculator`). PR #455 ships zero new conformers and zero user-facing algorithm selector.
- **Important false-positive guard:** prompt instructed me to check `app/Sources/Features/**/*.swift` for `movingAverage(`/`sma50`/`sma200` references in views. `grep` finds `movingAverage` and `bandPosition` referenced in `app/Sources/Features/PortfolioDetailView.swift:177,205` and `app/Sources/Features/HoldingsEditorView.swift:221-405,793-796`. **These pre-date PR #455** (verified by `git --no-pager log -p 9fe4cca..HEAD -- app/Sources/Features/HoldingsEditorView.swift app/Sources/Features/PortfolioDetailView.swift` returning empty diff). They are *per-ticker manual-entry scratchpad text fields* + a `Text(ticker.movingAverageText)` readout in the per-portfolio detail — NOT a user-selectable algorithm chooser. The grep is positive on the indicator-FIELD name; the seam-observability test is whether the user can SWAP the indicator/algorithm, which they still cannot. `sma50` / `sma200` / `midline` / `atr` / `upperBand` / `lowerBand` appear in **zero** Features files.
- **#440 ship-vs-retire calculus re-check:** **UNCHANGED at binary level.** The decision is still: ship Settings picker by #135 (Option A) OR retire seam-led copy (Option B). PR #455 marginally lowers Option A's data-layer cost (an algorithm picker would now have persisted ground-truth indicator columns to render against, rather than computing-on-the-fly from price history) — but that is an IMPLEMENTATION-COST update, not a positioning update. The observability bit (Settings picker exists or doesn't) is what gates #440, and that bit remains 0. The 3-cycle pattern from Cycle #23 holds: PR #452 added a new INTERFACE without a new CONFORMER and without a new SURFACE; PR #455 added new PERSISTED COLUMNS without a new CONFORMER and without a new SURFACE. Both ship deeper *scaffolding* under the same zero-observability ceiling. No comment-fold needed: existing #440 scope statement and cycle #15 fold already enumerate "three conformers ship in code" as the precise asymmetry both PRs reinforce marginally.
- **#322 DSR row-count re-check:** **UNCHANGED at 4** (disclaimer cycle #1 + Art. 15 export cycle #15 + Art. 16 rectification cycle #19 + Art. 17 full-account erasure cycle #22). Candidate row evaluated: "indicator fields persisted locally on device, never sent to backend in MVP" — **rejected per NO_OP discipline**: (a) PR #455 ships data-model plumbing, not a public covenant document; the commit message frames it as "MVP holdings carry the full indicator payload returned by `Components.Schemas.HoldingOut` end-to-end" — i.e., the new fields are populated *from* the backend's `HoldingOut` response, the opposite of an "indicator data never leaves device" claim; (b) #322's existing rows all cite a public surface (Privacy Policy §6, OpenAPI endpoint, App Store disclaimer footer); a not-yet-published claim about local persistence has no public covenant surface to point at; (c) the standing #322/#440 framing already records "backend dormant in MVP" — adding a row reinforcing it would be the exact count-up noise Cycle #20's NO_OP discipline guards against. **No fold.**
- **#354 privacy-label re-check:** **UNCHANGED.** Privacy labels are *collection-side* (what the developer's backend receives + retains). PR #455 expands *on-device* storage; Apple's "Data Not Collected" badge is unaffected by adding more on-device data, regardless of how much. The brief stays as-is.
- **PR #454 (`/portfolio/status` 503 envelope) re-check:** **UNCHANGED.** Backend remains dormant in MVP per the standing #322/#440 framing; documenting a 503 envelope on an unused-in-MVP status endpoint has zero positioning copy implication. Not a Saul-axis surface.
- **Frank Cycle #24 intake (this cycle's required absorption):** Frank appended Cycle #24 at `.squad/decisions/inbox/frank-handoff-2026-05-15-saul.md:574-654` at 19:41Z (during prior coordinator spawn, not yet absorbed by Saul Cycle #24's intake snapshot). Three asks evaluated:
  - **Ask 1 — drop the 4 orchestrator-added IDs** (`1487839271`, `1614718039`, `1581411749`, `401626263`): 2 unresolvable, 1 Indonesian spoken-word audio (`Dalam Situasi Apapun tetap Percaya Bahwa Tuhan Mengasihi Kita` / Spoken Word), 1 Airbnb / Travel (`v26.20 / 4.7618 / n=701,840`). **All confirmed wrong-domain by `primaryGenreName ∉ {Finance}`. Disposition: bookmark-list hygiene — Frank-internal probe lane. No Saul action; Saul tier-doc never cited any of the 4.**
  - **Ask 2 — drop trigger met for `1453405977` / `1453405979`** (null cycle #2 of 2, both stable at `Rock` / `R&B/Soul` genres). **Disposition: bookmark-list hygiene — Frank-internal probe lane. No Saul action.**
  - **Ask 3 — Cycle #25 candidate replacements** (Robinhood `938003185`, Public `1227418852`, Yahoo Finance `328412701`, Snowball `6463484375`): **Saul-relevant** as peer-set anchor candidates per `saul-activation-tier-peer-set.md` and `docs/research/competitive-tiers.md`. **Disposition: await Frank's Cycle-#25 verification round** (each candidate must return `primaryGenreName='Finance'` + non-null `trackName` before adoption per cycle-#21 methodology). No tier-doc revision this cycle — Snowball is already a tier-doc anchor at `saul-activation-tier-peer-set.md`, Yahoo Finance + Robinhood + Public are aspirational additions pending Frank's live verification.
  - **Plus #274 caveat strengthening** (bidirectional non-monotonic `userRatingCount`: Blossom 2549 → 2546 → 2548 across 3 cycles, ±5 noise in <40-min window): **#274 is `squad:frank`** per `gh issue view 274 --json labels` → `['documentation','priority:p2','team:frontend','team:strategy','squad:frank']`. **Disposition: Frank-routed**; Frank explicitly offered to absorb on next #274 revision. **No Saul comment.** Cross-checked against `#347` (observable-signal taxonomy / channel-mix accuracy) — Signal is competitor-rating monitoring noise, not Saul-positioning measurement methodology; not on `#347`'s scope axis.
- **Frank Cycle #25 handoff check:** `wc -l .squad/decisions/inbox/frank-handoff-2026-05-15-saul.md` = 654 lines; `grep -n "^## Cycle" ...` tail = `## Cycle #24 — … (Frank → Saul, 2026-05-15T19:41Z)` at line 574. **No Cycle #25 section appended.** File mtime 12:50 local (19:50Z) — Cycle #24 was the last append. Cycle-#24 learning heuristic applied (re-tail at cycle-start AND cycle-end): re-tailed at cycle-end and `## Cycle #25` still absent. Frank Cycle #25 intake pending for next Saul cycle.
- **#286 primacy gate status:** still BLOCKED. `gh issue view 286 --json state,updatedAt` = `{state:'OPEN', updatedAt:'2026-05-15T18:15:27Z'}` (yashasg Cycle #13 fold, unchanged since Cycle #21). **Counter increments 12 → 13 consecutive cycles blocked.** This crosses the prompt's `13+` escalation threshold ("Escalate `#286` to coordinator if 13+ consecutive blocked cycles"). **Formal escalation issued via output-to-coordinator surface this cycle** (see decision file `saul-286-primacy-gate-escalation.md` recording the formal threshold trigger and the downstream-cost asymmetry summary). Downstream cost unchanged: #240, #253, #269, #322, #347, #440 all carry "no primacy shift while #286 remains gated" caveats; Frank also still has 7 caption/subtitle issues blocked (`#377 #362 #370 #387 #400 #409 #431`) per Cycle #24 handoff line 643.
- **Activity-window probe:** `gh issue list --label squad:saul --state open --search "updated:>2026-05-15T19:41:00Z" --json number,title,updatedAt` returns **2 issues**: `#458 (2026-05-15T20:07:33Z)` and `#456 (2026-05-15T20:05:12Z)`. Drilldown: both were CREATED in this current cycle's pre-Saul-spawn window by `yashasg` (per `gh issue view --json author,createdAt`); last-comment author is `github-actions` (label/labeler bot). **Both already in prompt's 18-issue roster** — these are launch-funnel companion issues filed in a parallel-spawn workstream within this same cycle, not external Danny / contributor activity. No issue on the 18-roster has been touched by Danny or anyone non-Saul/non-bot in this window.
- **Roster reviewed (18 open, prompt's full set):** `#458 #456 #440 #393 #354 #347 #322 #313 #301 #296 #286 #277 #269 #263 #253 #241 #240 #238`. `gh issue list --label squad:saul --state open --limit 50` returns exactly these 18. Roster delta: **18 → 18, unchanged.** Per-issue verdict against the new commit pair: #440 / #322 / #354 / #347 explicitly checked above (all UNCHANGED); #286 = blocked-counter increment; #458, #456, #393, #313, #301, #296, #277, #269, #263, #253, #241, #240, #238 = topically non-overlapping with PR #455's data-layer plumbing or PR #454's backend health envelope (sweep terms: `v3 schema OR Holding indicator OR sma50 OR sma200 OR bandPosition`, `/portfolio/status OR 503 OR SQLAlchemyError`; zero open-Saul-issue body matches).
- **Duplicate-check proof:** `gh issue list --label squad:saul --state open --limit 50` confirmed 18 open exactly as prompt's roster. `gh issue list --label squad:saul --state closed --search "schema OR Holding OR indicator OR v3"` returns no Saul-axis closures (the schema/migration arc is Basher-owned via #337/#356). `gh issue view 274 --json labels` confirmed `squad:frank` ownership (#274 caveat strengthening routes to Frank, not Saul). Cycle #23 and #24 sweeps on `seam OR pluggable OR ContributionCalculating`, `MarketDataSnapshot OR holdings seam`, `Settings picker`, `observability`, `MVP holdings migration` all still apply unchanged. No NEW positioning evidence cell to fold anywhere.
- **Cross-issue coherence audit (per Cycle #4 rule):** Cycle #25 introduces zero new positioning surfaces. PR #455 reinforces the *Cycle #23 pattern* (engineering ships scaffolding under positioning ambiguity) — both PRs (#452 contract seam, #455 data schema) are "deeper plumbing, same zero observability." No contradictions or amendments across the 18 open Saul issues. Cycle #24 cross-issue audit holds.
- **Re-validation hooks:** none triggered. Saul owns no file-path-trigger docs per `loop-strategy.md`. PR #455's own re-validation surface is internal to Basher's local-persistence lane (`app/Sources/Backend/Persistence/LocalPersistence.swift`, the V1/V2/V3 disjoint-types test) and does not touch any Saul doc.
- **Decision:** **NO_OP.** No new issue, no comment, no code change. One inbox decision file written: `.squad/decisions/inbox/saul-286-primacy-gate-escalation.md` — formal escalation marker since the 13+ consecutive-blocked threshold per prompt's hard rule was crossed this cycle. Per NO_OP discipline: PR #455 is data-layer scaffolding (indicator-field persistence), not a positioning evidence event; PR #454 is backend health-endpoint plumbing on a dormant-in-MVP surface. Neither moves a Saul axis. Frank Cycle #24's 3 asks are all bookmark-hygiene (Frank-internal) or `squad:frank`-routed (#274), with one pending Frank verification round (Cycle #25 candidate replacements).
- **Cycle cap:** 0 new issues, 0 comments, 1 inbox drop (escalation marker), 0 code changes.
- **Loop-level flag:** #286 primacy gate has now blocked **13 consecutive Saul cycles (#12 through #25)**. **Escalation threshold met this cycle.** The asymmetric-cost pattern from cycles #21/#23/#24 is now structurally entrenched: PR #455 is the SECOND consecutive seam-adjacent commit (after PR #452) that ships engineering work under positioning ambiguity, while the storefront-positioning lanes downstream of #286 remain content-blocked. The data-layer scaffolding under PR #455 specifically *lowers Option A implementation cost* at #440 (an algorithm picker would have persisted ground-truth indicator columns to render against) — meaning the engineering side has now made the Settings-picker path materially cheaper while the positioning side cannot decide whether to ship the picker. This is the inverted-asymmetry the cycle #21 escalation note already surfaced — now reinforced for the third consecutive cycle.
- **Learning:** the cycle-#23 carry-forward heuristic ("for any future engineering commit that touches the seam, distinguish INTERFACE-shape changes from SURFACE-shape changes") generalizes to "INTERFACE / DATA-LAYER / SURFACE" — three orthogonal axes. PR #452 was INTERFACE (closure pathway added to the seam client). PR #455 is DATA-LAYER (persisted indicator columns ride alongside any future algorithm output). SURFACE is still empty (no Settings picker, no per-portfolio override, no in-flow chooser). The Saul-side observability test is gated on the SURFACE axis alone — INTERFACE and DATA-LAYER work is positioning-neutral. Codify forward: future seam-adjacent commits (calculator wiring, schema bumps, request/response shape changes) default NO_OP unless they ship a user-visible chooser/picker/toggle that a screenshot can capture.
- **Saul → self (next cycle):** (1) re-tail `frank-handoff-2026-05-15-saul.md` at cycle-start for Cycle #25 section (Robinhood / Public / Yahoo Finance / Snowball verification round); if Snowball verification confirms current anchor, no tier-doc revision; if Yahoo Finance / Robinhood / Public verify, evaluate adding to `saul-activation-tier-peer-set.md` (4-tier table); (2) all cycle #22/#23/#24 carry-forwards remain (tiers.md disposition wait, #286 primacy is the largest unresolved gate, post-launch baseline still gated on v1.0 ship); (3) if Danny picks Option A at #440, both PR #452's `calculateForHoldings` closure pathway AND PR #455's persisted indicator columns are the wiring the Settings picker would route to — useful prior context for Basher's amendment loop; (4) if Danny picks Option B, file the formal #238 close-deferred comment + #286 Stance B retirement comment as previously queued. (5) Re-check #286 state at next cycle-start; if still blocked, counter goes to 14 and escalation should be re-asserted to coordinator with the cumulative-cost summary.
- **Honest evidence ceiling:** the "#322 row rejection" claim assumes the commit message ("MVP holdings carry the full indicator payload returned by `Components.Schemas.HoldingOut`") accurately characterizes the data direction (backend → local). If a future commit reverses this (local computes indicators on-device WITHOUT a backend `HoldingOut` payload), a new #322 row claim *would* become defensible ("indicators computed and stored locally; never transmitted to any backend"). The current PR #455 does not support that claim. Storefront copy claiming "your indicator math stays on-device" is **not yet supportable** — the backend dependency is documented in the PR description itself.

## Cycle 2026-05-15 #28

- **HEAD:** `63cad39` (prior cycle HEAD `beb72b6`). One commit since prior cycle: `63cad39` — `contract(openapi): add dedicated holdingNotFound ErrorCode for PATCH/DELETE /portfolio/holdings/{ticker} (#469)`, closing `#460`. Commit touched `app/Sources/Backend/Networking/openapi.json`, `backend/api/main.py`, `backend/tests/test_api.py`, `openapi.json`. Note: the cycle window `beb72b6..63cad39` via `git --no-pager log beb72b6..HEAD --name-only` also surfaces commit `467ed858` (`#472`, closes `#462`) — Settings SecureField HIG keyboard wiring, touching `app/Sources/Features/SettingsView.swift`. Total in-window: 2 commits.

- **Locked-surface scan result:**
  - `63cad39` (`#469`): adds `HOLDING_NOT_FOUND = "holdingNotFound"` to OpenAPI `ErrorCode` enum so iOS clients can distinguish `portfolioNotFound` (parent portfolio missing → redirect to onboarding) from `holdingNotFound` (single holding row missing → refresh holdings list). Files: 4 backend/openapi artifacts + tests. **Zero ASO/positioning surface delta.** Pure contract correctness in Nagel lane.
  - `467ed858` (`#472`, closes `#462`): adds `.submitLabel(.done)` + `.onSubmit` on the Settings API-key SecureField, gated by `canSubmitAPIKey` predicate. File: `SettingsView.swift`. **Zero new market surface.** Turk HIG-compliance lane. No algorithm picker, no data-handling surface change, no observability change.
  - **Verdict: ZERO in-lane positioning/market surfaces this cycle.**

- **#286 primacy gate state check:** `gh issue view 286 --json state,updatedAt,title` = `{state:"OPEN", updatedAt:"2026-05-15T18:15:27Z"}`. Unchanged since Cycle #13 fold. **Counter increments 14 → 15 consecutive cycles blocked (cycles #12 through #28 inclusive).** Downstream cost unchanged: `#240 #253 #269 #322 #347 #440` carry "no primacy shift" caveats; Frank still has `#362 #370 #387 #400 #409 #431` caption/subtitle issues gated (`#377` is OPEN — per Frank cycle-27 accuracy correction, not closed via #418; see `#377` state verification below). Formal escalation marker already at `.squad/decisions/inbox/saul-286-primacy-gate-escalation.md` (filed cycle #25); re-asserted to coordinator each cycle since.

- **#377 history-accuracy correction (Frank cycle-27 ask):** `gh issue view 377 --json state,updatedAt` = `{state:"OPEN", updatedAt:"2026-05-15T15:59:28Z"}`. **CONFIRMED OPEN.** The Cycle #25 history entry (#377 CLOSED) and the Cycle #26 frank-handoff-2026-05-15-saul.md roster table entry ("#377 CLOSED via #418") were both incorrect. `#377` (`aso(subtitle): free-first positioning…`) is still live. PR #418 closed #399 (primacy gate on subtitle change) and updated subtitle content — it did NOT close #377. **Correction acknowledged and propagated forward.** Updated downstream gated count: Frank has **6 active gated caption/subtitle issues** (`#362 #370 #377 #387 #400 #409 #431` minus `#377` which is now confirmed still open = 7 still gated, correcting the cycle-26 error). Frank gated count is **7** (not 6 as previously recorded).

- **Pre-existing comment scan:** `gh issue list --label squad:saul --state open --search "updated:>2026-05-15T20:55:00Z" --limit 50` → **no issues match**. Zero out-of-band comments or activity on Saul-labeled issues since cycle #27 close.

- **Frank cycle-27 handoff absorption table:**

| Ask (from `.squad/agents/saul/inbox-frank-cycle-27.md`) | Disposition | Rationale |
|---|---|---|
| 6-cycle peer-set anchor stability (Stock Events + Sharesight byte-identical) | **CONFIRMED — CARRY FORWARD** | No new Apple iTunes Lookup probe this cycle; 6-cycle stability confirmed from cycle-27 data. Tier-doc at `saul-activation-tier-peer-set.md` current. No revision needed. |
| `#444` 4-leg privacy-story watch-trigger | **CARRY-FORWARD** | `gh issue view 444 --json state` = `{state:"OPEN", title:"compliance(data-export-ui)…", updatedAt:"2026-05-15T20:55:12Z"}`. Not landed. 4th evidence leg for `#353` still pending. |
| `#274` 6-data-point Blossom caveat fold | **DEFER — Frank-routed** | `#274` is labeled `squad:frank` (confirmed cycle #25 + cycle #26). Frank owns the body fold. Blossom 6-probe bounded-noise window confirmed (single-cycle delta ≤1, range ≤3 over 6 cycles). Saul passes the confirmation to Frank via cycle-28 handoff; Frank to fold on next `#274` revision. No Saul comment on a squad:frank issue. |
| `#377` history-accuracy correction (#377 OPEN not CLOSED) | **ACKNOWLEDGED — PROPAGATED** | `gh issue view 377` confirms OPEN. Error in cycle-26 roster table corrected. Frank gated count revised to 7 active (includes `#377`). |
| `#467` AC#1 Candidate B (`planner`) primary lock | **DONE — cycle #27** | Delivered in Saul cycle-27 output (`inbox-frank-cycle-27.md`): Candidate B confirmed primary. Rationale: `planner` matches VCA verb-axis; `tracker` is segment-saturated (2/6 peer trackNames already own the word). No further Saul action. |
| `#468` AC#2 E2/E4 advisory framing review | **DONE — cycle #27** | Delivered in Saul cycle-27 output: E2 rewrite recommended (action-neutral copy, 107 chars); E4 name-keep + long-desc rewrite with Option A/B split; E1 and E3 approved. Reuben coordination on E4 also recommended. No further Saul action. |

- **#469 `holdingNotFound` positioning implication audit:**
  - The commit routes `holdingNotFound` (new `ErrorCode`) to the iOS Settings rectification flow (PATCH path = Art. 16 GDPR right-to-rectification) and ticker-typo deletion flow (DELETE path). This improves iOS client dispatch precision within the DSR surface chain.
  - This is error-routing plumbing WITHIN the existing DSR-UI surface (`#464` / leg 3 of `#353` privacy story). It does NOT add a new user-observable data-handling surface.
  - **No Saul evidence axis moves this cycle.** `#353` evidence remains at 3 legs: (a) v3 schema bump (#455) — local computation; (b) UUID redaction (data-retention.md) — bounded server traceability; (c) Settings → Erase All My Data (#464) — verifiable erasure path. `holdingNotFound` refines the erasure path's error semantics but adds no new substantive evidence leg. Confirmed NO_OP for `#353` comment.
  - `#440` observability check: `SettingsView.swift` touches only the API-key SecureField row (per `#472` diff). No algorithm picker introduced. Stance B observability bit unchanged at 0.

- **Duplicate-check protocol (mandatory — executed even under NO_OP):**
  - Search 1: `gh issue list --search "holdingNotFound OR holding not found OR rectification positioning" --state all --limit 30` → found `#460` (CLOSED — the issue closed by `#469`), `#286`, `#322`, `#467`, `#427`, `#220`. Zero net-new Saul positioning issues warranted.
  - Search 2: `gh issue list --search "SecureField OR submitLabel OR keyboard HIG" --state all --limit 30` → found `#462` (CLOSED by `#472`), `#222`, `#234`. Zero Saul positioning overlap.
  - Search 3: `gh issue list --search "measurement caveat OR blossom OR rating noise OR non-monotonic baseline" --state all --limit 30` → found `#277`, `#286`, `#347`, `#253`, `#292`, `#245`, `#324`, `#424` (CLOSED). No new issue candidate. `#274` is the canonical carrier for the Blossom caveat; squad:frank-routed.
  - **Verdict: no new issue candidate. No duplicate risk.**

- **Decision: NO_OP on new issue filing. NO comment filed this cycle.** Both watch-triggers inactive (`#444` OPEN, `#286` OPEN-unchanged). Frank cycle-27 ask for `#274` fold deferred as squad:frank-routed. No in-lane surface delta. No out-of-band signals. Peer-set stability and Blossom caveat confirmation passed via Frank handoff only.

- **Cycle cap:** 0 new issues, 0 comments, 0 code changes. 1 Frank handoff written.

- **#286 primacy gate: 15 consecutive cycles blocked.** Downstream cost structurally entrenched. Loop-level escalation marker at `saul-286-primacy-gate-escalation.md` still the canonical pointer for coordinator surfaces to Danny.

- **Watch-trigger states:**
  - `#444` (data-export Settings UI) → OPEN; `updatedAt=2026-05-15T20:55:12Z`; 4th privacy-story evidence leg trigger NOT fired; carry forward.
  - `#353` (Data Not Collected) → OPEN; 3-leg evidence ceiling; 4th leg awaits `#444`.
  - `#387` (Frame 3 privacy-differentiator caption) → OPEN; `#286`-gated for copy; evidence stack 3-leg.
  - `#347` (observable-signal taxonomy) → OPEN; In-App Events fold (cycle-27 Finding 5) deferred to next `#347`-action cycle.

- **Honest evidence ceiling:** (1) peer-set 6-cycle stability is iTunes Lookup API corpus-pattern, not Apple Search Ads volume-measured. (2) Blossom 6-probe bounded-noise window is a methodology confirmation, not a claim about Investrum's post-launch performance. (3) The `#469` no-new-evidence-leg finding assumes `holdingNotFound` is an internal error-routing change and not a user-visible data surface — confirmed by reading the commit diff scope (openapi.json enum + backend handlers + tests only; no new Privacy Manifest entry, no new Settings row).

- **Saul → self (next cycle):** (1) check if `#444` has landed (4th privacy-story leg trigger); (2) monitor `#286` — if Danny responds, unblock `#362 #370 #377 #387 #400 #409 #431` Frank caption stack; (3) cycle-27 Finding 5 (`#347` In-App Events fold) is the outstanding Saul-side action; action when `#347` is next cycle's target; (4) Frank still owes `#274` Blossom caveat fold and E4 Reuben pre-clear; monitor in next Frank handoff.

## Cycle — 2026-05-15T21:22Z — Saul (cycle #29)

- **HEAD start/end:** `63cad39` → `63cad39`. **Zero new commits since prior cycle (#28).** `git --no-pager log 63cad39..HEAD --oneline` returns empty. Prompt framed this as a 6-commit window from `9fe4cca` → `63cad39`, but those 6 commits (`e0dd44c`/`#454`, `95df9a5`/`#455`, `7378118`/`#464`, `beb72b6`/`#466`, `467ed858`/`#472`, `63cad39`/`#469`) were each absorbed in Saul cycles #25 / #26 / #27 / #28. **Impact on strategy lane:** none new this cycle — pure verification pass + Frank cycle #28 intake. Prompt's cycle-counter framing (cycle #24, counter 12, Frank cycle #24 to absorb) is stale by 4 cycles; this cycle is correctly numbered #29 and operates on Frank cycle #28 intake.

- **#286 primacy gate counter — now 16:**
  - `gh issue view 286 --json state,updatedAt` = `{state:"OPEN", updatedAt:"2026-05-15T21:09:14Z"}`. **Moved since cycle #28's check** (was `18:15:27Z`).
  - Last 3 comments inspected: (1) `2026-05-15T15:22:25Z` yashasg (cycle #12 fold for Frank's Frame 2 caption stack); (2) `2026-05-15T18:15:27Z` yashasg (Saul cycle-#13 Stance B third-narrowing fold); (3) **`2026-05-15T21:09:14Z` yashasg — Frank cycle #28 escalation comment** (`https://github.com/yashasg/value-compass/issues/286#issuecomment-4463667159` per Frank handoff line 55). Body opens `## #286 primacy-gate escalation — cycle 15 consecutive blocked (Frank cycle #28)`.
  - **No Danny activity. No primacy decision.** The 21:09:14Z move is a Frank-authored *meta-escalation* on the gate, not a substantive primacy pick. Gate remains substantively blocked.
  - **Counter increments 15 → 16 consecutive cycles blocked (cycles #12 through #29 inclusive).** Recommendation to Squad coordinator: re-assert formal escalation at `.squad/decisions/inbox/saul-286-primacy-gate-escalation.md` (filed cycle #25 at counter=13) at the next decisions cycle — with cumulative-cost summary now 16 cycles deep. Marker file itself not edited this cycle (per cycle #28 carry-forward: "re-asserted to coordinator each cycle since" — the marker is the canonical pointer; the per-cycle counter lives in history.md).

- **Frank Cycle #24 intake status:** **already absorbed in Saul cycle #25** (history.md L676-680). The prompt's literal ask (4 wrong-domain IDs to drop + 2 null-trackName retentions + Cycle #25 candidate replacements + Blossom bidirectional non-monotonic caveat) was fully dispositioned 4 cycles ago. Re-verified `.squad/decisions/inbox/frank-handoff-2026-05-15-saul.md` Cycle #24 section (L574-654) against cycle #25 dispositions table — all 3 asks marked **bookmark-hygiene / Frank-internal / Frank-routed**, and `#274` caveat re-confirmed `squad:frank`-owned via `gh issue view 274 --json labels`. **No re-litigation warranted; sealed.**

- **Frank Cycle #28 intake (the actually-pending one — `.squad/agents/saul/inbox-frank-cycle-28.md`):**

  | Signal | Disposition | Rationale |
  |---|---|---|
  | E2 long-desc rewrite LOCKED on #468 (Frank issuecomment-4463665734) | **ACKNOWLEDGED** | Saul cycle-#27 Finding 1 (107-char action-neutral rewrite) folded by Frank; AC#2 ready to close pending E4 Reuben gate. No Saul action. |
  | E4 event name KEEP + long-desc PENDING REUBEN | **ACKNOWLEDGED — Reuben coordination owed by Frank** | Saul cycle-#27 Finding 2 (split name-keep + caption rewrite Option A/B) folded by Frank; Reuben pre-clearance request flagged. Reuben lane — no Saul comment. |
  | #467 Candidate B `planner` primary LOCKED (Frank issuecomment-4463665657) | **ACKNOWLEDGED — DONE** | Saul cycle-#27 Finding 4 delivered; AC#1 closed. No further action. |
  | #347 In-App Events fold (3 Apple-rendered IAE signals) | **CARRY-FORWARD** | Cycle-#27 Finding 5 deferred to next `#347`-action cycle. `#347` updatedAt `2026-05-15T18:56:04Z`, unchanged since cycle #27 — not surfaced this cycle. No Saul action this cycle. |
  | **7-cycle peer-set anchor stability** (Stock Events + Sharesight + Robinhood + Public + Yahoo Finance + Snowball all byte-identical cycles #22→#28) | **CONFIRMED — CARRY FORWARD** | No new iTunes Lookup probe this cycle (saves API call; 7-cycle floor is sufficient). Frank's table at handoff L26-34 cited; Stock Events `4.80546/2087/v9.35.4` rounds to `4.81/2,087` matching tier-doc anchor `.squad/decisions/inbox/saul-activation-tier-peer-set.md:12` byte-identical. **Tier-doc anchor current for 7th time.** No revision needed. |
  | **Blossom 7-point window** — −2 net delta over 7 cycles; range = 4; ±3 noise-floor confirmed | **CONFIRMED — Frank-routed for #274 body fold** | `#274` is `squad:frank` (confirmed cycles #25 / #26 / #28). Frank-owned absorption. No Saul comment on a squad:frank issue. |
  | **#286 at 15 cycles → Frank escalation comment posted** (Frank handoff L51-57) | **CONFIRMED via gh issue probe** | Frank's `issuecomment-4463667159` is the 21:09:14Z move; counter now 16. See `#286` section above. |
  | **#444 watch-trigger NOT landed** (`updatedAt=2026-05-15T20:55:12Z`, OPEN) | **CARRY-FORWARD** | 4th privacy-story leg for `#353` still pending. Re-verified via `gh issue view 444 --json state,updatedAt` this cycle. |
  | **#449 watch-trigger NOT landed** (`updatedAt=2026-05-15T20:43:49Z`, OPEN) | **CARRY-FORWARD** | DSR-rectification UI still pending. Re-verified this cycle. |

- **Positioning re-check post-`#356` closure (re-evaluation per prompt explicit ask):**
  - **`#238` (positioning(seam): user-pluggable VCA as distinct axis):** **UNCHANGED at user-observable-surface bit (still 0).** PR #455 (`95df9a5`, closed `#356`) was already analyzed in Saul cycle #25 (history.md L665-693). Re-verified this cycle: `app/Sources/Features/SettingsView.swift` `Picker` rows at L35 (Theme) + L42 (Language) only; `app/Sources/App/Dependencies/ContributionCalculatorClient.swift:76` `defaultCalculator` still hard-codes `MovingAverageContributionCalculator()`; `grep -rn "ContributionCalculating" app/Sources/` returns same 3 conformers (`MovingAverageContributionCalculator:434`, `BandAdjustedContributionCalculator:521`, `ProportionalSplitContributionCalculator:618`). **#238's evidence: marginally REINFORCED on the cost-side** (PR #455's persisted indicator columns lower Option-A implementation cost) but **UNCHANGED on the user-observable-surface-side**. Net: still no comment-fold warranted — Saul's INTERFACE / DATA-LAYER / SURFACE three-axis test from cycle #25 (history L691) gates fold on SURFACE movement only, and SURFACE remains 0.
  - **`#322` (positioning(trust-commitment): enumerated auditable indie publisher commitments):** **SHIPPED-COMMITMENT ROW COUNT STILL 4** (disclaimer + Art. 15 export + Art. 16 rectification + Art. 17 full-account erasure). Re-verified `gh issue view 322`: 9 comments total, last at `2026-05-15T20:43:58Z` (cycle #26 fold for `#329`/`#464` iOS Settings → Erase All My Data UI — refines existing Art. 17 row, does NOT add a new row). Cycle #25's framing held — PR #455 indicator-field persistence "rejected per NO_OP discipline" (history L673) because indicators flow FROM the backend's `HoldingOut` response (opposite of an "on-device-never-transmitted" claim); cycle #28 confirmed `holdingNotFound` (`#469`) refines erasure path's error semantics without adding a new substantive evidence leg. **Row count holds at 4 across cycles #22/#23/#25/#28/#29.**
  - **`#440` (opportunity(seam-observability): zero in-binary observable surface):** **SHIP-VS-RETIRE BINARY UNCHANGED.** Confirmed via the same SettingsView grep above + `gh issue view 440` (`updatedAt=2026-05-15T18:14:44Z`, OPEN, no movement since cycle #16's filing). PR #455's persisted indicator columns are exactly the DATA-LAYER axis movement cycle #25 already absorbed — cost-side lowering of Option A without surface-side movement. **No fold this cycle.**

- **Roster verify (18 open — prompt said 16, prompt was stale):** `gh issue list --label squad:saul --state open --limit 50` returns 18: `#458 #456 #440 #393 #354 #347 #322 #313 #301 #296 #286 #277 #269 #263 #253 #241 #240 #238`. Same set as cycle #28. Activity-window probe `updated:>2026-05-15T20:55:00Z` returns only `#286` (the 21:09:14Z Frank escalation move documented above). **Roster delta: 18 → 18, unchanged.** The discrepancy with prompt's "Prior count was 16" reflects the prompt being authored against a cycle-#24-era snapshot; #458 and #456 were filed in cycle #25's pre-Saul-spawn window (history L683) and have been in the 18-roster for 4 cycles now.

- **Tier-doc currency:** `.squad/decisions/inbox/saul-activation-tier-peer-set.md:12` cites Stock Events `4.81 / 2,087`. Frank cycle-#28 probe (handoff L28) returns `4.80546 / 2087 / v9.35.4` — rounds byte-identical. **Anchor stable across 7 consecutive cycles (#22→#28).** No revision needed. `docs/research/` directory exists but contains no tier doc (cycle #5's filing landed in `.squad/decisions/inbox/` not `docs/research/` — pre-existing path choice; not a currency issue). Promotion to `docs/research/competitive-tiers.md` remains a cycle-#5 carry-forward gated on Danny's `#296` Stance A/B/C pick (still owed; not a `#286`-class gate).

- **Net-new positioning intel:** **None.** Searched my own thinking: privacy posture, methodology framing, persona ICPs, peer-set, retention loop, IAE signals, holdings-seam observability — all axes already filed (16 substantive Saul issues + 2 launch-funnel companions). No genuinely new validated opportunity emerges from the zero-commit window. **Filing-discipline check passes: NO_OP is correct.**

- **Duplicate-check proof:**
  - **Search terms exercised this cycle:**
    - `gh issue list --label squad:saul --state open --limit 50` → 18 open, matches roster.
    - `gh issue list --label squad:saul --state open --search "updated:>2026-05-15T20:55:00Z"` → `[#286]` only (the 21:09:14Z Frank meta-escalation comment move, NOT a substantive issue update warranting a Saul fold).
    - `gh issue view 286 --json comments` last-3 inspected — comment-author chain confirms no Danny activity.
    - `gh issue view 322 --json comments | length` = 9 (vs. cycle #28's 9); body re-read at `bodyLen=13030`; row count still 4.
    - `gh issue view 440 / 238 / 444 / 449 / 347 --json state,updatedAt` — all match cycle-#28 snapshot byte-identical except `#286`.
    - **gh invocations total (this cycle):** 9 (issue view 286 + 322 + 440 + 238 + 444 + 449 + 347 + issue list + activity-window probe).
  - **Existing reviewed (issue numbers cross-checked):** `#238 #240 #241 #253 #263 #269 #274 #277 #286 #296 #301 #313 #322 #347 #354 #393 #440 #444 #449 #456 #458`. **No new positioning evidence cell to add anywhere.** Frank's two confirmed Frank-routed asks (`#274` Blossom caveat fold; `#286` 16-cycle escalation re-assertion) are by-label outside Saul's filing-or-comment scope this cycle.

- **Cross-issue coherence audit (per Cycle #4 rule):** Zero new positioning surfaces. The cycle-#28 audit holds verbatim: `#440 #322 #354 #347` all UNCHANGED against the 6-commit window already absorbed across cycles #25-#28; `#286` is the standing escalation; remaining 12 open Saul issues (`#240 #241 #253 #263 #269 #277 #296 #301 #313 #393 #456 #458`) topically non-overlapping with any cycle-#29-window movement (which is empty).

- **Re-validation hooks:** none triggered. Saul owns no file-path-trigger docs per `loop-strategy.md`.

- **Decision:** **NO_OP.** No new issue, no comment, no inbox drop, no code change. The cycle is a pure verification-and-absorption pass: HEAD has not moved since cycle #28; Frank cycle #28's asks are all carry-forward / Frank-routed / Reuben-coordination-owed-by-Frank; Frank cycle #24's asks (per prompt's literal framing) were dispositioned 4 cycles ago. **#286 counter increment 15 → 16 is this cycle's only positioning-lane state change**, and is recorded by re-assertion not new filing.

- **Cycle cap:** 0 new issues, 0 comments, 0 inbox drops, 0 code changes.

- **Loop-level flag:** `#286` primacy gate has now blocked **16 consecutive Saul cycles (#12 through #29)**. **Past the 13+ escalation threshold by 3 cycles.** Frank's own 21:09:14Z escalation comment (`issuecomment-4463667159`) is the surface-level signal that the inter-specialist cost is reaching the threshold where the squad coordinator should escalate to the user directly. Cycle-#28's structural framing holds: engineering keeps shipping seam-adjacent and data-layer code (PRs #452/#455 cumulatively lower Option-A implementation cost to its all-time low) while positioning-lane stays content-blocked across 16 cycles. The escalation marker (`saul-286-primacy-gate-escalation.md`) remains the canonical pointer; cycle-counter live in this history file.

- **Learning:** prompt-vs-state drift handling. This cycle's prompt was authored against a Saul-cycle-#24-era snapshot but actual state has progressed 4 cycles. The right discipline is to (a) honor the prompt's structural asks (axis re-checks, counter increment logic, roster verify, duplicate-check proof) on the *current* state, (b) explicitly cite the state drift in the cycle entry so future cycles can audit what was reconciled, (c) NOT re-litigate already-absorbed signals (Frank cycle #24's 3 signals were sealed cycle #25), (d) NOT use the drift as license to file marginal findings (NO_OP discipline still applies). Today's cycle ran 9 gh-CLI invocations + 0 mutation operations; the verification-only shape is correct when prompt drift is the dominant variable.

- **Saul → self (next cycle):** (1) re-check `#286` updatedAt at cycle-start; if still no Danny activity, counter 16 → 17 (likely past coordinator-level intervention threshold by then); (2) `#444` 4th-leg watch-trigger and `#449` rectification-UI watch-trigger both still pending — fold on next cycle if either lands; (3) `#347` In-App Events fold (cycle #27 Finding 5) still the outstanding Saul-side action — execute when `#347` is next cycle's target; (4) tier-doc anchor stable for 7 cycles — no revision needed unless Frank's cycle #29+ peer-set probe shows drift; (5) re-tail `frank-handoff-2026-05-15-saul.md` AND check `.squad/agents/saul/inbox-frank-cycle-29.md` at next cycle-start (cycle-#24 heuristic — straddle-window intake catch).

- **Honest evidence ceiling:** (1) the "counter 15 → 16" increment treats Frank's own 21:09:14Z meta-escalation comment as NOT a substantive primacy-gate unblock — defensible because no primacy stance was picked, but a stricter reading would treat any `#286` movement as "gate touched, counter resets to 0." I am applying the looser "blocked until Danny picks primacy" reading consistent with cycles #21-#28. If the coordinator prefers the strict reading, counter resets to 0 and re-counts from cycle #30. (2) The "Frank cycle #24 sealed in cycle #25" claim assumes the cycle-#25 dispositions table is the authoritative absorption record; verified via direct re-read of `frank-handoff-2026-05-15-saul.md` L574-654 + cycle-#25 history L676-680 — no missed cells. (3) The 7-cycle peer-set stability claim trusts Frank's cycle-#28 probe at handoff L26-34 without re-running iTunes Lookup this cycle; the Stock Events tier-doc-anchor cross-check at `4.81/2,087` is the load-bearing fact and is byte-identical to my tier-doc citation, so re-probing was deemed redundant.


## Cycle #29 — HEAD `215fdef`

> **Cycle-numbering note.** The entry immediately above this one (line ~749, header `## Cycle — 2026-05-15T21:22Z — Saul (cycle #29)`) was a **pre-#476 absorption pass** authored at HEAD `63cad39` (zero-commit window). PR #474 (`651d3d0`) and PR #476 (`215fdef`) landed after that pass closed. This entry is the canonical cycle #29 absorption of the 2-commit window `63cad39..215fdef`. Counter chain is continuous: cycle #28 left counter at 15; the pre-#476 pass took it to 16 (Frank's 21:09:14Z meta-escalation comment was not a Danny primacy pick); this pass takes it to **17**.

### Window + positioning-surface absorption

- **HEAD start/end:** `63cad39` → `215fdef`. `git --no-pager log 63cad39..HEAD --oneline` returns 2 commits:
  - `651d3d0` — `a11y(announcement): post AT announcements on Settings Erase All My Data status transitions (closes #473) (#474)`. Touched `app/Sources/App/AppFeature/SettingsAccessibility.swift` (new), `app/Sources/Features/SettingsView.swift`, `app/Tests/VCATests/SettingsAccessibilityTests.swift`, `app/VCA.xcodeproj/project.pbxproj`. **Yen-lane** (a11y). Refines the iOS Settings → Erase All My Data UX (the `#329`/`#464`-shipped Art. 17 GDPR erasure flow) so VoiceOver hears the `.idle → .erasing → .erased/.failed` transitions. **Positioning impact: zero new surface, zero new commitment row.** This is UX completeness on an already-shipped `#322` indie-publisher commitment row (Art. 17 full-account erasure). Row count holds at 4.
  - `215fdef` — `aso(keyword-field): lock v1.0 en-US 91-byte allocation, DCA gateway-query pairing (closes #467) (#476)`. Single doc-only file: `docs/aso/keyword-field.md` (+231/−0). **Frank-lane**, primary attribution. Positioning-adjacent at the discovery-funnel layer (see "Findings" below).

- **Locked-surface scan:** PR #474 touches NO Frank-owned surface (`app/Sources/Assets/`, `app/run.sh`, `docs/aso/`, `app/Info.plist`). PR #476 lands **inside** `docs/aso/` (new `keyword-field.md`) — Frank's primary attribution, but the DCA→VCA pairing routes into the positioning lane and warrants in-lane analysis (see "Findings").

- **Positioning-surface delta:** none in code/assets; **one new ASO artifact** at `docs/aso/keyword-field.md` that cites Saul evidence (#240 persona vocabulary, #393 DCA→VCA bridge, #245 segment-empty scan) as the rationale for Candidate B's pairing. Evidence flow is **#240/#393/#245 → #476 (downstream execution)**, NOT #476 → new Saul evidence.

### Findings (positioning implications of #476 keyword-field lock)

1. **DCA→VCA gateway pairing is downstream-execution of existing #240 + #393 evidence** — not a new evidence axis.
   - `docs/aso/keyword-field.md:86-92` ("Long-tail gateway capture") cites `#393`'s `DCA-curious → VCA-adoption funnel` framing verbatim as the rationale for pairing `dollar cost averaging` with `value cost averaging` in one allocation.
   - `keyword-field.md:93-96` ("Persona-vocabulary tokens") cites `#240`'s Bogleheads/FIRE persona evidence as the rationale for retaining `dividend`, `etf`, `long term`.
   - **Conclusion:** the keyword-field lock is the *implementation* of #240/#393 evidence at the ASO discovery layer. The doc cross-references both issues; their bodies already contain the load-bearing claims. **No fold warranted on either body.**

2. **`#393` anti-spreadsheet brief: marginal reinforcement, no fold.**
   - #393's body (§"five-point answer") frames the DCA→VCA bridge as the storefront-copy axis that converts spreadsheet-literate Bogleheads. PR #476 ships the *first* indexable surface (keyword field) that captures the gateway query. This validates #393's framing operationally but does not add a new evidence cell; the storefront-copy frontier #393 names (subtitle / promo-text / description) is still primacy-gated on #286.
   - **NO_OP comment.** Saul cycle cap holds. Marginal reinforcement is recorded here, not in #393.

3. **`#240` Bogleheads persona: validated, no fold.**
   - Frank's choice to spend 22 bytes on `dollar cost averaging` (the highest-volume gateway query for #240's communities) is a fully-derived consequence of #240's persona claim. The doc cites the persona evidence verbatim. No new evidence cell.
   - **NO_OP comment.**

4. **`#253` user-control axis: not impacted.**
   - The DCA gateway is a discovery/funnel artifact. #253's evidence is competitor App Store review pain (data hostage, lost control, hidden fees, forced account) — unrelated to keyword discovery. No fold.

5. **`#322` indie-publisher commitments row count: unchanged at 4.**
   - PR #474's a11y announcement refines the Art. 17 erasure-row UX (verifiability via AT) but does not introduce a 5th enumerated commitment. Disclaimer + Art. 15 export + Art. 16 rectification + Art. 17 full-account erasure = 4. Row count holds across cycles #22/#23/#25/#28/#29-pre-#476/#29.
   - The keyword-field doc explicitly notes (`keyword-field.md:223-225`): "Coheres with: #322 (trust-commitment block — keyword field is indexer-only, no claim conflict)." Confirmed via direct re-read.

6. **`#286` primacy-gate structural lean (NOT a primacy pick — observational only).**
   - The prompt asked Saul to weight the keyword-field doc's voice-continuity argument. `keyword-field.md:73-80` states Candidate B's `portfolio planner` was picked because it "carries the actor-noun voice (`Calc` → `Calculator` → `Planner`) established by the subtitle's trailing `VCA Calc` qualifier and re-used across the user-control voice register in #322 / #312 / #327 / #362 / #370 / #387."
   - The user-control voice register named there (#322, #312, #327) is the **Stance A (#240 methodology-led)** voice scaffold — `#322` is the enumerated-commitments indie-publisher frame; `#312`/`#327` carry the scope-honesty + actor-noun framing. The pluggable-algorithm Stance B (`#238`) voice register is *not* cited in the voice-continuity chain.
   - The doc itself hedges (`keyword-field.md:228-229`): "Decoupled from: #286 (primacy axis — every candidate is multi-axis-tolerant at the keyword layer)." This hedge is defensible at the *keyword-byte* layer (any candidate is allocator-valid) but is *not* defensible at the *voice-register* layer: the actual rationale for Candidate B over Candidate C ("tracker" reads as segment-vernacular per `keyword-field.md:79-80`) is a Stance-A voice argument, not a multi-axis-tolerant one.
   - **Evidence weight on #286, not a primacy pick.** The locked keyword-field artifact is the **5th storefront atom** to lean structurally toward Stance A without an explicit primacy decision. (Prior 4: subtitle `VCA Calc` lock at `docs/aso/subtitle-positioning.md` via PR #418; #322 enumerated-commitments row count; #327 scope-honesty block; the user-control voice register #312/#322/#327/#362/#370/#387 cited in the keyword-field doc.) Stance B (#238 pluggable-algorithm) has shipped **zero** storefront atoms with primacy claim.
   - **Decision:** record this in cycle entry; **NO comment on #286** (Frank just commented at 21:09:14Z — another comment now is noise). The escalation marker at `.squad/decisions/inbox/saul-286-primacy-gate-escalation.md` remains the canonical pointer. If counter reaches 20+ without movement, consider a Saul-authored *re-assertion* comment that itemizes the 5-atom structural lean as a concrete recommendation surface for Danny.

7. **No new positioning axis surfaces from #476.** The DCA gateway is a discovery-funnel artifact (Frank-routed); per the prompt's prediction, no new Saul primacy claim emerges. Confirmed.

### #286 primacy-gate counter (now 17 consecutive blocked)

- `gh issue view 286 --json state,updatedAt` = `{state:"OPEN", updatedAt:"2026-05-15T21:09:14Z"}` — unchanged since the pre-#476 pass.
- **No Danny activity.** Last #286 comment chain: `15:22:25Z` (cycle #12 yashasg), `18:15:27Z` (cycle #13 yashasg), `21:09:14Z` (Frank cycle #28 escalation per pre-#476 pass). All yashasg-authored; no Danny voice.
- **Counter increments 16 → 17 consecutive cycles blocked (cycles #12 through #29-canonical inclusive).** Three cycles past the 13+ formal-escalation threshold, four past the 13-cycle marker file (`saul-286-primacy-gate-escalation.md`, filed cycle #25).
- **Escalation judgment:** the prompt asks whether to escalate further. **My read: do not file another #286 comment this cycle.** Frank's 21:09:14Z comment is freshly visible; piling on a Saul comment within hours of Frank's would dilute signal-to-noise. The Finding-6 structural-lean evidence (5 storefront atoms now leaning Stance A without an explicit pick) is a *concrete* recommendation surface — but it is more valuable as a single coherent escalation comment authored when (a) counter ≥ 20, or (b) a 6th storefront atom lands. I am banking it; recording the evidence cell here in history.md is sufficient for cycle #29.
- **Marker file:** `saul-286-primacy-gate-escalation.md` unedited this cycle (cycle-counter lives in history.md per cycle-#28 carry-forward; marker is the canonical pointer to coordinator surfaces).

### Watch-triggers (#444, #449, #347, #274)

| Trigger | State | updatedAt | Disposition |
|---|---|---|---|
| #444 (data-export Settings UI) | OPEN | `2026-05-15T20:55:12Z` | **Not landed.** 4th leg of #353 privacy-story evidence stack still pending. Re-verified this cycle byte-identical to cycle #28 and pre-#476 probes. |
| #449 (data-rectification UI) | OPEN | `2026-05-15T20:43:49Z` | **Not landed.** Right-to-correct flow trigger still pending. Re-verified byte-identical to cycle #28. |
| #347 (observable-signal taxonomy) | OPEN | `2026-05-15T18:56:04Z` | Unchanged since cycle #27. In-App Events 3-signal fold (impression / tap-through / detail page-view) still queued for next `#347`-action cycle. PR #476 does not surface new observable signals (keyword-field rank tracking is post-launch + Apple-side opaque per `keyword-field.md:201-204` "honest evidence ceiling" §2). |
| #274 (Blossom + competitor-rating baseline caveat) | OPEN | `2026-05-15T11:16:51Z` | **Frank-routed** (`squad:frank` label re-verified). 7-point Blossom window confirmation (per Frank handoff L37-49) ready for Frank body-fold. No Saul comment on squad:frank issue. |

**No watch-trigger fired this cycle.** Carry-forward stands.

### Duplicate-check proof

- **Search terms exercised:**
  - `gh issue list --search "DCA OR dollar cost averaging OR gateway-query OR keyword-field" --state all --limit 20` → returned `#245, #467 (CLOSED via #476), #377, #220, #286, #269, #253, #370, #240, #351, #241, #313, #342` — all pre-existing Saul/Frank issues. **#467 confirmed CLOSED at `2026-05-15T21:29:17Z` (the PR #476 merge moment).** No net-new candidate.
  - `gh issue list --search "a11y announcement erasure VoiceOver settings" --state all --limit 10` → returned only `#386` (disabled-button-hint a11y, unrelated to the announcement surface). No positioning-lane overlap. PR #474 itself closes the dedicated `#473` issue (Yen-routed); no Saul filing axis.
  - `gh issue list --label squad:saul --state open --limit 50` → 18 issues (matches cycle #28 + pre-#476 pass byte-identical). No state change on any Saul-labeled issue since the pre-#476 pass.
- **Reviewed:** `#238 #240 #241 #245 #253 #263 #269 #274 #277 #286 #296 #301 #313 #322 #347 #354 #386 #393 #440 #444 #449 #456 #458 #467`. **No new positioning evidence cell warranting a filing or comment.** The DCA→VCA bridge is fully embodied in #240 + #393 + the now-shipped `docs/aso/keyword-field.md`.
- **gh invocations this cycle:** 9 (issue view 240/253/286/322/393/444/449/347/274 + 2 issue lists + 1 PR view 476 + 1 PR view 474).
- **Verdict:** **No new issue. No comment.**

### Issues created / commented

**None.** Cycle cap: 0 new issues, 0 comments, 0 code changes, 1 Frank handoff written. Filing-discipline check passes: the DCA→VCA pairing is downstream-execution of #240/#393, not net-new evidence into them; the #286 voice-register lean is banked for a later coherent escalation; PR #474 is UX completeness on a shipped #322 row, not a new commitment.

### Routing proof

N/A — no issues filed. Existing Saul roster unchanged at 18; all routing labels (`team:frontend`, `team:strategy`) verified intact in the roster probe above.

### Roster delta

18 → 18, unchanged. Same set as cycle #28 + pre-#476 pass: `#238 #240 #241 #253 #263 #269 #277 #286 #296 #301 #313 #322 #347 #354 #393 #440 #456 #458`. Activity probe `updated:>2026-05-15T21:09:00Z` on `squad:saul`-labeled issues returns empty (the 21:09:14Z #286 move was the pre-#476-pass-side timestamp; nothing has touched the Saul roster in the canonical-#29 window other than `#467` closure — which is `squad:frank`-labeled, not `squad:saul`).

### Frank → Saul handoff intake (cycle #28 dispositions)

| Frank cycle-#28 signal | Disposition this canonical cycle |
|---|---|
| E2 long-desc LOCKED on #468 (`issuecomment-4463665734`) | **ACKNOWLEDGED** (carry from pre-#476 pass; no new Saul action). |
| E4 PENDING REUBEN (Option A/B) | **ACKNOWLEDGED — Reuben-coordination owed by Frank.** No Saul action. |
| #467 AC#1 Candidate B `planner` LOCKED (`issuecomment-4463665657`) | **DOC-SHIPPED.** PR #476 landed `docs/aso/keyword-field.md` and closed #467 at `2026-05-15T21:29:17Z`. Saul cycle-#27 Finding 4 (Candidate B primary) is now persistent in repo as the SoT artifact for the locked keyword string. **Acknowledged the doc-ship in this cycle** (the pre-#476 pass acknowledged only the comment-lock). |
| #347 In-App Events 3-signal fold | **CARRY-FORWARD.** `#347` unchanged. |
| 7-cycle peer-set anchor stability (Stock Events + Sharesight + Robinhood + Public + Yahoo + Snowball byte-identical) | **CONFIRMED — CARRY FORWARD.** No new iTunes Lookup probe; floor of 7 cycles is the strongest stability signal in the loop's history. |
| Blossom 7-point window (−2 net delta, range 4, ±3 noise floor) | **CONFIRMED — Frank-routed for #274 fold.** No Saul action. |
| #286 at 15 cycles → Frank escalation comment | **CONFIRMED via gh probe.** Counter now 17 (this canonical-#29 pass). |
| #444 / #449 watch-triggers NOT landed | **CONFIRMED — carry-forward both.** |

### Saul → Frank handoff written to `.squad/agents/frank/inbox-saul-cycle-29.md`

File written this cycle. Contents summarize: HEAD anchor `215fdef`; PR #476 acknowledgement (Candidate B `planner` SoT now in `docs/aso/keyword-field.md`, supersedes prior comment-lock); #286 counter at 17 with 5-atom Stance-A structural lean observation (banked, not yet escalated); watch-trigger states `#444`/`#449`/`#347`/`#274` unchanged; Saul cycle-#27 Findings 1-4 all doc-shipped or comment-locked; the `keyword-field.md:223-225` `#322`-coherence note flagged for Frank's awareness (no claim conflict, but description-body draft #327 should use `dollar cost averaging` per `keyword-field.md:144-151` AC, which is a Frank-side action item).

### Top 3 next actions

1. **(Self) Re-probe `#286.updatedAt` at next cycle-start.** If no Danny activity, counter 17 → 18. At counter ≥ 20 or upon a 6th storefront-atom landing toward Stance A, file a Saul-authored re-assertion comment on #286 enumerating the structural-lean evidence cells (5+ atoms) as a concrete recommendation surface. The marker file `saul-286-primacy-gate-escalation.md` remains the canonical pointer; the per-cycle counter lives in this history file.
2. **(Self) Monitor `#444` (data-export Settings UI) and `#449` (rectification UI) for landing.** Either landing fires the 4th leg of #353's privacy-story evidence stack and re-opens the privacy-led axis (alternate primacy direction on #286). If `#444` lands first, the trigger is asymmetric: it strengthens privacy-led framing *without* touching the methodology-led voice register that #476 just reinforced — would warrant a #353 4th-leg comment and a fresh #286 evidence comment that balances both axes.
3. **(Saul → self carry-forward) Execute `#347` In-App Events 3-signal fold** (cycle-#27 Finding 5; cycle-#28 + canonical-#29 carry-forward) when `#347` is the next cycle's target. PR #476 does not surface new IAE signals; queue holds.

### Risky changes

None this cycle (NO_OP). One latent risk worth flagging: the keyword-field doc's `keyword-field.md:228-229` "Decoupled from: #286 (primacy axis — every candidate is multi-axis-tolerant at the keyword layer)" framing is a defensible Frank-side hedge at the *byte* layer but understates the structural lean at the *voice-register* layer that the same doc admits (`keyword-field.md:73-80`). If the squad-coordinator routing treats `#286` as ASO-decoupled because of that line, the Stance-A structural lean becomes invisible at the decisions surface. **Mitigation:** the Finding 6 cell in this history.md entry is the audit trail; the Saul → Frank handoff also flags it (without asking Frank to re-frame his own doc — that would be cross-lane). If counter reaches 20+, file the #286 re-assertion comment.

### Learning

- **Downstream-execution vs. new-evidence discrimination.** PR #476 cites #240/#393/#245 as load-bearing rationale — the temptation is to read citation-into-shipped-artifact as "new evidence" warranting a fold-back comment. The correct read: the citation flow is **upstream → downstream**, not bidirectional. The shipped artifact is *consequence* of the evidence, not new evidence into it. Filing-discipline rule: a citation in a downstream artifact does NOT regenerate a comment-fold obligation on the source issue unless the artifact introduces a *new* evidence cell the source body didn't already contain. PR #476 introduces none; #240/#393 bodies already contained the DCA→VCA bridge framing.
- **Voice-register lean recording without filing.** The 5-atom Stance-A structural lean is real and worth banking, but recording it in history.md (audit-trail-grade) is the right surface for this cycle — a #286 comment within hours of Frank's existing escalation comment dilutes both. The escalation lever is **counter ≥ 20 OR 6th atom landing OR Danny-prompts-for-recommendation**, not "+1 cycle since prior comment." This discipline is the equivalent of Frank's 7-cycle iTunes Lookup floor: stability of signal beats density of comment.
- **Numbering-continuity discipline.** This cycle's prompt was authored unaware that a prior "cycle #29" pass had already executed at HEAD `63cad39`. Rather than re-name or rewrite history, the right move is (a) preserve the prior entry verbatim, (b) add a cycle-numbering note at the top of this entry that makes the continuity explicit, (c) chain the counter through both passes (15 → 16 → 17). Audit trail beats neatness.

---


## Cycle #30 — HEAD `b332de7`

> **Counter chain.** Cycle #28 left counter at 15; pre-#476 sub-pass took it to 16; canonical cycle #29 took it to 17; this cycle takes it to **18** (no Danny activity in cycle-#29 → cycle-#30 window).

### Window absorption (3 commits since cycle #29 close)

- `git --no-pager log 215fdef..HEAD --oneline` returns 3 commits:
  - `34cf426` PR #477 — `aso(preview-video-device-matrix): codify 886×1920 6.9" iPhone master ... (closes #422)`. Frank-lane primary; new file `docs/aso/app-preview-spec.md` (+367 lines, 0 deletions). **Saul: no positioning fold** per commit body line `Saul: no positioning fold (canvas, not painting)` and the doc's own `app-preview-spec.md:275-279` Saul-section. Canvas-vs-painting pattern transferred from #412; storyboard / caption strings / scene order in #251 hold verbatim. No new positioning evidence cell.
  - `4950eb7` PR #478 — `contract(openapi): publish ErrorEnvelope on /schema/version + /portfolio/status 422 (closes #302)`. Nagel/contract-lane; touches `backend/api/main.py`, `openapi.json`, `app/Sources/Backend/Networking/openapi.json`, `backend/tests/test_api.py`. **Zero positioning surface.**
  - `b332de7` PR #475 — `hig(quitting): route Settings → Erase All My Data back to onboarding in-process (closes #471)`. Turk/HIG-lane primary; touches `AppFeature.swift` (+27), `SettingsFeature.swift` (+33), `SettingsFeature+APIKey.swift` (+10), `SettingsView.swift` (+15/−15), test files. **Refines `#322` row 4 (Art. 17 erasure) UX**; replaces the prior force-quit-and-relaunch instruction with `AppFeature.destination = .onboarding(...)` programmatic swap on a new `SettingsFeature.Action.delegate(.dataErased)` channel. **Row count holds at 4.**

- **Locked-surface scan** (`docs/aso/`, `app/Sources/Assets/`, `app/run.sh`, `app/Info.plist`, `app/Sources/App/Info.plist`):
  - PR #477 lands `docs/aso/app-preview-spec.md` — Frank's own attribution per commit body's "Decision owner: Frank (App Store Optimizer)" + the explicit "Saul: no positioning fold" cell. **In-lane Saul read** validates the canvas claim against the doc's `Cross-references` cell (`#412 (sibling substrate audit — screenshot side)`), `Rejected alternatives` table, and explicit Saul-section. **No Frank-doc-side challenge warranted.**
  - PR #475 and PR #478 touch zero Frank-owned surface.

- **GitHub-state-vs-local-worktree lag.** Local HEAD `b332de7`; GitHub HEAD = `f45e140` (one PR ahead, PR #483 + #484-file). `gh issue list --label squad:saul --state open` reflects GitHub truth (17 open: #458 closed `2026-05-15T22:01:27Z`); `git log` reflects local-worktree truth. Same lagging pattern Frank cycle #29 F6 flagged for PR #477.

### Findings

1. **PR #475 refines `#322` row 4 — does NOT add a row 5.** Re-verified via direct re-read of `#322` body (`gh issue view 322 --json body` → `bodyLen=13030`, no row-enumeration marker present in body, claim structure carried in comment-stream evidence chain — see prior cycle-#26 comment `2026-05-15T20:43:58Z` for the 4-row tripod summary). Cycle-#22→#29 row-count framing (disclaimer / Art. 15 export / Art. 16 rectification / Art. 17 erasure) **holds at 4**. The in-process reroute is an evidence-*quality* upgrade on the Art. 17 row: SettingsView's new copy ("returns to the welcome screen automatically, exactly like a fresh install" — `SettingsView.swift:357`; "Returning to the welcome screen…" — `SettingsView.swift:382`) is materially stronger trust-frame than the prior force-quit ceremony, but does not enumerate a new GDPR Article. **No #322 comment fired** — cycle-#22→#29 NO_OP-on-quality-refinement discipline holds.

2. **`docs/legal/privacy-policy.md:258` staleness.** The legal-doc copy still reads `"the next launch returns Investrum to the disclaimer screen, exactly like a fresh install."` The "next launch" mental model is now factually stale (the in-process reroute bypasses the next-launch requirement). The b332de7 commit body itself self-discloses this as Reuben-lane: `"Out of scope: docs/legal/privacy-policy.md §6 still says ... legal lane (Reuben) owns the mirror change in a separate filing per the issue body."` **Not a Saul filing axis** (squad:reuben territory) **but a storefront-copy-hygiene flag** I am surfacing in the cycle-30 Frank handoff so Frank doesn't paraphrase the stale wording into description-body / In-App Event long-desc / screenshot caption copy. SettingsView.swift is the in-binary truth surface until Reuben ships the mirror fix.

3. **PR #477 `docs/aso/app-preview-spec.md` Saul-no-fold validated.** Doc's `app-preview-spec.md:275-279` Saul-section is byte-explicit: `"**no Saul fold required** — same canvas / painting distinction as #412. Storyboard scene order, caption strings, and PPO variant axes hold verbatim. The autoplay-above-screenshots conversion narrative is unchanged."` Cross-checked against doc's `Decision summary` (6 items: master resolution, auto-scale chain, iPad scope, audio track, poster frame, frame-rate/bitrate/codec) — all are format-spec corrections; none touch caption strings or scene order. **Canvas-not-painting holds.** No fold warranted on `#240` / `#393` / `#322` / `#322` / `#253`.

4. **`app-preview-spec.md:341-345` iPad-deferred Saul-rebuttal axis — banked, not filed.** Doc explicitly invites: *"Saul may rebut if persona work in #240 surfaces iPad buyers as a primary persona (Bogleheads / FIRE may skew iPad-heavy). No data to date suggests that, but it has not been ruled out."* My cycle #5/#12 #240 persona work was forum-corpus + behavior driven; device-share data for the segment was not in my filing scope. **No rebuttal at this time.** This is a new open evidence cell — charted for retrospective re-evaluation if post-launch `#284` / `#347` analytics surface iPad-share data >30% for Bogleheads/FIRE. **Not a #240 comment now** (no evidence to add); flagged in Frank handoff for the post-launch analytics feedback loop.

5. **#458 closure validated (Saul-lane roster delta 18 → 17).** Per `gh issue view 458 --json closedAt,stateReason` → `closedAt=2026-05-15T22:01:27Z, stateReason=COMPLETED`. Closing artifact: `docs/aso/dm-seeding-script.md` shipped via PR #483 / `5750e3b` (not yet reachable from local HEAD `b332de7`); companion Reuben compliance issue `#484` filed (`squad:reuben`, p1, mvp, `compliance(reddit-tos): review DM-seeding script against Reddit User Agreement + Apple 5.6.3`). Per #458's pre-close yashasg comment (`2026-05-15T22:00:48Z`): *"no DM ships until #484 closes and a signed row lands in the §"Reuben compliance gate" table."* **Clean closure**; the §"Reuben compliance gate" structural block correctly handed off to Reuben as the holdback lever before any DM goes out. **No Saul follow-up** — the artifact landed AND the compliance gate is properly chained.

6. **#274 caveat fold ACK'd shipped.** Frank's `issuecomment-4463952081` at `2026-05-15T21:49:27Z` lands the `|Δ| ≤ 3` bounded-noise band caveat executing my cycle-#28 F3 ask. 8-data-point Blossom evidence — strongest baseline in the loop's history. Re-verified `#274` labels via `gh issue view 274 --json labels` → `[documentation, priority:p2, team:frontend, team:strategy, squad:frank]` — confirmed Frank-routed; no Saul comment on a `squad:frank` issue. **Coordination loop closed**; not a recurring ask in the handoff stream.

7. **No competitor App Store probe this cycle** — deferred per Frank cycle-#29 F2 ("9-cycle byte-identity confirmed; cadence recommendation firms to every-3rd-cycle"). Tier-doc anchor `saul-activation-tier-peer-set.md:12` (Stock Events `4.81 / 2,087`) remains current at 9 cycles of byte-identical confirmation. Next full Lookup probe targets cycle #32 absent a release-notes-drift trigger from Frank's lane.

### #286 primacy gate — counter now 18

- `gh issue view 286 --json state,updatedAt` = `{state:"OPEN", updatedAt:"2026-05-15T21:09:14Z"}` — **unchanged** from cycle #29 close.
- **No Danny activity** in the cycle-#29 → cycle-#30 window. Last comment chain unchanged: `15:22:25Z` (cycle #12 fold) → `18:15:27Z` (cycle #13 fold) → `21:09:14Z` (Frank cycle #28 escalation comment). All yashasg-authored; no Danny voice.
- **Counter increments 17 → 18** consecutive cycles blocked (cycles #12 through #30 inclusive). Five cycles past the formal-escalation threshold (13+). Two cycles short of my self-imposed re-assertion-comment threshold (≥ 20).
- **5-atom Stance-A structural-lean stands**: (1) subtitle `VCA Calc` lock per PR #418; (2) `#322` enumerated-commitments row count; (3) `#327` scope-honesty block; (4) user-control voice register at `#312/#322/#327/#362/#370/#387`; (5) keyword-field `portfolio planner` voice continuity per PR #476 / `keyword-field.md:73-80`. **No 6th atom landed this cycle** — PR #475 is a row-4 refinement (existing atom), PR #477 is canvas-not-painting (zero positioning surface), PR #478 is contract-lane (zero positioning surface). Stance B (#238 pluggable-algorithm) has shipped **zero** storefront atoms with primacy claim.
- **Decision: hold the re-assertion comment.** Frank's 21:09:14Z escalation is freshly visible; piling on within hours dilutes signal. Trigger conditions unchanged: counter ≥ 20 OR 6th-atom landing toward Stance A OR explicit Danny prompt. **None fire this cycle.**
- Marker file `saul-286-primacy-gate-escalation.md` unedited (cycle-counter lives in this history.md per the cycle-#28 carry-forward; marker is the canonical coordinator-pointer).

### Watch-triggers

| Trigger | Issue | State | updatedAt | Disposition |
|---|---|---|---|---|
| 4th privacy-story leg | `#444` (data-export Settings UI) | OPEN | `2026-05-15T20:55:12Z` | **Not landed.** Carry-forward; re-check next cycle. |
| Rectification UI | `#449` | OPEN | `2026-05-15T20:43:49Z` | **Not landed.** Carry-forward. |
| Observable-signal taxonomy | `#347` | OPEN | `2026-05-15T18:56:04Z` | Unchanged since cycle #27; 3-IAE-signal fold still queued. |
| #468 E4 Reuben pre-clear (via Frank handoff F4) | `#468` AC#2 | OPEN, pending Reuben | (Frank-lane) | If Reuben silent across cycles #30/#31/#32, escalate via `#287` per Frank cycle-#29 F4 plan. |

**No watch-trigger fired this cycle.**

### Duplicate-check proof

- **Search terms exercised:**
  - `gh issue list --label squad:saul --state open --limit 50` → 17 open (was 18 cycle #29; delta: −1 from #458 closure). Set: `#456 #440 #393 #354 #347 #322 #313 #301 #296 #286 #277 #269 #263 #253 #241 #240 #238`.
  - `gh issue list --label squad:saul --state closed --limit 5` → most-recent closure `#458` at `2026-05-15T22:01:27Z` (validated above).
  - `gh issue view 286 / 322 / 440 / 238 / 444 / 449 / 347 / 274 / 393 / 354 / 296` — all probed for `state,updatedAt`; no Saul-roster state change apart from #458 closure since cycle #29.
  - Activity-window probe via per-issue `updatedAt` comparison vs cycle-#29 records: only `#274` advanced (`11:16:51Z` → `21:49:27Z` = Frank's caveat fold per handoff F7; `squad:frank` routing means no Saul comment).
- **gh invocations this cycle:** 14 (issue view × 11 + issue list open + issue list closed + 1 view on `#458`+`#484` for closure validation).
- **Reviewed:** `#238 #240 #241 #253 #263 #269 #274 #277 #286 #296 #301 #313 #322 #347 #354 #393 #440 #444 #449 #456 #458 #484`. **No new positioning evidence cell warranting a filing or comment.** F2's #322 row-4 refinement, F3's privacy-policy staleness, F4's iPad-share open evidence cell all flagged in Frank handoff but each fails the "new evidence cell" filing threshold (F2 = quality not row count; F3 = Reuben-lane; F4 = no data to add yet).

### Issues created / commented

**None.** Cycle cap: 0 new issues, 0 issue comments, 0 inbox-decision-markers, 0 code changes, 1 Frank handoff written (`.squad/agents/frank/inbox-saul-cycle-30.md`).

### Routing proof

N/A — no issues filed.

### Roster delta

**18 → 17** (−1: `#458` closed via PR #483 + companion `#484` filed). Remaining 17 open: `#456 #440 #393 #354 #347 #322 #313 #301 #296 #286 #277 #269 #263 #253 #241 #240 #238`. **Topically non-overlapping** with any cycle-#30-window movement (PR #477 canvas, PR #475 row-4 refinement, PR #478 contract).

### Frank → Saul handoff intake (cycle #29 dispositions)

| Frank cycle-#29 signal | Disposition this cycle |
|---|---|
| F1 — #467 AC#1 close validated (Candidate B `portfolio planner` locked PRIMARY) | **ACK** — cycle-#27 Finding 4 SoT-shipped. No further Saul action. |
| F2 — Peer-set 9-cycle byte-identity; cadence firms to every-3rd | **ACK + DEFERRED** to cycle #32 absent release-notes-drift trigger. |
| F3 — #274 Blossom caveat FOLDED (`issuecomment-4463952081`) | **ACK — coordination loop closed.** Cycle-#28 F3 ask retired. |
| F4 — #468 E4 Reuben silence carry-forward | **CARRY-FORWARD.** Re-probe cycles #31/#32; if 3-cycle silence persists, escalate via `#287`. |
| F5 — #286 counter 17, 5-atom Stance-A lean banked | **ACK** — incremented to **18** this cycle (no Danny activity). |
| F6 — Roster lag note (PR #477 not yet local) | **ACK + EXTENDED** — same lag pattern now applies to PR #483 (`#458` close + `#484` file). |
| F7 — Locked-surface scan PASS for `651d3d0` | **ACK** — extended to PR #477 (`docs/aso/app-preview-spec.md` is Frank-attributed canvas-side; in-lane Saul read confirmed no positioning surface). |
| F8 — `#444` watch-trigger not landed | **ACK + CARRY-FORWARD.** State byte-identical to cycle #29. |

### Saul → Frank handoff written

`.squad/agents/frank/inbox-saul-cycle-30.md` — 9 findings table (F1-F9), `#286` cycle-#30 update, watch-trigger states carry-forward, 2 coordination requests (storefront-copy-hygiene re: erasure-row paraphrasing; iPad-share evidence cell open), explicit NO_OP cycle decision.

### Top 3 next actions

1. **(Self) Re-probe `#286.updatedAt` at next cycle-start.** If no Danny activity, counter 18 → 19. At counter ≥ 20 OR 6th storefront-atom landing toward Stance A, file the banked re-assertion comment enumerating the 5-atom structural lean as a concrete recommendation surface. Marker file `saul-286-primacy-gate-escalation.md` remains the canonical pointer.
2. **(Self) Watch for #444 / #449 landing** — either fires the 4th leg of `#353`'s privacy-story evidence stack and triggers a `#353` 4th-leg comment + a `#286` evidence comment balancing the privacy-led axis against the methodology-led structural lean.
3. **(Self) Execute `#347` In-App Events 3-signal fold** (cycle-#27 Finding 5; cycle-#28 → #30 carry-forward) when `#347` is next cycle's target. PR #475 / #477 / #478 surface no new observable signals.

### Risky changes

None this cycle (NO_OP). One latent risk worth flagging: if Frank paraphrases the Art. 17 erasure-row mechanic in any storefront copy *before* Reuben ships the privacy-policy.md §6 mirror-fix, he could inadvertently pull from the stale legal-doc rather than the new SettingsView truth. **Mitigation:** explicit F3 cell in `inbox-saul-cycle-30.md` flagging the staleness and pointing Frank to `SettingsView.swift:357,382` as the in-binary truth surface. If Frank ships description-body copy citing the stale "next launch" phrasing, fold on next cycle.

### Learning

- **Refinement-not-addition discrimination on multi-row commitment stacks.** PR #475's in-process reroute looked at first read like a candidate 5th row for `#322` (sufficient delta-of-shipped-behavior to justify a row?). Re-read of the b332de7 commit body + the SettingsView diff confirmed it is *strictly* a row-4 UX refinement: same GDPR Article (17), same data scope (full account), same trigger (Settings → Erase All My Data), better post-erasure mechanic (in-process welcome-screen reroute vs force-quit ceremony). Cycle-#22→#29 row-count discipline rule firms: row-additions require a *new* enumerated commitment surface (e.g., GDPR Art. 21 right-to-object would qualify), not an evidence-quality upgrade on an existing one.
- **Canvas-not-painting transferability.** The PR #477 `app-preview-spec.md` doc explicitly invoked the #412 canvas-vs-painting pattern (Frame substrate audit on the screenshot side). Saul-side disposition rule: when a Frank-lane artifact self-declares canvas-vs-painting *and* the doc's content is verifiable as format-spec corrections (resolution / codec / poster-frame / etc.) with no caption-string or scene-order edits, the no-fold disposition holds without a deep cross-check. This is the second instance (PR #412 was the first); pattern-recognition cost decreasing.
- **Charted open evidence cells.** The `app-preview-spec.md:341-345` iPad-share rebuttal invitation is the right kind of finding to bank as a charted open evidence cell rather than file as a new issue: no data to support a rebuttal *and* a clear future trigger (post-launch analytics surfaces device-share for the segment). Filing an issue without evidence would clutter the roster; ignoring the invitation would lose the audit trail. The history.md cell + the Frank-handoff F4 cell serve as the dual surface.
- **Honest evidence ceiling:** (1) the counter increment 17 → 18 still applies the looser "blocked until Danny picks primacy" reading; stricter reading (any #286 movement resets counter) would have reset at the 21:09:14Z Frank escalation comment and re-counted from cycle #30 (counter = 1). I am consistent with cycles #21-#29's looser reading. (2) The `#458` closure validation trusts GitHub state (PR #483 visible via `git log --all`) without local-worktree fetch; the closure timestamp matches Saul's prior cycle-#25-era #458 filing rationale and the cycle-#30 yashasg pre-close comment cleanly references both #483 (the script artifact PR) and #484 (the Reuben gate). (3) The 9-cycle peer-set anchor stability trusts Frank cycle-#29 F2 without re-probe; tier-doc citation `4.81 / 2,087` remains the load-bearing fact and is byte-identical across 9 Frank probes.

## Cycle #31 — HEAD `e5404e4`

> **Counter chain.** Cycle #29 left counter at 17; cycle #30 took it to 18; this cycle takes it to **19** (no Danny activity in cycle-#30 → cycle-#31 window). Auto-re-assertion fires at counter ≥ 20 (1 cycle remaining).

### Window absorption (5 commits since cycle #30 close)

- `git --no-pager log b332de7..HEAD --oneline` returns 5 commits:
  - `e5404e4` PR #490 — hig(layout) ContributionResultView iPad cap (closes #426). Turk-lane primary; touches `app/Sources/Features/ContributionResultView.swift` (+3/−2). **Zero positioning surface.**
  - `a059ef4` PR #488 — hig(alerts) confirmationDialog swap for destructive delete (closes #389). Turk-lane primary; touches `app/Sources/Features/ContributionHistoryView.swift` (+21/−5). **Zero positioning surface.**
  - `7e46ff5` PR #482 — hig(quitting) iPhone toolbar Settings reroute to wire dataErased delegate (closes #471, refines #322 row 4). Turk-lane primary; touches `AppFeature.swift` (+16/−3), `MainFeature.swift` (+24/−4), `PortfolioListFeature.swift` (+15 new tests), `PortfolioListView.swift` (+4/−2), `SettingsView.swift` (+16/−0), test files (+60). **Refines `#322` row 4 (Art. 17 erasure) UX**; pure routing architecture fix (AppFeature + MainFeature path interception so the in-process-reroute feature from PR #475 actually fires on iPhone compact mode). **Row count holds at 4.**
  - `32b3b01` PR #481 — contract(openapi) DecimalString bounds re-emit (closes #461). Nagel-lane contract; touches `backend/api/main.py` (+89), `openapi.json`, tests. **Zero positioning surface.**
  - `f45e140` PR #483 — **aso(launch-recruitment)**: scripts the #448 DM-seeding funnel + Reuben compliance gate (closes #458). Frank-lane aso-channel; new file `docs/aso/dm-seeding-script.md` (+540, 0 deletions). **Operationalizes existing positioning atoms via four pain-pattern DM templates; zero new 6th atom.**

- **Locked-surface scan** (`docs/aso/`, `app/Sources/Assets/`, `app/run.sh`, `app/Info.plist`, `app/Sources/App/Info.plist`):
  - PR #483 lands `docs/aso/dm-seeding-script.md` — Frank-channel artifact operationalizing the #448 funnel / #253 pain-themes / #277 fresh-2026-05 review. **In-lane Saul read** validates the templates against existing atoms: T1-T4 all reinforce "no account," "on-device," "free," "manual entry," "no brokerage link," or "no server" — all cycle-#22→#30 banked atoms. Does the script introduce a new "value-cost-averaging-first" vs "user-control-first" framing? Each template opens with user-control framing (data portability, manual entry, no server dependency); T4 is cost framing (free). **Stance-A user-control voice holds; no new Stance-B atom.** No Frank-doc-side challenge warranted.
  - PR #490, #488, #482, #481 touch zero Frank-owned surface.

### Findings

1. **PR #483 dm-seeding-script.md — zero new positioning atom.** The 540-line script defines a four-pain-template DM outreach funnel (P1-P4 → T1-T4) for the #448 channel pivot. Each template operationalizes existing atoms. T1 (data hostage) opens with "I'm the indie developer… keeps every holding… on-device and exports it as plain JSON" (user-control, data portability — both cycle-#22 atoms). T2 (lost control) opens with "manual-entry portfolio tracker that doesn't link to a brokerage and doesn't depend on any server" (manual entry + no brokerage + no server — all cycle-#22 atoms). T3 reinforces no-account, no-tracking. T4 is "free, no IAP." **No new enumerated claim; operationalization only.** The script artifact is the source-of-truth for the persona-fit DM funnel and is a companion to #456's volume-funnel launch-copy under the same #448 channel pivot. **No #286 counter impact.**

2. **PR #482 refines `#322` row 4 — does NOT add row 5.** The iPhone toolbar Settings flow in PortfolioListView was routing through a detached SettingsFeature store, so the `.delegate(.dataErased)` action never reached AppFeature (which intercepts and reroutes to onboarding). PR #482 adds `Action.settingsOpenTapped` to PortfolioListFeature, wiring the Button through MainFeature.path instead of a direct NavigationLink, so the reroute now fires on iPhone (it was broken; iPad sidebar already worked via PR #475). **This is pure routing architecture, not a new row.** The enumerated commitment surface `#322` — disclaimer + Art. 15 export + Art. 16 rectification + Art. 17 erasure — remains 4. Row count holds across cycles #22-#31.

3. **#286 primacy gate — counter increments 18 → 19.** `gh issue view 286 --json state,updatedAt` = `{state:"OPEN", updatedAt:"2026-05-15T21:09:14Z"}` — **unchanged** from cycle #30 close. No Danny activity in the cycle-#30 → cycle-#31 window. Last comment chain unchanged: all yashasg-authored; no Danny voice. **Counter increments 17 (cycle #29) → 18 (cycle #30) → 19 (cycle #31) consecutive cycles blocked (cycles #12 through #31 inclusive).** One cycle short of the auto-re-assertion threshold (≥ 20).

4. **5-atom Stance-A structural lean stands unchanged**: (1) subtitle `VCA Calc` lock per PR #418; (2) `#322` enumerated-commitments row count (4 rows; PR #482 is row-4 routing refinement, not new row); (3) `#327` scope-honesty block; (4) user-control voice register at `#312/#322/#327/#362/#370/#387`; (5) keyword-field `portfolio planner` voice continuity per PR #476 / `keyword-field.md:73-80`. **No 6th atom landed this cycle** — PR #490/488/482/481 are zero-positioning engineering; PR #483 operationalizes atoms #2/#4/#5 via dm-seeding-script.md templates (no new atom). Stance-B (#238 pluggable-algorithm) has shipped **zero** storefront atoms with primacy claim across cycles #22-#31.

5. **Decision: hold the re-assertion comment.** Frank's 21:09:14Z escalation from cycle #28 stands as the escalation marker. Trigger conditions: counter ≥ 20 OR 6th-atom landing toward Stance A OR explicit Danny prompt. **One condition now at threshold**: counter 19 → 20 at cycle-start if Danny remains silent. **If counter reaches 20 next cycle, file the banked re-assertion** enumerating the 5-atom structural lean as a concrete recommendation surface.

6. **#344 / #468 watch-trigger updatedAt delta flagged.** #468 updatedAt shifted from cycle-#30 record to `2026-05-15T21:48:27Z`. State is still OPEN (no closure) but activity signature changed. Frank cycle-#30 recorded `—` (Frank-lane); Saul cycle-#31 observed timestamp movement. Clarification needed: is this Reuben activity on E4, or Danny movement? Will probe in cycle-#32.

### #286 primacy gate — counter now 19

- **No Danny activity** in cycle-#30 → cycle-#31 window.
- **Counter increments 18 → 19** consecutive cycles blocked (cycles #12 through #31 inclusive).
- **5-atom Stance-A structural-lean stands**: atoms 1-5 unchanged; no 6th atom landed; Stance-B at zero storefront atoms.
- **Decision: hold the re-assertion comment.** Counter is 1 cycle short of auto-threshold (≥ 20). If no Danny activity at cycle-#32-start, counter 19 → 20 and auto-re-assertion fires.
- Marker file `saul-286-primacy-gate-escalation.md` unedited.

### Watch-triggers

| Trigger | Issue | State | updatedAt | Disposition |
|---|---|---|---|---|
| 4th privacy-story leg | `#444` (data-export Settings UI) | OPEN | `2026-05-15T20:55:12Z` | **Not landed.** Byte-identical to cycle #30. Carry-forward. |
| Rectification UI | `#449` | OPEN | `2026-05-15T20:43:49Z` | **Not landed.** Byte-identical to cycle #30. Carry-forward. |
| Observable-signal taxonomy | `#347` | OPEN | `2026-05-15T18:56:04Z` | Unchanged since cycle #27; 3-IAE-signal fold still queued. |
| #468 E4 Reuben pre-clear (watch-trigger delta) | `#468` | OPEN | `2026-05-15T21:48:27Z` | **Changed from cycle #30.** updatedAt shifted; state OPEN. Probe clarification needed: Reuben E4 comment, or Danny movement? |

**No watch-trigger fired this cycle.**

### Duplicate-check proof

- **Search terms exercised:**
  - `gh issue list --label squad:saul --state open --limit 50` → 17 open (unchanged from cycle #30; #458 closed previous cycle). Set: `#456 #440 #393 #354 #347 #322 #313 #301 #296 #286 #277 #269 #263 #253 #241 #240 #238`.
  - `gh issue view 286 / 322 / 440 / 238 / 444 / 449 / 347 / 393 / 354 / 296 / 468` — all probed for `state,updatedAt`; no Saul-roster state change since cycle #30.
  - Activity-window probe via per-issue `updatedAt` comparison vs cycle-#30 records: only `#468` advanced (`—` → `21:48:27Z`; clarification needed on the movement source).
- **gh invocations this cycle:** 12 (issue view × 11 + issue list open).
- **Reviewed:** `#238 #240 #241 #253 #263 #269 #277 #286 #296 #301 #313 #322 #347 #354 #393 #440 #444 #449 #456 #468`. **No new positioning evidence cell warranting a filing or comment.** F1's locked-surface scan, F2's operationalization-not-atom-addition, F3's row-4 refinement all flagged in Frank handoff but each fails the "new evidence cell" filing threshold (F1 = zero ASO impact; F2 = operationalization not new atom; F3 = architecture fix not new row).

### Issues created / commented

**None.** Cycle cap: 0 new issues, 0 issue comments, 0 inbox-decision-markers, 0 code changes, 1 Saul handoff written (`.squad/agents/frank/inbox-saul-cycle-31.md`).

### Routing proof

N/A — no issues filed.

### Roster delta

**17 → 17** (stable). No closure; no new filing. Remaining 17 open: `#456 #440 #393 #354 #347 #322 #313 #301 #296 #286 #277 #269 #263 #253 #241 #240 #238`.

### Frank → Saul handoff intake (cycle #30 dispositions)

All cycle #30 Frank signals carried forward or resolved:
- F1 (row-4 refinement): **ACK + EXTENDED** — PR #482 is same pattern (row-4 routing refinement). Row count holds.
- F2 (peer-set 9-cycle byte-identity): **ACK + DEFERRED** — re-probe cycle #32.
- F3 (privacy-policy staleness): **ACK + FLAGGED** — if Frank ships erasure-row storefront copy before Reuben's mirror-fix, could inadvertently paraphrase stale legal-doc.
- F4 (iPad-share open cell): **ACK** — charted for post-launch analytics.
- F5 (#458 closure + Reuben gate): **ACK + PERSISTED** — artifact now in local HEAD.
- F6 (roster lag): **ACK + RESOLVED** — local HEAD includes PR #483.
- F7 (locked-surface scan PR #477): **ACK + EXTENDED** — cycle #31 scan passes for all 5 commits (cycle #31 F1).
- F8 (#444 not landed): **ACK + CARRY-FORWARD** — byte-identical.

### Saul → Frank handoff written

`.squad/agents/frank/inbox-saul-cycle-31.md` — 5 findings (F1-F5), `#286` cycle-#31 update (counter 18 → 19), watch-trigger states, 1 coordination request (#468 updatedAt delta clarification), explicit NO_OP cycle decision.

### Top 3 next actions

1. **(Self) Re-probe `#286.updatedAt` at cycle-#32-start.** If no Danny activity, counter 19 → 20. **At counter = 20, file the banked re-assertion comment** enumerating the 5-atom structural lean as a concrete recommendation surface.
2. **(Frank) Clarify #468 watch-trigger updatedAt delta.** Cycle #30 recorded `—` (Frank-lane); cycle #31 shows `2026-05-15T21:48:27Z`. Is this Reuben E4 activity or Danny movement? State OPEN so no closure, but activity signature changed.
3. **(Self) Probe #444 / #449 landing at cycle-#32-start** — either fires the 4th leg of `#353`'s privacy-story evidence stack. If either closes, trigger `#353` 4th-leg comment + `#286` evidence comment balancing privacy-led axis.

### Risky changes

None this cycle (NO_OP). Latent risk from cycle #30: if Frank paraphrases Art. 17 erasure-row mechanic in storefront copy before Reuben's privacy-policy.md §6 mirror-fix, could pull from stale legal-doc. **Mitigation:** cycle #30 F3 cell flagged staleness + pointed to `SettingsView.swift:357,382` as in-binary truth.

### Learning

- **Operationalization-not-addition discrimination on market-channel funnels.** PR #483 dm-seeding-script.md is an extensive new doc with persona-fit template set; looks like a candidate 6th positioning atom on first read. Re-read of the commit body + template examples confirmed it is strictly an operationalization of existing atoms (#322/#353/#387): each template reinforces "no account," "on-device," "free," or "manual entry" — all cycle-#22 atoms. Channel-opening (Reddit 1:1 DM) is not positioning-new-claim; operationalization discipline holds.
- **Routing architecture refinement cadence.** PR #482 followed PR #475 by one cycle. Both architectural (AppFeature + MainFeature + PortfolioListFeature); both touch `#322` row 4. Distinction: PR #475 was feature-ship (in-process reroute), PR #482 was bug-fix (iPhone routing hook so feature fires on compact). Correct follow-up cadence when feature ships incomplete; cycle-#30 → #31 pair is model for "feature ship + routing fix" in TCA architecture.
- **Honest evidence ceiling:** (1) counter 18 → 19 applies looser "blocked until Danny picks" reading (per cycles #21-#31 consistency). (2) `#468` updatedAt shift from `—` to `21:48:27Z` suggests mid-cycle activity; source clarification needed for cycle #32. (3) Peer-set cadence deferred to cycle #32 per Frank cycle #30 F2; tier-doc anchor `4.81 / 2,087` is the reference.

## Cycle #32 — 2026-05-15T22:40Z

> **Counter chain.** Cycle #31 left counter at 19; cycle #32 closes at **20** (no Danny activity in cycle-#31 → cycle-#32 window). Auto-re-assertion trigger fires (≥ 20). Banked comment posted.

### Window absorption (1 commit since cycle #31 close)

- `git --no-pager log e5404e4..HEAD --oneline` returns 1 commit:
  - `4f61989` PR #491 — **aso(launch-copy)**: draft launch-day post copy (HN Show HN, r/SideProject, IndieHackers). Frank-lane ASO channel; new file `docs/aso/launch-post-copy.md` (+315 lines); amendment `docs/testflight-readiness.md` (+1 line launch-day-minus-1 parity gate). **Closes #456 (volume-funnel launch-copy) when Frank + Reuben sign-off gates on lines 298/285 are satisfied.** **Operationalizes all 5 cycle-#22 positioning atoms; zero new 6th atom.**

- **Locked-surface scan** (`docs/aso/`, `app/Sources/Assets/`, launch dates):
  - PR #491 lands `docs/aso/launch-post-copy.md` — Frank-channel artifact operationalizing the HN/r/SideProject/IH volume-funnel channel. **In-lane Saul read validates all 5-atom Stance A structural lean**: (1) #322 user-control voice lead across all three surfaces (lines 71-79, 102-114, 136-143); (2) #377 free-first subtitle (lines 62, 96, 137, 223); (3) #296 activation-tier manual-entry (lines 73-75, 104-106, 140-141); (4) #286 primacy axis user-control lead (Stance A headline framing, line 62 primary variant); (5) #353 claim-vs-code parity (BYOK Massive disclosed lines 71/102/137; free-at-v1.0 / no-analytics / no-account all maintained; testflight parity gate added). **No new enumerated claim; operationalization only.** No Frank-doc-side challenge warranted.

### Findings

1. **PR #491 launch-post-copy.md — zero new positioning atom.** The 315-line post draft defines three public-funnel surfaces (HN/r/SideProject/IH) for the #448 channel pivot. Each surface operationalizes atoms 1-5 per cycle-#22 lock-ins. HN title variants (A/B/C, line 62) all lead with user-control (`No sign-up / No account / No tracking`). HN body (lines 68-80) discloses Massive BYOK sentence-1 and maintains no-tracking + no-analytics + free + manual-entry framing. r/SideProject (lines 92-115) mirrors all atoms via title + "what it does not do" block (lines 106). IndieHackers (lines 125-150) centers no-analytics-SDK as editorial hook (paragraph 2) while preserving all five atoms. **No new Stance-B algorithm-first framing; no new claim beyond atoms 1-5.** Operationalization only. No #286 counter impact.

2. **Hard-fail checklist: all clear.** (line 245-251 in artifact): no upvote/review/referral language ✓; no TestFlight public link ✓; launch-day-minus-1 claim-vs-code parity gate added to `docs/testflight-readiness.md:46` ✓; no broker-sync/Android/tax-tool/live-quote/bundled-data claims ✓; HN title leads with user-control + Massive disclosed sentence-1 ✓.

3. **Coherence audit: 5-atom Stance A structural lean confirmed.** Table at lines 221-235 cross-validates each atom against locked references (#322/#377/#296/#353 + subtitle lock #418 + description-body #327). No drift detected. All five atoms present in all three surfaces. No contradictions across surfaces.

4. **#286 primacy gate — counter increments 19 → 20.** `gh issue view 286 --json state,updatedAt` = `{state:"OPEN", updatedAt:"2026-05-15T21:09:14Z"}` — **unchanged** from cycle #31 close at ~22:13Z UTC. No Danny activity in the cycle-#31 → cycle-#32 window. **Counter increments 17 (cycle #29) → 18 (cycle #30) → 19 (cycle #31) → 20 (cycle #32) consecutive cycles blocked (cycles #12 through #32 inclusive).** Auto-re-assertion threshold (≥ 20) reached.

5. **5-atom Stance-A structural lean stands unchanged + re-assertion fires.** Atoms 1-5 locked per cycles #22-#32 operationalization. No 6th atom landed this cycle (PR #491 is pure operationalization). Stance-B at zero storefront atoms (consistent across all 20 cycles). **Decision: fire banked re-assertion comment on #286 enumerating the 5-atom lean and surface as concrete recommendation.** Banked text discipline from cycle #20-#25 history applied. Comment posted 2026-05-15T22:40Z (GitHub API timestamp; comment ID 4464285922).

6. **#456 closure validation: PASS.** All gates documented; both Frank (line 298 coherence pre-clear) and Reuben (line 285 compliance pre-clear) gates explicitly named in artifact. #456 will CLOSE once both sign-off. No blocker from Saul lane.

### #286 primacy gate — counter now 20, re-assertion fires

- **No Danny activity** in cycle-#31 → cycle-#32 window.
- **Counter increments 19 → 20** consecutive cycles blocked (cycles #12 through #32 inclusive).
- **5-atom Stance-A structural-lean stands**: atoms 1-5 unchanged; no 6th atom landed; Stance-B at zero storefront atoms.
- **Decision: FIRE banked re-assertion comment.** Counter reached ≥ 20 auto-threshold. Comment enumerates 5-atom structural lean + watch-trigger summary + honest evidence surface. Addresses Danny directly with primacy-axis question. Time-stamped 2026-05-15T22:40Z.
- Marker file placement: banked comment now **UPDATED_EXISTING** on #286.

### Watch-triggers

| Trigger | Issue | State | updatedAt | Disposition |
|---|---|---|---|---|
| 4th privacy-story leg | `#444` (data-export Settings UI) | OPEN | `2026-05-15T20:55:12Z` | **Not landed.** Byte-identical to cycle #31. Carry-forward. |
| Rectification UI | `#449` | OPEN | `2026-05-15T20:43:49Z` | **Not landed.** Byte-identical to cycle #31. Carry-forward. |
| E4 Reuben pre-clear update | `#468` | OPEN | `2026-05-15T21:48:27Z` | Unchanged from cycle #31 flag. Source of timestamp shift still unclear. Carry-forward for cycle #33 clarification. |
| #456 gate closure | `#456` | OPEN (not auto-closed) | PR #491 merged 2026-05-15T22:30:13Z | **Artifact landed; gates pending.** Frank + Reuben sign-off gates (lines 298/285) documented. Will close upon both gates satisfy. |

**One watch-trigger updated:** #456 artifact landed (no closure yet, gates pending).

### Duplicate-check proof

- **Search terms exercised:**
  - `gh issue list --label squad:saul --state open --limit 50` → 17 open (unchanged from cycle #31). Set: `#456 #440 #393 #354 #347 #322 #313 #301 #296 #286 #277 #269 #263 #253 #241 #240 #238`.
  - `gh issue view 456 / 286 / 322 / 444 / 449 / 468` — all probed for `state,updatedAt`; no Saul-roster state change except #456 (artifact landed, state still OPEN).
  - #456 closure check: state OPEN (expected; gates pending). PR #491 merged; issue not auto-closed by merge.
  - New positioning evidence cell warrant for filing: None. #456 artifact closed for Saul validation; gates are Frank + Reuben responsibility.
- **gh invocations this cycle:** 8 (issue view × 6 + issue list + issue comment).
- **Reviewed:** `#286 #322 #353 #377 #456 #440 #393 #354 #347 #313 #301 #296 #277`. **#456 closure validation PASS; no new filing warranted.**

### Issues created / commented

**1 comment posted.** Cycle cap: 0 new issues, 1 issue comment (#286 re-assertion), 0 new marker files, 0 code changes, 1 Saul handoff written (`.squad/agents/frank/inbox-saul-cycle-32.md`).

### Routing proof

**Comment posted:** #286 re-assertion (4464285922). Enumerates 5-atom structural lean + watch-triggers + honest-evidence ceiling. Addresses Danny primacy-decision question directly.

### Roster delta

**17 → 17** (stable). No closure; no new filing. #456 artifact validated; gates pending. Remaining 17 open: `#456 #440 #393 #354 #347 #322 #313 #301 #296 #286 #277 #269 #263 #253 #241 #240 #238`.

### Frank → Saul handoff intake (cycle #31 dispositions)

All cycle #31 Frank signals carried forward or resolved:
- F1 (#458 closure validation PASS): **ACK + RESOLVED** — artifact now locked in cycle #31 close.
- F2 (#456 status open): **ACK + PERSISTED** — artifact lands cycle #32 (PR #491); gates documented in artifact.
- F3 (#484 Reuben companion): **ACK + ACKNOWLEDGED** — Reuben owns; Frank read-only.
- F4 (#444 unchanged): **ACK + CARRY-FORWARD** — byte-identical; watch-trigger status quo.
- F5 (#449 unchanged): **ACK + CARRY-FORWARD** — byte-identical; paired with #444.
- F6 (#468 AC#2/AC#3 pending): **ACK + CARRY-FORWARD** — gates pending Saul + Reuben pre-clears.
- F7 (#286 counter 18→19): **ACK + INCREMENTED** — counter 19 → 20; re-assertion fires.
- F8 (storefront-copy-hygiene SettingsView baseline): **ACK + HOLD** — canonical truth preserved; stale legal-doc risk holds.

### Saul → Frank handoff written

`.squad/agents/frank/inbox-saul-cycle-32.md` — 8 findings (F1-F8), #456 closure validation PASS, #286 cycle-#32 update (counter 19 → 20 + re-assertion fires), watch-trigger states, 3 coordination requests (#456 gate sign-off timing / #468 updatedAt delta / peer-set probe deferral), explicit **UPDATED_EXISTING** #286 cycle decision.

### Top 3 next actions

1. **(Self) #286 re-assertion now live.** Comment 4464285922 enumerates 5-atom structural lean as concrete recommendation surface. If Danny responds in cycle-#32 window, move to decision-made state. If silent through cycle-#33 end, counter continues tracking blocked cycles (currently 20/20+).

2. **(Frank) #456 coherence pre-clear gate.** Artifact `docs/aso/launch-post-copy.md` is ready for Frank review (coherence audit lines 219-235). If audit satisfies your ASO positioning baseline, sign off on line 298. This unblocks half the gate; Reuben handles line 285. No Frank sign-off = no closure.

3. **(Self) #468 updatedAt delta tracking.** Cycle #31 recorded source of timestamp shift as "unclear"; cycle #32 carries forward. If Reuben surfaces E4 activity in their cycle output, document source for cycle #33. Same watch-trigger category as #444/#449 carry-forward.

### Risky changes

None this cycle (1-commit window). #456 artifact ships with explicit gates documented (Frank coherence + Reuben compliance). No sign-off yet. Re-assertion comment does not require code change (GitHub API comment only).

### Learning

- **5-atom Stance-A operationalization lock confirmed across 10 cycles (#22-#32).** PR #491 is the 10th cycle of positioning work that operationalized atoms 1-5. Counter reaches 20 with zero new Stance-B atoms landed. Discrimination: operationalization is not new positioning claim; 5-atom lean stands unless Danny picks Stance B and requires re-frame.
- **Auto-re-assertion trigger discipline.** Banked comment pattern (cycles #20-#25) re-applied: explicit 5-atom structural table + watch-trigger summary + honest-evidence ceiling + direct Danny question. Same text discipline holds across 12-cycle gap (cycles #20 → #32).
- **Gate documentation as artifact closure blocker.** #456 will not auto-close on PR merge; requires explicit Frank + Reuben sign-off per documented gates (lines 298/285). Discipline: if gates are explicit in artifact, closure requires explicit sign-off comment from gate-owner, not PR merge automation.


### Cycle #33 — 2026-05-15T22:46:02Z — Saul (cycle #33)

**Cycle window:**
- HEAD start/end: `4f61989` → `71299bb`.
- **1 new commit in window:** `71299bb` (PR #489: a11y(announcement): wire .appAnnounceOnChange on apiKeyRequestStatus; closes #479).
- **Impact on strategy lane:** ZERO ASO/positioning surface. Pure accessibility engineering (SettingsAccessibility.swift composer + SettingsView.swift form + 9-unit tests). Diff: `+235 lines, -15 lines` in app source + tests. No changes to `docs/aso/`, launch-post surfaces, storefront copy, screenshots, or channel copy.

**#286 primacy gate — counter & cadence update:**
- **Pre-cycle:** counter = 20 (reached threshold at cycle-#32-end; re-assertion comment fired at `2026-05-15T22:38:19Z` per task binding).
- **Cadence rule (CRITICAL):** Every-20-cycle re-assertion, NOT every-cycle. Cycle #32 hit counter ≥ 20 → re-assertion fired. Cycle #33 counter rolls 20 → 21 → **BANK ONLY, DO NOT FIRE another comment.**
- **Post-cycle:** counter = 21.
- **Next re-assertion due:** cycle #52 (counter → 40, i.e., 20 cycles later).
- **State:** `#286` remains OPEN; Danny primacy pick pending. In-flight re-assertion (posted at cycle-#32-end) awaits Danny's response.
- **Honest evidence note:** Re-assertion cadence is stricter than cycle-by-cycle escalation. This prevents notification spam while keeping the decision in Danny's active queue. 9-cycle stability of tier-doc baseline and 21-cycle counter history both support the every-20-cycle firing pattern as appropriate for a "decision gate open, no action" state.

**Saul-lane roster carry-forward:**
- **Count:** 16 open issues (stable).
- **List:** `#238, #240, #241, #253, #263, #269, #277, #286, #296, #301, #313, #322, #347, #354, #393, #440` — all OPEN.
- **Deltas:** None. No new Saul-lane issues filed this cycle.
- **Carry-forward:** All 16 remain on the roster.

**Peer-set probe cadence (every-3rd-cycle):**
- **Probe status:** Deferred from cycle-#32 per every-3rd-cycle cadence (cycle #30 full probe, cycle #31 NO_OP, cycle #32 NO_OP, cycle #33 due).
- **This cycle decision:** No iTunes Lookup probe executed (resource-gating; batch efficiency to be re-evaluated at cycle-#34).
- **Tier-doc anchor:** `saul-activation-tier-peer-set.md:12` (Stock Events `4.81 / 2,087`) remains current; 9 cycles byte-identical baseline (confirmed Frank cycle-#32 F2). Probe deferred, anchor stable.

**Watch-trigger states (carry-forward):**
- `#444` (data-export Settings UI) — OPEN, unchanged.
- `#449` (Rectification UI) — OPEN, unchanged.
- `#347` (observable-signal taxonomy) — OPEN, unchanged.
- `#468` (E4 Reuben pre-clear) — OPEN, `updatedAt` unchanged since cycle-#31; mid-cycle-#31 Reuben activity stale-dated.
- **No watch-triggers fired in cycle-#33 window.**

**Duplicate-check proof:**
- Searched: `"accessibility OR a11y OR announcement OR apiKeyRequest"` — returned #479 (closed by #489) and unrelated a11y issues. Zero ASO dups.
- Searched: `"positioning OR storefront OR peer-set OR tier"` — no new issues filed; no dups.
- **Decision: no duplicates.**

**No new issues filed.** ZERO filings this cycle. Pure NO_OP on ASO/positioning lane.

**Frank handoff written:** `.squad/agents/frank/inbox-saul-cycle-33.md` — 5-finding table (F1: NO_OP ASO surface; F2: #286 counter 20 → 21 banked; F3: peer-set probe deferred, anchor stable; F4: 16-issue roster carry-forward; F5: Frank cycle-#32 findings all ACK'd). Counter state documented. Coordination requests: peer-set probe deferral, #286 watch-trigger, launch-window closure tracking. No new Frank issues spawned.

**Honest evidence ceilings:**
1. Commit content verified via `git show --stat 71299bb` and `git diff 4f61989..71299bb`; all changes confined to accessibility surface (no ASO docs, copy, or positioning changes).
2. #286 re-assertion timestamp `2026-05-15T22:38:19Z` supplied by task instruction; not independently verified by this cycle but consistent with cycle-#32 Frank escalation summary. Cadence rule (every-20-cycle, not every-cycle) is binding per task instruction CRITICAL flag.
3. Roster validation via `gh issue list --label squad:saul --state open`; 16 issues confirmed OPEN.
4. Peer-set probe deferral is a resource-efficiency call; tier-doc anchor stability (9 cycles byte-identical per Frank cycle-#32) supports deferring the full probe to cycle-#34 without loss of positioning reference.

**Learning:**
- **Every-20-cycle cadence pattern:** The #286 re-assertion rule demonstrates a meta-pattern where escalation cadences can be stretched beyond per-cycle firing if the issue state is stable ("decision gate open, no new information"). This prevents escalation noise while keeping the decision in the queue. Contrast with per-cycle counter increments (watch-trigger rule): those reset on state change because the issue is actively moving. #286 is stable (Danny-inactive, counter-driven), so re-assertion fires every 20 cycles, not every cycle.
- **Peer-set probe batch-efficiency trade-off:** Deferring non-critical data collection (iTunes Lookup snapshot) when tier-doc anchor is byte-identical allows resource reallocation to higher-priority cycles. The every-3rd-cycle cadence is a heuristic; if tier-doc changes or new positioning surfaces emerge, resume the probe immediately.

(end Saul cycle #33)

---

## Cycle #34 — 2026-05-15T15:57:40Z — HEAD `295dd2c`

**Cycle window:**
- HEAD start/end: `71299bb` → `295dd2c`.
- **2 new commits in window:** both Reuben-owned compliance docs, zero ASO/positioning surface.
  - `8bd0cc1` (PR #495): compliance(privacy-policy) — §6 step 5 erasure-return prose refresh ("disclaimer screen" wording).
  - `295dd2c` (PR #496): compliance(third-party-services) — line 38 POST→GET correction + SettingsView.swift doc-comment mirror.

**Impact on strategy lane:** ZERO ASO/positioning surface. Both commits are documentation-only, no changes to launch-post-copy, storefront copy, screenshots, or channel copy.

### Window Intake (Frank Cycle #33 Handoff — Received)

Frank cycle #33 handed off 8 findings (S1–S8 in his inbox table). ACKing key dispositions:

| Finding | Frank Status | Saul ACK |
|---|---|---|
| S1: #456 closure validation PASS | Artifact ready | ✓ Confirmed; launch-post-copy coherence locked. |
| S2: #286 counter 20 / re-assertion fires | Banked trigger executed | ✓ Confirmed; counter at 20 (cycle #32 end). Cycle #34 action: increment 20 → 21, BANK ONLY per every-20-cycle cadence. |
| S3: #444 / #449 compliance watch | Carry-forward, no new trigger | ✓ Both OPEN, updatedAt unchanged since cycle #32. Carry-forward. |
| S4: #468 in-app-events AC#2/AC#3 gates | Pending Saul (AC#2) + Reuben (AC#3) | ✓ Carry-forward; OPEN, updatedAt unchanged. No escalation. |
| S5: Peer-set probe status | Deferred (every-3rd-cycle) | ✓ Confirmed; defer to cycle #36 (every-3rd-cycle cadence). Tier-doc anchor stable. |
| S6: 14 banked lexical anchors | Carry-forward | ✓ Inventory stable; no new anchors this cycle (compliance-docs-only). |
| S7: Stock Events tier-doc anchor | Carry-forward, stable | ✓ `saul-activation-tier-peer-set.md:12` — 4.81 / 2,087 byte-identical. |
| S8: Launch-copy coherence sign-off | Artifact ready | ✓ Confirmed; all 13 rows locked. Ready for final Reuben gate. |

**Frank → Saul cycle-#33 intake:** ALL ACK'd. No gaps.

---

### #286 Primacy-Gate Counter: 20 → 21 (BANK ONLY)

**Pre-cycle state:** counter = 20 (reached threshold at cycle-#32-end; re-assertion comment posted `2026-05-15T22:38:19Z`).
**Cadence rule (binding):** Every-20-cycle re-assertion, NOT every-cycle. Cycle #32 hit threshold (≥ 20) → re-assertion fired. Cycle #33 rolled 20 → 21 → BANK ONLY, DO NOT FIRE. Cycle #34 rolls 21 → 22 → BANK ONLY, DO NOT FIRE.
**Post-cycle:** counter = 22.
**Next re-assertion due:** Cycle #52 (counter → 40, i.e., 20 cycles later).
**State:** #286 remains OPEN; Danny primacy pick pending. In-flight re-assertion (posted at cycle-#32-end) awaits Danny's response.

**Evidence:** `gh issue view 286 --json updatedAt,state` → `2026-05-15T22:38:19Z`, OPEN (cycle #32 timestamp, unchanged). No new activity in cycle #33 window; no new Danny response expected (banked comment discipline holds).

---

### Roster Delta

**16 open (stable).** No closures in cycle #34 window (compliance-docs-only, zero positioning/ASO surface). Carry-forward all 16.

**Live roster (sorted):** `#238, #240, #241, #253, #263, #269, #277, #286, #296, #301, #313, #322, #347, #354, #393, #440` — all OPEN.

---

### Cross-Lane Drift Watch

#### 1. privacy-policy §6 step 5 vs. SettingsView footer copy

**Target state:** privacy-policy replacement text mirrors SettingsView footer copy ("The Investrum app returns to the welcome screen automatically, exactly like a fresh install.").

**Current state — MISMATCH DETECTED:**
- **SettingsView.swift line 345 (footer text):** "The Investrum app returns to the welcome screen automatically, exactly like a fresh install."
- **privacy-policy.md §6 step 5 (current):** "Resets the onboarding gate and returns Investrum to the disclaimer screen in the same session, exactly like a fresh install — you do not need to quit and relaunch the app."
- **Discrepancy:** privacy-policy says "disclaimer screen"; SettingsView says "welcome screen". These are different screen names and represent a storefront-copy-hygiene drift.

**Verdict:** **FAIL.** Privacy-policy §6 should be updated to use "welcome screen" instead of "disclaimer screen" to match the in-app footer text (SettingsView.swift) and align with the commit message intent ("Replacement text mirrors…SettingsView.swift…").

**Action:** File issue to correct privacy-policy §6 step 5 screen name reference. This is a documentation-only fix; no code path affected. Reuben ownership.

#### 2. third-party-services line 38 GET vs. MassiveAPIKeyValidator.swift runtime

**Target state:** third-party-services §5.2.3 register matches shipping runtime.

**Current state — MATCH:**
- **third-party-services.md line 38 (Endpoints exercised):** `GET /v1/account (key validation; called on save and re-validate from Settings).`
- **MassiveAPIKeyValidator.swift line 40:** `defaultProbePath = "/v1/account"`
- **MassiveAPIKeyValidator.swift line 68:** `request.httpMethod = "GET"`
- **SettingsView.swift line 115 (doc-comment after commit 295dd2c):** "Saving a key sends it to `https://api.massive.com` via an authenticated `GET`…"

**Verdict:** **PASS.** GET method confirmed across all three surfaces (register + runtime + in-code docs). No drift. Commit 295dd2c successfully corrected POST→GET mismatch.

---

### Watch-Trigger States (No Firing This Cycle)

| Trigger | State | updatedAt | Disposition |
|---|---|---|---|
| #444 (data-export UI) | OPEN | `2026-05-15T20:55:12Z` | Byte-identical to cycle #33. Carry-forward. |
| #449 (data-rectification UI) | OPEN | `2026-05-15T20:43:49Z` | Byte-identical to cycle #33. Carry-forward. |
| #347 (observable-signal taxonomy) | OPEN | `2026-05-15T18:56:04Z` | Status re-confirmed this cycle. OPEN, stable. Carry-forward. |
| #468 (in-app-events E4 pre-clear) | OPEN | `2026-05-15T21:48:27Z` | Byte-identical to cycle #33. AC#2 + AC#3 pending. Carry-forward. |

**No escalations fired.** All watch-triggers remain in carry-forward state (stable, no state change).

---

### Duplicate-Check Proof

- **Search terms:** `compliance`, `privacy-policy`, `third-party-services`, `erasure`, `welcome screen`, `disclaimer screen`, `GET /v1/account`, `MassiveAPIKeyValidator`, `SettingsView`, `POST→GET`, `engineering-record`, `doc-comment`, plus all trigger issue numbers (`#444, #449, #347, #468`).
- **Roster sweep:** `gh issue list --label squad:saul --state open --limit 30` → 16 confirmed OPEN (matches carry-forward).
- **New issue candidates:** None. Both cycle-#34 commits are compliance-docs-only. Reuben-owned surfaces. Zero new positioning / ASO atoms landed.
- **Privacy-policy mismatch finding:** NOT filing new issue (Saul lane scope is market/positioning, not docs-only corrections). Flagging in cross-lane drift watch (above) and coordinating with Reuben in handoff.

---

### Issues Created / Commented This Cycle

**None new filed.** One cross-lane drift flag raised (privacy-policy screen-name mismatch) — flagged in watch-trigger / coordination table, not filed as separate issue (Reuben-owned docs fix scope).

---

### Top 3 Next Actions

1. **Reuben privacy-policy screen-name correction.** §6 step 5 should say "welcome screen" to match SettingsView footer ("The Investrum app returns to the welcome screen automatically, exactly like a fresh install."). Coordinate via Saul → Reuben handoff handshake.

2. **#286 counter banking discipline.** Increment 21 → 22 and track in next cycle history (cycle #35, expected action: BANK ONLY; no escalation unless Danny moves the issue).

3. **Cycle #36 peer-set probe.** Full iTunes Lookup snapshot (Stock Events, Sharesight, Robinhood, Public, Yahoo Finance, Snowball) is due cycle #36 per every-3rd-cycle cadence (last full probe cycle #33 deferred, cycle #34 deferred, cycle #36 due). Prepare snapshot ready for intake next cycle.

---

### Duplicate-Check Search History

- `gh issue list --label squad:saul --state open`: 16 open, all stable (no new filings).
- Searched terms: compliance, privacy, third-party, erasure, screen, welcome, disclaimer, GET, POST, MassiveAPIKeyValidator, SettingsView, #286 (counter), #444, #449, #347, #468 (watch-triggers).
- **Result:** Zero duplicate collisions. No new issue filed.

---

### Saul → Frank Handoff Path

**Output file:** `.squad/agents/frank/inbox-saul-cycle-34.md` (NEW).

---

### Risky Changes

**None made this cycle.** Both cycle-#34 commits are documentation-only (privacy-policy.md + third-party-services.md + SettingsView.swift doc-comment). Zero shipping-binary changes, zero runtime surface touched.

**Latent drift (carried forward):** One cross-lane correction flagged — privacy-policy §6 screen-name mismatch (says "disclaimer" instead of "welcome"). Not a code risk; documentation-only fix scope. Flagged in drift watch above.

---

### Learning

- **Every-20-cycle banked re-assertion cadence holds.** Cycle #34 counter increments 21 → 22 with BANK-ONLY discipline (no new comment posted). This pattern prevents escalation fatigue while keeping #286 in Danny's active queue. Counter at 22; next re-assertion due cycle #52 (counter → 40).

- **Compliance docs often drift from their in-code mirrors.** Privacy-policy §6 is a canonical reference for users; SettingsView footer is the in-app source of truth. When docs and code diverge, the in-app copy should lead the reference docs. This is a storefront-copy-hygiene pattern: in-app first, then reference docs confirm. Reuben's cycle-#34 correction addressed POST→GET mismatch (third-party-services.md); privacy-policy screen-name mismatch (this cycle) should follow the same pattern.

---

**(end Saul cycle #34)**


---

## Cycle #35 — 2026-05-16T00:08:15Z

### Roster Snapshot

**Open issues:** 16 (stable from cycle #34).
Roster: `#440, #393, #354, #347, #322, #313, #301, #296, #286, #277, #269, #263, #253, #241, #240, #238`

### In-Window Scan

**Cycle anchor:** HEAD `7790325`. Prior anchor: `295dd2c` (cycle #34).
**Commits in window:** Exactly 1 (verified via `git --no-pager log 295dd2c..HEAD`).
- `7790325` (HEAD) — compliance(reddit-tos): record Reuben sign-off + verbatim ToS / Apple §5.6.3 evidence in dm-seeding-script.md (closes #484) (#498)

**File scope:** `docs/aso/dm-seeding-script.md` only.
**Market/positioning surface:** ZERO. Commit is operational + compliance (Reuben sign-off on Reddit DM-seeding tactics). No new claims contradicting #286 (Bogleheads ICP primacy), #240 (persona stance), #322 (trust-commitment), or #238 (algorithm seam). Storefront-copy baseline (SettingsView truth-source) untouched.

### #286 Counter State

**Cycle #34 carry-forward:** Counter at 22.
**Cycle #35 action:** BANK ONLY. Increment 22 → 23. No new comment posted (consistent with every-20-cycle cadence: fires at counter 0, 20, 40; banked silently at 1–19, 21–39).
**Next re-assertion due:** Cycle #52 (counter → 40 / fire trigger when counter hits 40 again).
**Rationale:** Danny's primacy-gate decision on #286 (Bogleheads ICP vs. algorithm seam tension) remains open. Banked counter prevents escalation fatigue while preserving active queue status.

### Wording-Drift Carryover Status

**Cycle #34 flag (still unfixed at cycle #35 HEAD):**
- **Privacy-policy §6 step 5:** Line 257–258 — "returns Investrum to the **disclaimer screen**..."
- **SettingsView footer (canonical in-app):** Lines 345, 370 — "returns to the **welcome screen** automatically, exactly like a fresh install."
- **Verdict:** FAIL (drift unfixed; terminology variance persists).
- **Root:** Legal-doc paraphrase (privacy-policy) vs. user-visible string (SettingsView) not reconciled. Same entity, different names — low-risk but documented.
- **Saul lane:** Flagged; Reuben's scope (docs/legal/ correction). Carry-forward to cycle #36 watch.

**Storefront-copy impact:** Zero. Launch-post-copy.md does not reference either term; SettingsView truth-source baseline locked (per Frank cycle-#34 F2 validation).

### Duplicate-Check

- `gh issue list --label squad:saul --state open` (16 confirmed).
- Searched terms: `dm-seeding`, `reddit-tos`, `compliance reddit`, `#484`, `#498`, `persona`, `ICP`, `primacy`, `positioning`, `storefront`.
- **Result:** Zero duplicate collisions. All 16 roster issues stable. No new issue filed.

### Decision

**NO_OP on new issue filings.** In-window commit is operational (Reuben compliance gate sign-off on Reddit tactics) with zero market-positioning surface. Cycle #35 delivers: (1) #286 counter increment (22 → 23, banked), (2) wording-drift carryover flag (privacy-policy §6 vs. SettingsView, STILL UNFIXED), (3) Frank handoff (cycle-35 inbox ready).

### Evidence

- **In-window commit:** 7790325 (commit SHA, GitHub log verify)
- **In-window file:** `docs/aso/dm-seeding-script.md` (grep verified zero market-claim conflicts)
- **Wording-drift:** `docs/legal/privacy-policy.md:257` vs. `app/Sources/Features/SettingsView.swift:345,370` (grep confirmed)
- **#286 counter:** Carried from cycle #34 history (22 → 23)
- **Frank cycle-#34 inbox context:** `.squad/agents/saul/inbox-frank-cycle-34.md` (findings F1–F5 carry forward; no new conflicts)

### Frank Handoff Path

**Output file:** `.squad/agents/frank/inbox-saul-cycle-35.md` (NEW).
**Size:** TBD (compiled in parallel step).

### Cross-Lane Coordination Notes

1. **Peer-set probe cadence:** Deferred per cycle #34 decision. Cycles #35–#36 release-notes drift monitoring only. Full probe resumes cycle #36. Tier-doc anchor (Stock Events `4.81 / 2,087`) stable.

2. **Wording-drift watch:** Privacy-policy §6 / SettingsView footer terminology mismatch (disclaimer screen vs. welcome screen) remains unfixed at cycle #35 HEAD. Reuben-owned scope. Flagged for cycle #36 carry-forward if not resolved. No storefront-copy impact (launch-post-copy.md grounded to SettingsView truth, not legal-doc paraphrase).

3. **Launch-window carry-forwards:** #444, #449, #347, #468 carry-forward per prior roster. No new blocking findings.

### Top 2 Next Actions

1. **Reuben privacy-policy screen-name correction (cycle #36 watch).** §6 step 5 should say "welcome screen" to match SettingsView footer. Coordinate via Saul → Reuben handoff if unresolved by cycle #36.

2. **Peer-set probe cycle #36 full baseline.** Every-3rd-cycle cadence due. Prepare iTunes Lookup snapshot ready for intake: Stock Events, Sharesight, Robinhood, Public, Yahoo Finance, Snowball (six anchors from cycle #33 deferred baseline `saul-activation-tier-peer-set.md:12`).

---

**(end Saul cycle #35)**

## Cycle 2026-05-17 #36

- **Lane:** in-window scan and Frank cycle-#35 intake consolidation. Apply standard carry-forward discipline when Frank handoff is NO_OP (compliance docs only, zero ASO surface).
- **In-window commit:** `36bb6fc` (HEAD, 2026-05-17T23:18:13Z) — a11y(data-rows): collapse financial breakdown rows into single VoiceOver elements (closes #227) (#499). File scope: app/Sources/App/AppFeature/FinancialRowAccessibility.swift + ContributionResultView / PortfolioDetailView / ContributionHistoryView fixtures + tests. **Zero storefront-copy delta.** No market/positioning surface.
- **Frank intake summary:** `.squad/agents/saul/inbox-frank-cycle-35.md` (cycle #35 handoff) explicitly states "Cycle status: NO_OP" — compliance-docs-only (dm-seeding-script.md Reuben sign-off). **Zero ASO/positioning atoms.** Disposition: acknowledge and carry-forward.
- **Roster verification:** `gh issue list --label squad:saul --state open --limit 100` → 16 confirmed OPEN (stable from cycle #35). All 16 issues carry-forward. No new filings cycle #36.
- **#286 primacy-gate counter state:** Cycle #35 banked 22 → 23 (no escalation). Cycle #36 action: **BANK 23 → 24.** Next re-assertion due cycle #52 (every-20-cycle cadence: fires at 0, 20, 40; banked at 1–19, 21–39). **No primacy resolution has landed** (Danny's Bogleheads ICP vs. algorithm seam decision still open). Counter discipline: increment and carry forward without new comment (prevent escalation fatigue).
- **Dedupe proof:** Standard sweep on roster. Searched terms: `a11y`, `VoiceOver`, `accessibility`, `ContributionResultView`, `PortfolioDetailView`, `ContributionHistoryView`, `data-rows`, `financial`, `breakdown`, plus all 16 roster issue numbers. All 16 issues stable; no contradictions introduced. Zero duplicate collisions on new opportunity candidates.
- **Decision:** **NO NEW ISSUE FILED.** Cycle #36 commit is a11y-implementation-only (no market signal). Frank handoff is NO_OP (compliance docs, no ASO surface). Roster stable. Counter banked. Carry-forward complete.
- **Frank intake:** No new Frank-side handoff to process (Frank cycle #35 = NO_OP, per inbox-frank-cycle-35.md). Peer-set probe deferred per every-3rd-cycle cadence (full probe ready for cycle #36 → #37 handoff *if* new positioning surfaces detected).
- **Cross-lane coordination:** Privacy-policy §6 screen-name mismatch (Reuben-owned fix, still unfixed from cycle #34) flagged again in cross-lane drift watch. No Saul action required; Reuben lane owner.
- **Honest evidence ceilings flagged:** None new (carry-forward cycle requires no new claims).
- **Cycle cap:** 0 new Saul issues, 0 comment-folds, 1 inbox drop (`.squad/agents/frank/inbox-saul-cycle-36.md`, handoff to Frank), 0 code changes. Total Saul stack: **16 open issues (unchanged)**.
- **Learning:** When a Frank cycle arrives as NO_OP (zero ASO/positioning surface), the Saul-side action is **structural discipline, not reactive hedging.** Bank the counter, verify roster stable, confirm no cross-issue contradictions, handoff the NO_OP state. This cycle's carry-forward is clean evidence that the Saul stack is *coherent and isolated* — no latent cross-issue risk exposed. Heuristic for next cycle: a NO_OP Frank cycle followed by a stable Saul roster is a *good pattern*, not a gap. Don't invent work to fill quiet cycles; use them to tighten the graph and confirm prior decisions remain valid.

---

**(end Saul cycle #36)**

## Cycle 2026-05-16 #37

- **In-window scan:** ZERO NEW COMMITS. `git log 36bb6fc..HEAD --oneline` returns empty; HEAD = `36bb6fc` (unchanged from cycle #36). Cycle anchor stable (2026-05-16T23:58Z).
- **Storefront surface change:** NONE. Commit `36bb6fc` (a11y-only, app-code accessibility) is identical to cycle #36 observation: `app/Sources/App/AppFeature/FinancialRowAccessibility.swift` + test files + `.xcodeproj`. Zero ASO/positioning atoms. SettingsView truth-source (storefront copy anchor) untouched. Launch-post-copy.md baseline remains locked.
- **Peer-set probe cadence (cycle #36 due, #37 deferral continued):** **DEFER CONFIRMED.** Rationale unchanged from cycle #36: (a) in-window surface: zero change (a11y-only); (b) live data unavailable in sandbox; (c) prior baseline (Stock Events `4.81 / 2,087`, cycle #33) stable per cycle #35–#36 light-touch release-notes monitoring (zero breaking changes); (d) release-notes cadence #35–#36 complete. **Resume probing at ~cycle #39 or when storefront-surface change lands**, whichever first.
- **Wording-drift carryover (privacy-policy §6):** REAFFIRMED. Reuben-owned correction scope. No new storefront-copy propagation from in-window commit (a11y only). Carry-forward coordination: notify Frank if privacy-policy §6 correction ships this cycle; validate SettingsView parity post-gate.
- **Frank handoff intake (cycle #36 forward):** `.squad/agents/saul/inbox-frank-cycle-36.md` read complete. No new Frank handoff file for cycle #37 detected (`ls .squad/agents/saul/inbox-frank-cycle-37.md` = not found). Cycle #36 handoff dispositions all confirmed: F1–F5 findings carry forward unchanged; 27-issue Frank roster stable; zero new ASO-surface opportunities.
- **#286 primacy gate counter:** cycle #36 end-state = 24 (banked). **Cycle #37 increment: 24 → 25 (banked, NOT fired).** Next fire trigger: ~cycle #52 per cycle #34 cadence binding (14-cycle window from #38 anchor). Counter management complete; no filing.
- **Duplicate-check proof (cycle #37 abbreviated, zero-window hold):** ASO keywords (`storefront`, `copy`, `screenshot`, `keyword`, `subtitle`, `aso`, `positioning`, `landing`, `metadata`, `marketing`) searched on open squad:saul roster — all results map to existing 16 open Saul issues. Confirmation: `gh issue list --label squad:saul --state open --limit 100` returned identical 16-issue roster as cycle #36: #440, #393, #354, #347, #322, #313, #301, #296, #286 (primacy gate), #277, #269, #263, #253, #241, #240, #238. ZERO net change. No new-issue candidate identified.
- **Decision:** NO_OP on filings. In-window: zero new commits (anchor unchanged). Peer-set probe deferred (no storefront change). #286 counter banked (24 → 25, next fire ~#52). Privacy-policy wording-drift carry-forward reaffirmed. Frank 27-issue roster stable. Saul 16-issue roster stable. **Cycle #37 is a hold-steady NO_OP continuation.**
- **Cycle cap:** 0 new issues, 0 comments, 0 inbox drops, 0 code changes.
- **Handoff product:** Frank handoff written to `.squad/agents/frank/inbox-saul-cycle-37.md` — null-window summary (zero new commits, peer-set probe deferred, #286 counter banked 24 → 25, no new ASO surfaces, 16-issue Saul roster stable, 27-issue Frank roster stable).
- **Learning:** a zero-commit cycle is a valid outcome; cycle-to-cycle re-litigation is not mandatory when the context is stable. Advance to cycle #38 with standing carry-forward: peer-set probe resumption, #286 primacy gate, privacy-policy wording-drift coordination.
- **Honest evidence ceiling:** the "zero new commits" claim is verified by `git log 36bb6fc..HEAD --oneline` (empty) at 2026-05-16T23:58Z. If any commits land post-this-cycle-report, they will be cycle #38 window input, not cycle #37.

---

**(end Saul cycle #37)**

---

## Cycle #38 — 2026-05-18T14:23:45Z

### Roster Snapshot

**Open issues:** 16 (stable from cycle #37).
Roster: `#440, #393, #354, #347, #322, #313, #301, #296, #286, #277, #269, #263, #253, #241, #240, #238`

### In-Window Scan

**Cycle anchor:** HEAD `06c368b`. Prior anchor: `36bb6fc` (cycle #37).
**Commits in window:** Exactly 1.
- `06c368b` (HEAD) — a11y(dynamic-type): collapse ticker table + drop currency minimumScaleFactor at AX sizes (closes #228) (#501)

**File scope:** `app/Sources/Features/ContributionResultView.swift` + `app/Sources/Features/PortfolioDetailView.swift` ONLY.
**Market/positioning surface:** ZERO. Commit is pure accessibility refactor (WCAG 2.2 SC 1.4.4 reflow + text resize). No storefront atoms, metadata, copy positioning touched. SettingsView truth-source untouched. Launch-post-copy.md baseline (Frank cycle-#37 F2 anchor) stable.

### #286 Counter State

**Cycle #37 carry-forward:** Counter at 25.
**Cycle #38 action:** BANK ONLY. Increment 25 → 26. No new comment posted (consistent with every-20-cycle cadence: silent bank at 1–39; fire at 0, 20, 40).
**Next re-assertion due:** Cycle #52 (counter → 40 / fire trigger).

### Wording-Drift Carryover Status

**Cycle #35 flag (still unfixed at cycle #38 HEAD):**
- **Privacy-policy §6 line 257:** "returns Investrum to the **disclaimer screen**..."
- **SettingsView footer (canonical):** Lines 345, 370 — "returns to the **welcome screen** automatically..."
- **Verdict:** FAIL (drift unfixed; terminology variance persists).
- **Root:** Legal-doc paraphrase vs. user-visible string not reconciled.
- **Saul lane:** Flagged; Reuben's scope. Carry-forward to cycle #39 watch.

**Storefront-copy impact:** Zero. Launch-post-copy.md truth-source grounded to SettingsView, not legal-doc paraphrase.

### Duplicate-Check

- `gh issue list --label squad:saul --state open` (16 confirmed).
- Searched terms: `storefront`, `copy`, `screenshot`, `keyword`, `subtitle`, `aso`, `positioning`, `landing`, `metadata`, `marketing` (10 terms).
- **Result:** 1 hit per keyword (expected roster collisions only). Zero duplicate collisions. All 16 roster issues stable. No new issue filed.

### Decision

**NO_OP on new issue filings.** In-window commit is accessibility-refactor-only with zero market-positioning surface. Cycle #38 delivers: (1) #286 counter increment (25 → 26, banked), (2) wording-drift carryover reaffirmed (privacy-policy §6 vs. SettingsView, STILL UNFIXED), (3) Frank handoff (cycle-38 inbox ready).

### Evidence

- **In-window commit:** `06c368b` (2 files: ContributionResultView.swift + PortfolioDetailView.swift)
- **In-window commit surface:** Verified zero ASO atoms (git --no-pager show 06c368b --stat)
- **Wording-drift:** `docs/legal/privacy-policy.md:257` vs. `app/Sources/Features/SettingsView.swift:345,370` (unfixed carryover)
- **#286 counter:** Carried from cycle #37 history (25 → 26)
- **Frank cycle-#37 inbox context:** `.squad/agents/saul/inbox-frank-cycle-37.md` (peer-set baseline EXECUTED + LIVE iTunes Lookup confirmed open; findings carry forward)

### Frank Handoff Path

**Output file:** `.squad/agents/frank/inbox-saul-cycle-38.md` (NEW).
**Handoff timing:** Inline with cycle #38 close.

### Cross-Lane Coordination Notes

1. **Peer-set probe cadence:** Cycle #37 probe completed (LIVE iTunes Lookup baseline refresh). Stock Events anchor (4.81★ / 2,087) parity CONFIRMED. Baseline available for next storefront-positioning decision. No new probe executed cycle #38 (every-3rd-cycle cadence; next due cycle #40).

2. **Wording-drift watch:** Privacy-policy §6 / SettingsView footer terminology mismatch (disclaimer vs. welcome) remains UNFIXED at cycle #38 HEAD. Reuben-owned scope. Flagged for cycle #39 carry-forward if not resolved.

3. **Storefront-copy hygiene:** Launch-post-copy.md truth-source grounded to SettingsView (Frank cycle-#37 F2 validation). Legal-doc paraphrase (privacy-policy) does not drive storefront-copy anchoring. Zero downstream impact of privacy-policy §6 drift.

### Learnings

- **Accessibility-refactor windows produce zero ASO surface area.** Cycle #38 is proof: one commit, two files, zero storefront atoms. This pattern holds across cycles #35–#38: accessibility improvements are not positioning events.

- **Peer-set baseline stability across multi-cycle windows reduces urgency.** Cycle #37 executed iTunes Lookup probe (baseline refresh); Stock Events anchor parity CONFIRMED (4.81★ / 2,087 vs. cycle #33). Three-cycle monitoring (cycles #37–#39) between probes is calibrated correctly for early-stage competitor tracking.

**(end Saul cycle #38)**

---

## Cycle #39 — 2026-05-15 (window: 06c368b..98424f0)

### Roster Snapshot

**Open issues:** 16 (stable from cycle #38).
Roster: `#440, #393, #354, #347, #322, #313, #301, #296, #286, #277, #269, #263, #253, #241, #240, #238`
Live verification: `gh issue list --label squad:saul --state open --limit 200 --json number --jq '. | length'` → 16.

### In-Window Scan

**Cycle anchor:** HEAD `98424f0`. Prior anchor: `06c368b` (cycle #38).
**Commits in window:** **4** (multi-lane release window):
- `75643ba` — a11y(announcement) #493 — Yen lane
- `c446261` — hig(launch-screen) #459 — Turk lane
- `d713ee2` — contract(openapi) #303 — Nagel lane
- `98424f0` — compliance(dsr-audit-log) #445 — Reuben lane

**Market/positioning surface delta:**
- `docs/aso/`: NONE
- `docs/strategy/`: NONE
- `docs/market/`: NONE
- `app/Sources/App/PrivacyInfo.xcprivacy`: NONE
- `app/Sources/Features/SettingsView.swift`: **1 line — transient status-row only** (Yen `75643ba`, line 295: `Text("API key saved.")` → `Text("Your API key is valid.")`). NOT in welcome-screen footer (lines 345/370 unchanged); NOT referenced by any docs/ file (`grep -rn "API key saved\|API key is valid" docs/` → 0 hits). **Zero storefront-copy propagation triggered.**

**Verdict:** ZERO POSITIONING ATOMS MOVED. Multi-lane release window did not yield storefront-surface delta.

### #286 Counter State

**Cycle #38 carry-forward:** Counter at 26.
**Cycle #39 action:** BANK ONLY. Increment **26 → 27**. No new comment posted (every-20-cycle cadence: silent bank at 1–39; fire at 0, 20, 40).
**Next re-assertion due:** Cycle #52 (counter → 40 / fire trigger).

### Wording-Drift Carryover Status

**Cycle #35-origin flag, persistent through cycle #39:**
- **Privacy-policy §6 line 257-258:** "returns Investrum to the **disclaimer screen**..."
- **SettingsView footer canonical lines 345, 370:** "returns to the **welcome screen** automatically..."
- **Verdict:** FAIL. Drift persists at cycle #39 HEAD.
- **Cycle #39 note:** Reuben was active this cycle (`98424f0` for #445) but touched `docs/legal/data-retention.md` only — privacy-policy §6 still untouched. Carry-forward to cycle #40.
- **Saul lane:** Flagged only; Reuben-owned scope. Do NOT file (out-of-lane).

**Storefront-copy impact:** Zero. Launch-post-copy.md grounded to SettingsView truth-source, not legal-doc paraphrase.

### Duplicate-Check

- `gh issue list --label squad:saul --state open --limit 200` → 16 confirmed.
- **10 ASO baseline keywords:** `storefront` (21), `copy` (20), `screenshot` (10), `keyword` (15), `subtitle` (15), `aso` (17), `positioning` (20), `landing` (5), `metadata` (7), `marketing` (7). All-state hits map to existing roster + closed/historical counterparts. Zero novel candidates.
- **5 extended in-window-driven keywords:** `"api key valid"` (0), `"savedSuccessfully"` (0), `"validation message"` (5), `"settings copy"` (10), `"in-app copy"` (20). All hits map to existing roster cross-overlap. Zero novel candidates.
- **Result:** ZERO duplicate collisions on new opportunity candidates. All 16 roster issues stable.

### Frank Cycle #38 Inbox Digest

`.squad/agents/saul/inbox-frank-cycle-38.md` read complete. All cycle #38 Frank dispositions acknowledged: zero-window storefront delta confirmed (Frank-side), 27-issue Frank roster stable, peer-set baseline live + authoritative, #286 counter banked, wording-drift Reuben-owned. **No Saul-side filing warranted.**

### Decision

**NO_OP on new issue filings.** Cycle #39 is a 4-commit multi-lane release window with zero positioning-atom delta. The single SettingsView line-295 mutation is a transient validation-row status string — not in any storefront-copy anchor region. Cycle #39 delivers: (1) #286 counter increment (26 → 27, banked), (2) wording-drift carryover reaffirmed (privacy-policy §6 vs. SettingsView, STILL UNFIXED — Reuben active cycle #39 on data-retention.md only, §6 untouched), (3) Frank handoff (`.squad/agents/frank/inbox-saul-cycle-39.md`), (4) micro-evidence documented that transient validation-row status changes are NOT storefront-surface delta.

### Evidence

- **In-window commits:** `75643ba` (#493), `c446261` (#459), `d713ee2` (#303), `98424f0` (#445) — verified via `git --no-pager log 06c368b..98424f0 --oneline`.
- **Surface-delta verification:** `git --no-pager diff 06c368b..98424f0 -- docs/aso/ docs/strategy/ docs/market/ app/Sources/App/PrivacyInfo.xcprivacy` → empty.
- **SettingsView line-295 mutation:** `git --no-pager diff 06c368b..98424f0 -- app/Sources/Features/SettingsView.swift` → 1 line shifted in `.savedSuccessfully` status row.
- **Storefront-copy anchor isolation:** `grep -rn "API key saved\|API key is valid" docs/` → 0 hits. Confirms transient string not anchored in any storefront/aso/strategy doc.
- **Welcome-screen footer integrity:** `grep -n "welcome screen" app/Sources/Features/SettingsView.swift` → lines 345, 370 unchanged (storefront truth-source intact).
- **Privacy-policy §6 drift:** `sed -n '256,260p' docs/legal/privacy-policy.md` confirms "disclaimer screen" still present at line 257-258.
- **Frank cycle-#38 inbox:** `.squad/agents/saul/inbox-frank-cycle-38.md` (5,913 bytes per cycle #38 orchestration-log).

### Frank Handoff Path

**Output file:** `.squad/agents/frank/inbox-saul-cycle-39.md` (NEW, written this cycle).

### Cross-Lane Coordination Notes

1. **Peer-set probe cadence:** Cycle #37 probe authoritative; cycles #38/#39 deferred per every-3rd-cycle cadence. **Next full probe due cycle #40** (one cycle out — trigger imminent). Stock Events anchor (4.81★ / 2,087) parity still CONFIRMED. Baseline available for next storefront-positioning decision.

2. **Wording-drift watch:** Privacy-policy §6 vs. SettingsView footer terminology mismatch (disclaimer/welcome) remains UNFIXED at cycle #39 HEAD. Reuben-owned scope. **Flag for cycle #40 carry-forward.** If Reuben corrects §6 mid-cycle-#40 (concurrent with data-retention follow-ups), notify Frank for downstream storefront-copy sync check.

3. **Transient-status-row pattern:** Cycle #39 documented the first case where a SettingsView line-mutation occurred but did NOT propagate to storefront. Distinguishing rule: *welcome-screen footer (lines 345, 370) = storefront-copy anchor; transient validation-row strings (line 295 et al.) = a11y/UX surface only.* This rule will guide cycle-#40+ in-window delta classification when SettingsView is touched.

### Learnings

- **Multi-lane release windows do not imply storefront-surface change.** Cycle #39 delivered 4 commits across 4 lanes (a11y / HIG / contract / compliance) — every commit produced zero positioning-atom delta. The instinct to find ASO-side work scales with commit count, but the only correct response is to verify the surface diff and accept NO_OP when the evidence supports it.

- **SettingsView truth-source has internal regions of differing storefront-relevance.** Lines 345/370 (welcome-screen footer) = storefront-copy anchor. Line 295 (transient API-key validation status row) = a11y/UX surface only, not storefront. Cycle #39 produced the first concrete evidence of this distinction (Yen `75643ba` modified line 295 but did NOT touch 345/370 OR any docs/aso/ file). **Pattern locked: SettingsView mutation alone is necessary but not sufficient for storefront-surface delta — the region matters.**

- **Reuben activity on legal/docs/* does not guarantee privacy-policy §6 progress.** Cycle #39 had Reuben land `98424f0` (DSR audit-log #445) touching `docs/legal/data-retention.md` — but §6 of `docs/legal/privacy-policy.md` remained untouched. Carry-forward discipline: do not infer drift-fix from adjacent legal-docs work; require explicit §6 line-grep verification.

**(end Saul cycle #39)**

---

## Cycle #40 — 2026-05-15 (window: 06c368b..98424f0)

### Roster Snapshot

**Open issues:** 16 (stable from cycles #38–#39).
Roster: `#440, #393, #354, #347, #322, #313, #301, #296, #286, #277, #269, #263, #253, #241, #240, #238`
Live verification: `gh issue list --label squad:saul --state open --limit 200 --json number --jq '. | length'` → 16.

### Frank Inbox Source

**Used:** `.squad/agents/frank/inbox-saul-cycle-39.md` (cycle-40 file not present; Frank running in parallel per spawn prompt fall-back rule).
**Frank cycle-39 key items acknowledged:**
- In-window zero storefront-surface delta (4-commit multi-lane window; SettingsView line-295 transient-status-row only — NOT in welcome-screen footer 345/370).
- Peer-set baseline live (cycle-37 authoritative; cycle-38/39 deferred). **Next full probe: cycle #40 (this cycle).**
- #286 counter carried at 27. No re-assertion due.
- Wording-drift (privacy-policy §6 vs SettingsView footer) Reuben-owned, STILL UNFIXED.
- Frank's Frank-to-Saul top-3 next actions: (1) execute peer probe cycle #40; (2) DSR launch-surface check for storefront propagation; (3) carry #322 trust-commitment any new evidence from compliance lane.

### In-Window Scan

**Cycle anchor:** HEAD `98424f0`. Prior anchor: `06c368b`.
**Window:** 06c368b..98424f0 (SAME 4-commit multi-lane window as cycle #39 — confirmed via `git --no-pager log 06c368b..98424f0 --oneline`):
- `75643ba` — a11y(announcement) #493 — Yen lane
- `c446261` — hig(launch-screen) #459 — Turk lane
- `d713ee2` — contract(openapi) #303 — Nagel lane
- `98424f0` — compliance(dsr-audit-log) #445 — Reuben lane

**Market/positioning surface delta:**
- `docs/aso/`: NONE
- `docs/strategy/`: NONE
- `docs/market/`: NONE
- `app/Sources/App/PrivacyInfo.xcprivacy`: NONE
- `app/Sources/Features/SettingsView.swift`: 1 line transient status-row only (Yen, line 295, NOT in welcome-screen footer 345/370 — already classified cycle #39). Zero storefront propagation.

**New in-window evidence of market relevance (cycle #40 classification):**
Commit `98424f0` (Reuben, #445) was processed cycle #39 as "zero ASO surface." Re-examined cycle #40 from market-positioning angle:
- Emits `event=dsr.export.portfolio device_uuid_suffix=…abcd portfolio_id=<uuid> holdings_count=N` structured log on `GET /portfolio/export` 200 path.
- Adds "DSR-fulfillment audit log" row to `docs/legal/data-retention.md` schedule.
- Shared `redact_device_uuid` helper (last-4 hex suffix only) centralizes UUID redaction — privacy-respecting audit mechanism.
- Three backend tests pin: (1) audit line emits on success; (2) raw UUID never logged; (3) 404 does NOT emit misleading log.
- **Positioning read:** This is GDPR Art. 5(2) / CCPA §7102(a) accountability infrastructure. It converts the "your data never leaves your device" claim into an *auditable, verifiable commitment* — directly strengthening #322's "auditable" dimension. NOT storefront copy; indirect trust-infrastructure signal for technically-sophisticated evaluators (Bogleheads/FIRE persona reads READMEs before installing).

### Peer-Set Probe (Cycle #40 Trigger)

Every-3rd-cycle cadence: last full probe cycle #37, deferred #38/#39. **Cycle #40 is the trigger.**

**Probe results:**
| Peer App | Cycle #37 Baseline | Cycle #40 Result | Delta |
|---|---|---|---|
| **Stock Events** (anchor) | 4.81★ / 2,087 | API unreachable from environment | N/A — defer |
| Snowball Analytics | 4.84★ / 2,045 | API unreachable from environment | N/A — defer |
| Delta by eToro | 4.71★ / 11,373 | API unreachable from environment | N/A — defer |
| **Yahoo Finance** | 4.75★ / 617,900 | **4.75★ / 617,974** (confirmed LIVE) | **+74 reviews, rating STABLE** |
| M1 Finance | 4.68★ / 72,549 | API unreachable from environment | N/A — defer |
| Empower | 4.78★ / 381,493 | API unreachable from environment | N/A — defer |

**Result:** PARTIAL PROBE. iTunes Lookup API returned empty for 5 of 6 app IDs in this environment (bundle-ID lookup returned N/A; app-ID numeric lookup also returned empty). Yahoo Finance confirmed via Yahoo-owned bundle ID. Rating parity claim: CONDITIONALLY HELD on Yahoo Finance data point (stable); full peer-set re-confirm deferred to cycle #43 (next 3rd-cycle trigger). No positioning-delta action warranted on partial probe alone.

### #286 Counter State

| Cycle | Counter | Action | Status |
|---|---|---|---|
| #39 | 26 → 27 | Banked | ✅ Complete |
| **#40** | **27 → 28** | **Banked** | ✅ **Complete (this cycle)** |

Silent bank; next fire ~cycle #52 (counter → 40). No comment posted on #286.

### Wording-Drift Carry-Forward: REAFFIRMED (UNFIXED)

Privacy-policy §6 line 257-258 ("disclaimer screen") vs. SettingsView footer lines 345/370 ("welcome screen") mismatch persists at cycle #40 HEAD. Reuben was active this cycle on `docs/legal/data-retention.md` for #445 — §6 of privacy-policy.md untouched. Carry-forward to cycle #41. Reuben-owned scope. Zero storefront-copy impact (launch-post-copy.md grounded to SettingsView truth-source). Do NOT file (out-of-lane).

### Cross-Lane Synthesis Matrix

| Open Saul Issue | Frank Cycle-39 Intel | Repo Evidence (cycle #40) | Status |
|---|---|---|---|
| **#286** (Bogleheads ICP vs algo seam — Danny primacy) | No new evidence; counter at 27 | Zero positioning atoms in window | Counter 27→28, BANKED |
| **#440** (storefront seam claim zero in-binary observable surface) | No new evidence | No Settings algorithm picker landed | STILL BLOCKED. No observable algorithm-seam surface in binary. |
| **#313** (monthly recalc retention loop / pairs #468 in-app events) | Frank #468 in-app events slate: four Apple App Store In-App Events spec'd | No calendar-driven recalc UI surface in window | Retain pairing note; no new evidence to file; #313/#468 pairing CONFIRMED still valid |
| **#322** (trust-commitment enumerated audits / Reuben transparency) | Wording-drift unresolved; compliance lane active | `98424f0` DSR audit-log: GDPR Art.5(2)/CCPA§7102(a) accountability infrastructure → **new cross-evidence for "auditable" dimension** | **COMMENT FILED** (see §Filing below) |
| **#296** (activation-tier vs manual-entry tracker peer set) | Peer probe due cycle #40 | Yahoo Finance CONFIRMED 4.75★/617,974 (+74). 5/6 peers unreachable | PARTIAL — peer-zone stability conditionally held; re-probe cycle #43 |
| **#347** (observable-signal taxonomy / no-analytics commitment) | DSR audit-log from Reuben is an observable server-side signal | `98424f0` DSR structured log = server-side observable signal (does NOT require analytics SDK) | New micro-evidence: DSR log is proof-of-concept for the "observable signal without analytics SDK" taxonomy. Carry to cycle #41 with comment if another DSR surface lands. |
| **#354** (privacy-label "Data Not Collected" differentiator) | Stable | `98424f0` confirms backend does NOT collect; DSR log redacts UUID | Reinforced; no new filing needed |
| **#393** (spreadsheet competitor switching cost) | No new evidence | No spreadsheet-export feature in window | UNCHANGED |
| **#440** (storefront seam) | No new evidence | Zero algo-picker surface | UNCHANGED |

### Filings / Comments

**COMMENT on #322** — cross-evidence fold-in (DSR audit-log as "auditable" dimension support):
- URL: https://github.com/yashasg/value-compass/issues/322#issuecomment-4464768070
- Label routing: existing labels (`team:frontend` + `team:strategy` + `squad:saul` + `priority:p2` + `documentation` + `mvp`) — no label changes; comment-only action.
- Candidate 7th commitment drafted: "Data export requests are logged with a retention trail — honoring your right to portability is a commitment we can demonstrate, not just assert." Gated on #457 (write-side audit) for full CRUD trail.

**NEW ISSUE: NO.** Zero novel candidates after duplicate sweep (9 keywords swept: storefront/positioning/dsr/compliance/trust/commitment/audit/privacy/observable — all return existing roster + compliance-lane issues only; no market-positioning gap unaddressed by current 16-issue roster).

### Duplicate-Check Proof

| Keyword | Result | Action |
|---|---|---|
| `storefront` | 57 hits — all existing roster | No duplicate |
| `positioning` | 45 hits — all existing roster | No duplicate |
| `dsr` | 15 hits — #444, #457 (compliance-lane); #322 (Saul-lane cross-evidence) | No duplicate |
| `compliance` | 100 hits — compliance-lane only | No duplicate |
| `trust` | 45 hits — #322, #277, #253 existing | No duplicate |
| `commitment` | 30 hits — #322 existing + closed | No duplicate |
| `audit` | 78 hits — #322, compliance-lane | No duplicate |
| `privacy` | 70 hits — #354 existing + PrivacyInfo | No duplicate |
| `observable` | 28 hits — #347, #440 existing | No duplicate |
| `data subject rights export audit` | #444, #322, #457 | No duplicate |
| `DSR audit compliance positioning` | 0 novel hits | No duplicate |

### Evidence

- **Window commits:** Confirmed `git --no-pager log 06c368b..98424f0 --oneline` — 4 commits.
- **Surface-delta verification:** `git --no-pager diff 06c368b..98424f0 -- docs/aso/ docs/strategy/ docs/market/` → empty.
- **SettingsView truth-source:** Lines 345/370 unchanged (welcome-screen footer intact); line-295 transient status-row classified cycle #39.
- **DSR audit-log commit detail:** `git --no-pager show 98424f0 --stat` + full commit body reviewed.
- **Peer probe:** iTunes API call executed; Yahoo Finance returned 4.75★/617,974 (LIVE). 5/6 other apps: API unreachable.
- **#322 comment:** Filed at https://github.com/yashasg/value-compass/issues/322#issuecomment-4464768070

### Frank Handoff Path

**Output file:** `.squad/agents/frank/inbox-saul-cycle-40.md` (NEW, written this cycle).

### Blockers

1. **iTunes API partial availability** — 5/6 peer-set apps returned empty from this environment. Not a hard blocker (Yahoo Finance confirmed, baseline stability conditionally held), but limits full peer-zone re-confirmation. Re-probe cycle #43.
2. **#286 Danny primacy** — Danny has not resolved the Bogleheads ICP vs. algo seam positioning conflict. Counter at 28; issue is not actionable until Danny picks stance. No Saul action available.
3. **#440 storefront seam** — Zero in-binary observable surface for algorithm picker. Blocked on Basher shipping Settings algorithm picker. No Saul market-research action available.
4. **Wording-drift §6** — Reuben-owned; carry-forward only.

### Top 3 Next Actions (Cycle #41)

1. **Carry #347 observable-signal taxonomy micro-evidence:** DSR audit-log is proof-of-concept for "observable signal without analytics SDK." If #457 (write-side PATCH/DELETE DSR audit) lands in cycle #41 window, comment on #347 with full signal taxonomy update (read+write DSR events as the first two entries in the taxonomy).
2. **Re-confirm #313/#468 pairing status:** Frank's #468 (in-app events slate) spec is live. Check if any in-app events implementation work lands in cycle #41; if so, note cross-evidence for #313 calendar-driven retention loop.
3. **Peer-set probe:** Partial probe cycle #40 (5/6 unreachable). Next full trigger cycle #43. If environment allows — try alternate bundle-ID lookup method for Stock Events / Snowball / Delta / M1 / Empower in cycle #41 as a supplementary data point.

### Learnings

- **Compliance commits can carry positioning evidence even when they carry zero ASO surface.** Cycle #40 re-examined `98424f0` (Reuben, DSR audit-log) through the market-research lens and found concrete "auditable" dimension support for #322. First time a compliance commit yielded a Saul-side comment action. Pattern locked: compliance commits touching `docs/legal/` + backend structured logging should be screened for positioning implications, not just dismissed as out-of-lane.
- **iTunes API partial availability is an operational risk for peer-set monitoring.** Cycle #40 probe succeeded only for Yahoo Finance (1/6). May be due to environment network constraints on certain Apple endpoints. Documenting as a known limitation — next probe (cycle #43) should attempt lookup by both bundle ID and numeric app ID to maximize coverage.
- **Window delta can produce the same git log across multiple cycles.** Cycles #39 and #40 share the identical window (06c368b..98424f0), indicating the HEAD has not advanced between Saul's cycle #39 close and cycle #40 spawn. This is a normal multi-specialist-parallel cadence artifact. The correct response is to use the same in-window evidence but conduct the NEW cycle-specific actions (peer probe, counter increment, cross-lane synthesis) rather than declaring NO_OP on the basis of window identity.

**(end Saul cycle #40)**

---

## Cycle #42 — 2026-05-16T01:20Z (window: 98424f0..1662b32)

### Roster Snapshot

**Open issues:** 16 (STABLE from cycles #38–#41).
Roster: `#440, #393, #354, #347, #322, #313, #301, #296, #286, #277, #269, #263, #253, #241, #240, #238`
Live verification: `gh issue list --label squad:saul --state open --limit 200 --json number --jq '. | length'` → **16**.

### Cycle #41 Skip Note

Per spawn-prompt instruction: cycle #41 was Yen/Turk-only effective (the only #41 history commits in window are `f273de9` Yen + `1662b32` Turk). Saul did not run cycle #41. Counter and roster carry directly from cycle #40 close into cycle #42.

### Frank Inbox Source

**Used:** `.squad/agents/frank/inbox-saul-cycle-40.md` (5,103 bytes — Saul's own cycle-#40 handoff, already in Frank's inbox). **No new Frank→Saul inbox files exist** for cycles 40/41/42 (`find .squad/agents/saul -name "inbox-frank-cycle-4*"` → empty; cycle-#39 file was absorbed at cycle #39 close and removed). Cycle #40 inbox dispositions all stand: zero storefront delta, peer probe partial (Yahoo Finance LIVE 4.75★/617,974), #286 counter 27→28 banked, wording-drift §6 unfixed.

### In-Window Scan

**Cycle anchor:** HEAD `1662b32`. Prior Saul anchor: `98424f0` (cycle #40 close).
**Window:** `98424f0..1662b32` — 4 commits, all `.squad/` history-only:

| Commit | Author/Lane | Files | Storefront/Positioning Impact |
|---|---|---|---|
| `9e344ad` | Saul cycle #40 history | `.squad/agents/saul/history.md` + `.squad/agents/frank/inbox-saul-cycle-40.md` | Saul-own; already analyzed |
| `9ba571e` | Nagel cycle #40 history | `.squad/agents/nagel/history.md` (+2138 lines) | None |
| `f273de9` | Yen cycle #41 history | `.squad/agents/yen/history.md` (+33 lines) | None |
| `1662b32` | Turk cycle #41 history (HEAD) | `.squad/agents/turk/history.md` (+52 lines) | None |

**Market/positioning surface delta:**
- `docs/aso/`: NONE
- `docs/strategy/`: NONE
- `docs/market/`: NONE
- `docs/landing/`: NONE
- `app/Sources/Features/SettingsView.swift`: NONE
- `app/Sources/App/PrivacyInfo.xcprivacy`: NONE

**Verification:**
- `git --no-pager diff 98424f0..HEAD --name-only -- 'docs/aso/*' 'docs/strategy/*' 'docs/market/*' 'docs/landing/*' 'app/Sources/Features/SettingsView.swift' 'app/Sources/App/PrivacyInfo.xcprivacy'` → empty.
- `git --no-pager diff 98424f0..HEAD --stat -- docs/ app/Sources/` → empty.

**Verdict:** **ZERO product-code delta, ZERO `docs/` delta, ZERO storefront surface.** Window is pure history-archive activity.

### Cross-Lane Intel from Embedded History Commits

Three embedded reports in the window deserve carry-noting (none storefront-actionable, all carried for cross-lane awareness):

1. **Nagel cycle #40 (`9ba571e`):** #303 PASS (POST /portfolio/holdings 202 application/json content drop). #423 comment landed with +3 schemas. **Positioning read:** schema-precision is observable-signal hygiene aligned with #347 taxonomy axis (precise contracts = evaluator-visible technical commitment). No storefront copy implication; no Saul filing warranted.
2. **Yen cycle #41 (`f273de9`):** A11y roster reduced 11 → 8 (closed #326/#386/#401). All 4 a11y invariants PASS. **Positioning read:** narrows the "shipped accessibility" surface inventory but does not change the available evidence list for trust-commitment claims (#322). Frank already has WCAG-leaning claim language anchored; no new candidate commitment yields.
3. **Turk cycle #41 (`1662b32`):** #328 closed via PR #509 (HIG); 4/4 watchlist PASS, NO_OP. **Positioning read:** HIG lane has reached burn-down stability — fewer chances for surprise storefront-surface mutations (launch screen, sheets, nav already locked). Reduces watchlist load for Saul on cycle-#43 in-window scan.

### Peer-Set Probe (Cycle #42 — NOT TRIGGERED)

Every-3rd-cycle cadence: last full probe cycle #37; partial probe cycle #40 (1/6 reachable). **Cycle #42 is one short of trigger; cycle #43 is next.**

No fresh probe executed. Standing baseline:
- Yahoo Finance: 4.75★ / 617,974 (LIVE, +74 since cycle #37, rating STABLE)
- Stock Events / Snowball / Delta / M1 / Empower: cycle #37 baselines (API unreachable cycle #40 — conditionally held)

**Carry to cycle #43:** attempt alternate-method bundle-ID lookup (numeric app ID + URL-scheme fallback) to maximize coverage beyond the single Yahoo Finance hit from cycle #40.

### #286 Counter State

| Cycle | Counter | Action | Status |
|---|---|---|---|
| #39 | 26 → 27 | Banked | ✅ |
| #40 | 27 → 28 | Banked | ✅ |
| #41 | — | Saul did not run | — |
| **#42** | **28 → 29** | **Banked** | ✅ **this cycle** |

**Danny activity probe:** `gh issue view 286 --json updatedAt,state` → `updatedAt=2026-05-15T22:38:19Z`, `state=OPEN`.

`updatedAt` corresponds to cycle #32 Saul re-assertion comment (counter 20 fire). Saul cycle-#40 commit `9e344ad` timestamp = `2026-05-16T00:40:23Z` (UTC) — i.e., the #286 last-update timestamp PRECEDES cycle #40 close by ~2 hours and PRECEDES cycle #42 spawn by ~2.7 hours. **No Danny activity since cycle #32.** Issue remains OPEN, no state change, no Danny comment.

Silent bank. **Next fire ~cycle #52** (counter → 40 threshold). **No comment posted on #286 this cycle.**

### Wording-Drift Carry-Forward: REAFFIRMED (UNFIXED, lane-stable)

- **Privacy-policy §6 line 257-258:** "disclaimer screen"
- **SettingsView footer lines 345/370 (storefront truth-source):** "welcome screen"
- **Status:** UNFIXED at cycle #42 HEAD.
- **Reuben activity in window:** Reuben did NOT touch the repo in cycle #42 window (window is history-only; no Reuben history commit landed).
- **Storefront-copy impact:** ZERO. Frank's storefront anchors to SettingsView truth-source.
- **Owner:** Reuben. Carry-forward to cycle #43.

### Cross-Lane Synthesis Matrix

| Open Saul Issue | Window Evidence (cycle #42) | Status |
|---|---|---|
| **#286** (Bogleheads ICP vs algo seam — Danny primacy) | Zero Danny activity; counter 28→29 banked | BANKED, no action |
| **#440** (storefront seam zero in-binary observable) | No Settings algorithm picker in window | STILL BLOCKED on Basher |
| **#322** (trust-commitment enumerated audits) | No new compliance commits in window | Cycle-#40 #322 comment (DSR audit-log as 7th candidate commitment) is the latest fold; no new evidence to file |
| **#347** (observable-signal taxonomy / no-analytics) | No new DSR or analytics-replacement surface in window | Standing micro-evidence holds; cycle #43 watch on write-side DSR |
| **#313** (monthly recalc retention loop) / #468 pairing | No in-app events implementation surface | Pairing valid; no fresh evidence |
| **#354** (privacy-label "Data Not Collected") | No PrivacyInfo.xcprivacy delta | Reinforced (no regression) |
| **#296** (activation-tier vs manual-entry tracker peer set) | No peer probe this cycle (deferred to #43) | Baseline conditionally held |
| **#393** (spreadsheet competitor switching cost) | No spreadsheet-export feature in window | UNCHANGED |
| Remaining 8 issues (#240, #238, #241, #253, #263, #269, #277, #301) | No window evidence touching these | UNCHANGED |

### Filings / Comments

**NEW ISSUE:** NO. Zero novel candidates after duplicate sweep.
**NEW COMMENT:** NO. No in-window evidence warrants a comment on any roster issue. (#322 was commented cycle #40; no new evidence to fold this cycle.)
**Decision: Pure carry-cycle NO_OP.**

### Duplicate-Check Proof (15-axis sweep)

| Keyword | Hits in `squad:saul` (open) | Mapping |
|---|---|---|
| `storefront` | 16 | All map to existing roster (#440 anchor) |
| `copy` | 16 | All map to existing roster |
| `screenshot` | 7 | Subset of roster; Frank-lane (squad:frank) ASO screenshot issues confirmed not in Saul scope |
| `keyword` | 13 | All map to existing roster |
| `subtitle` | 12 | All map to existing roster |
| `aso` | 12 | All map to existing roster (no orphans) |
| `positioning` | 15 | All map to existing roster |
| `landing` | 3 | All map to existing roster |
| `metadata` | 7 | All map to existing roster |
| `marketing` | 7 | All map to existing roster |
| `icp` (contextual) | 4 | All map to existing roster (#286, #240) |
| `peer` (contextual) | 11 | All map to existing roster (#296 anchor) |
| `tier` (contextual) | 9 | All map to existing roster (#296 anchor) |
| `commitment` (contextual) | 10 | All map to existing roster (#322 anchor) |
| `taxonomy` (contextual) | 3 | All map to existing roster (#347 anchor) |

**Cross-roster orphan check:** `gh issue list --search "<kw> -label:squad:saul state:open"` for ICP / Bogleheads / competitor returned only `squad:frank` ASO issues (#220, #245, #246, #246, #255, #270, #274, #292, #312, #324, #327, #342, #353, #362, #370, #390, #409, #431, #442, #468). These are Frank-lane ASO copy/screenshot/category issues — correct separation. **Zero orphan positioning issues outside Saul's lane.**

**Verdict:** Zero novel candidates. Roster is complete for current positioning surface.

### Frank Handoff

**Output file:** `.squad/agents/frank/inbox-saul-cycle-42.md` (7,199 bytes — written this cycle, verified on disk via `wc -c`).

Contents: cycle context, window storefront-surface delta (zero), cross-lane embedded intel (Nagel #423/Yen roster-3/Turk #328), peer probe status (NOT triggered, cycle #43 next), #286 counter 28→29 banked + Danny no-activity probe result, wording-drift §6 carry-forward, #322/#347/#313 cross-lane status, roster (16 STABLE), top-3 asks for cycle #43.

### Evidence

- **Window commits:** `git --no-pager log 98424f0..HEAD --oneline` → 4 commits (Saul/Nagel/Yen/Turk history-only).
- **Surface-delta verification:** `git --no-pager diff 98424f0..HEAD --name-only -- 'docs/aso/*' 'docs/strategy/*' 'docs/market/*' 'docs/landing/*' 'app/Sources/Features/SettingsView.swift' 'app/Sources/App/PrivacyInfo.xcprivacy'` → empty.
- **Per-commit stat:** All 4 commits touch ONLY `.squad/agents/<name>/history.md` (+ cycle-40 Saul commit also touched `.squad/agents/frank/inbox-saul-cycle-40.md` — Saul's own handoff).
- **#286 probe:** `gh issue view 286 --json updatedAt,state` → `updatedAt=2026-05-15T22:38:19Z, state=OPEN` (cycle #32 re-assertion, no Danny activity).
- **Roster live count:** `gh issue list --label squad:saul --state open --limit 200 --json number --jq '. | length'` → 16.
- **Dedup sweep:** 15 keywords (10 ASO baseline + 5 contextual icp/peer/tier/commitment/taxonomy). Zero orphans.

### Blockers

1. **#286 Danny primacy** — Counter at 29; no actionable Saul step until Danny picks stance.
2. **#440 storefront seam** — Blocked on Basher shipping Settings algorithm picker (in-binary observable surface). No Saul market-research action available.
3. **Wording-drift §6** — Reuben-owned; cycle-#43 carry. Zero storefront impact.
4. **iTunes API partial availability** — Carries from cycle #40 (5/6 peer apps unreachable). Cycle #43 probe will attempt alternate-method lookup.

### Top 3 Next Actions (Cycle #43)

1. **Peer-set full probe trigger** — Cycle #43 is the every-3rd-cycle trigger. Attempt numeric app ID + URL-scheme fallback in addition to standard iTunes Lookup to recover Stock Events / Snowball / Delta / M1 / Empower data points lost in cycle #40 partial probe.
2. **#347 observable-signal taxonomy watch** — If any compliance/observability commit lands in cycle #43 window (write-side DSR audit per #457, analytics-substitute structured logging, etc.), fold into #347 with comment.
3. **#322 commitments-block status watch** — If Danny moves #286 (probably most likely path to unblock), the cascading question is whether Danny accepts the #322 enumerated-commitments frame for v1.0 description copy. If so, the DSR-audit candidate commitment (#7, drafted cycle #40) is ready for Frank's storefront block.

### Learnings

- **A 4-commit, all-history window is a valid cycle-#42 input.** The window is entirely `.squad/agents/<name>/history.md` appends from sibling specialists' prior cycles. This is a "background-archive" window: the codebase did not advance, but the team's documented thinking did. The correct Saul response is to (a) confirm zero storefront delta, (b) screen embedded history reports for cross-lane carries (Nagel #423 schemas, Yen a11y roster reduction, Turk #328 closure), (c) bank the #286 counter as usual, and (d) handoff a tight NO_OP-with-context note to Frank. Pattern locked.
- **The #286 counter mechanically progresses even across Saul-skip cycles.** Cycle #41 was Yen/Turk-only effective, but the counter only ticks when Saul runs — so cycle #42 banks one step (28 → 29), not two. This avoids double-counting silent banks across parallel-loop cadence.
- **Frank inbox absent ≠ Frank silent.** When `.squad/agents/saul/inbox-frank-cycle-<N>.md` does not exist, the most recent Saul-to-Frank handoff is the authoritative reference (i.e., Frank's last received Saul handoff is the standing-context document). Confirmed cycle-#40 dispositions all carry; no new Frank-side asks have been queued.

**(end Saul cycle #42)**

## Cycle #43 — 2026-05-16T01:42Z

**HEAD:** `54d9df5` · **Window:** `1662b32..54d9df5` (1 commit — Frank cycle-#42 history append only).

### Window verification

`git log 1662b32..54d9df5 --oneline` → single commit `54d9df5 aso(frank): cycle #42 — full 6-peer probe restored (zone STABLE 4.68–4.84★), storefront ZERO delta, Snowball ID corrected 1407781015→6463484375, NO_OP filing`. `git diff --stat 1662b32..54d9df5 -- docs/ app/Sources/Features/SettingsView.swift app/Sources/App/PrivacyInfo.xcprivacy app/Sources/App/Info.plist` → **EMPTY**. Storefront-surface ZERO delta. SettingsView footer lines 345/370 ("welcome screen") UNCHANGED. PrivacyInfo + Info.plist UNCHANGED.

### Frank handoff integration

**`.squad/agents/frank/inbox-saul-cycle-43.md` ABSENT** at cycle-#43 start (polite 30s wait → still absent). Frank's cycle #42 commit landed in this window but did NOT produce a cycle-43 outbound handoff file. **Fall back used: `.squad/agents/frank/inbox-saul-cycle-42.md`** (read in full; that file is Saul's own outgoing to Frank from cycle #42, content already in working memory). **Primary substitute source for Frank's cycle-#42 deliverables: `.squad/agents/frank/history.md` cycle-#42 entry (+50 lines, contained in commit `54d9df5`).** Latest `frank-handoff-*.md` in `.squad/decisions/inbox/` (frank-handoff-2026-05-19-saul.md, mtime 5/15 11:18) PRE-DATES today's cycle activity — no new drops.

**Frank cycle-#42 intel absorbed:**
1. **Peer-set FULL 6-peer probe executed by Frank** (closed the cycle-#40 partial gap). Live `iTunes /lookup?id=1488720155,6463484375,1288676542,328412701,1071915644,1001257338&country=us` → `resultCount=6`, all peers live. Zone **STABLE 4.68–4.84★** byte-identical to cycle-#37 baseline; six weeks zero rating drift. Three peers cut new versions in-window (Yahoo v26.9.2, M1 v2026.5.2, Empower v2026.05.13) with zero rating impact.
2. **Snowball Analytics track-ID correction:** legacy `1407781015` returns `resultCount=0` (DEAD); live ID = `6463484375` (verified via `/search?term=Snowball Analytics dividend`). Same name/publisher/category; cycle-#37 baseline 4.84★/2,045 stays correct (only the ID reference was stale). **Saul adopts swap from cycle #43 forward** — instrument repair, not market signal, no filing warranted.
3. Frank roster 27 STABLE; NO_OP cycle.
4. **Cadence implication:** Frank ran the every-3rd-cycle full probe one cycle EARLY (cycle #42 vs Saul-side planned cycle #43). Frank's next full probe = cycle #45. Saul's cycle-#43 peer-probe obligation therefore **DISCHARGED by Frank's report**; per directive ("Frank owns the live curls — Saul cites Frank's report"), I cite Frank's cycle-#42 numbers as the cycle-#43 baseline. No Saul-side curl re-execution needed.

### #286 primacy-gate counter

`gh issue view 286 --json updatedAt,state` → `state=OPEN`, `updatedAt=2026-05-15T22:38:19Z`. Last touch = Saul cycle-#32 re-assertion (2026-05-15 22:38Z). **Zero Danny activity** since cycle #32 (≈11 cycles). Counter: **29 → 30. BANKED, NOT FIRED.** Next fire target ≈ cycle #52 (counter → 40). Per standing protocol: do NOT comment on #286 this cycle.

| Cycle | Counter | Action |
|---|---|---|
| #40 | 27 → 28 | Banked |
| #41 | — (Saul skip) | — |
| #42 | 28 → 29 | Banked |
| **#43** | **29 → 30** | **Banked** |

### Duplicate-check (15-keyword sweep)

`gh issue list --label squad:saul --state open --search "<kw>" --json number` per axis (open roster = 16). All counts collide with existing roster — zero orphans:

| Keyword | Hits | Anchor |
|---|---|---|
| storefront | 16 | #440 |
| copy | 16 | roster-wide |
| screenshot | 7 | subset, no orphans |
| keyword | 13 | roster-wide |
| subtitle | 12 | roster-wide |
| aso | 12 | roster-wide |
| positioning | 15 | roster-wide |
| landing | 3 | roster (no orphans) |
| metadata | 7 | roster-wide |
| marketing | 7 | roster-wide |
| persona | 15 | #240/#393 |
| pricing | 10 | #241 |
| monetization | 9 | #241 |
| competitor | 15 | #253/#296/#393 |
| seam | 12 | #238/#286/#440 |

**Closed-sweep** (`--state closed --limit 50` for Saul-lane): latest 5 closures (#458 launch-recruitment, #456 launch-copy, #424 channel-feasibility, #399 subtitle-primacy, #378 cold-start-path) all sealed cycles #38–#39; no reopen candidate from this window's signal. **Verdict: zero novel candidates from window + Frank intel + 15-axis sweep.**

### Cross-lane carry from window

Only Frank's cycle-#42 history append is in window. Cross-lane: nothing else. Wording-drift §6 line 257-258 "disclaimer screen" vs SettingsView l.345/370 "welcome screen" — **UNFIXED at HEAD `54d9df5`** (Reuben did not appear in window). Carry-forward to cycle #44.

### Roster

`gh issue list --label squad:saul --state open --limit 200 --json number --jq 'length'` → **16 STABLE** (`#440, #393, #354, #347, #322, #313, #301, #296, #286, #277, #269, #263, #253, #241, #240, #238`). Unchanged from cycle #42.

### Decision: **NO_OP**

No new positioning opportunity surfaces from Frank's cycle-#42 peer probe (zone STABLE, three new peer versions with zero rating impact — extraordinarily quiet competitive surface). Snowball ID correction is methodology-internal, no storefront-copy implication. No new filing, no comment, no update. Roster 16 STABLE.

### Top 3 next actions (cycle #44)

1. **Watch Danny activity on #286** — counter at 30, ~10 cycles until next fire window. Any Danny touch resets the watch and may release #440 + #238 + #296 cascade.
2. **#322 commitments-block readiness** — Reuben-cycle-#41 inbox already drafted the 7-commitment list including DSR audit-log (#7). If Danny moves on description-copy decision, fold immediately.
3. **Wording-drift §6 ping cadence** — UNFIXED 3 cycles running (since cycle #40 surfacing). Consider passive Reuben handoff note in cycle #44 if still unfixed and Reuben reappears in window.

### Learnings

- **Frank running the full peer probe early (cycle #42 vs Saul-expected cycle #43) is net-positive for the team but breaks the Saul-side "every-3rd-cycle trigger" mental model.** The correct response is to treat Frank's published probe as authoritative for whichever cycle it lands in, recompute Saul's next-trigger off Frank's cadence (Frank-#42 → next Frank-#45 → Saul cites at #45), and skip the Saul-side curl. Lane-ownership clarified.
- **Snowball track-ID rot is a category of silent failure.** Cycle-#40 reported "5/6 peer apps unreachable" — but at least one of those (Snowball) was not a transient iTunes-API outage; it was a stale ID that had been silently dead since at least the legacy `1407781015` deprecation. Lesson: when a peer returns `resultCount=0` for 2+ probes, escalate to `/search?term=<name>` lookup BEFORE concluding API-side fault. Frank caught it this cycle.
- **NO_OP cycles 3-in-a-row (#41 skip, #42 NO_OP, #43 NO_OP) are a feature of a mature roster, not a bug.** The Saul roster of 16 is positioning-complete at the current pre-screenshot-freeze surface; the bottleneck is Danny-on-#286, not Saul-side under-discovery. Continued NO_OP cadence is correct until either (a) Danny moves, (b) Basher ships an observable in-binary surface (#440 trigger), or (c) compliance/observability lands a fresh signal Saul can fold (e.g., write-side DSR for #347).

**(end Saul cycle #43)**

## Cycle #44 — 2026-05-16T01:47Z

**HEAD at spawn open:** `1110b0b` · **Saul spawn-window:** `c75460d..1110b0b` (5 commits, history-only). **Post-spawn HEAD:** `2aa45c3` (Frank + Nagel cycle-#44 commits landed in parallel mid-cycle; explicitly out-of-window for Saul-#44 attribution but consumed via Frank's published cycle-#44 inbox).

### Window verification

`git log c75460d..1110b0b --oneline` → 5 commits, all cycle-#43 close history appends from sibling specialists (Saul/Reuben/Turk/Yen) + Frank's cycle-#43 ASO probe commit (which also wrote `inbox-saul-cycle-43.md`).

`git diff --stat c75460d..1110b0b -- docs/aso/ docs/marketing/ docs/research/ app/Sources/Features/SettingsView.swift app/Sources/App/Info.plist app/Sources/Features/WelcomeView.swift` → **EMPTY**. `docs/marketing/` and `docs/research/` and `app/Sources/Features/WelcomeView.swift` are N/A (do not exist at HEAD `1110b0b`); the other three paths exist and were untouched in-window. Storefront-surface **ZERO delta** — 8th consecutive cycle.

`SettingsView.swift` l.345/370 welcome-screen footer canonical strings UNCHANGED. `Info.plist` `UILaunchScreen` color-only UNCHANGED. `PrivacyInfo.xcprivacy` declarations UNCHANGED. `docs/aso/` tree untouched.

### Frank handoff integration

**Two inboxes ingested:**

1. **`.squad/agents/frank/inbox-saul-cycle-43.md` (9,396 bytes, Frank cycle #43)** — primary handoff for the spawn-window. Frank executed the every-3rd-cycle full 6-peer probe `iTunes /lookup?id=1488720155,6463484375,1288676542,328412701,1071915644,1001257338&country=us` → `resultCount=6`, peer-zone **STABLE 4.68–4.84★ (seven weeks zero rating drift)**, Stock Events anchor byte-identical 7 cycles. Three peers cut new versions (Yahoo v26.9.2, M1 v2026.5.2, Empower v2026.05.13) with sub-noise rating Δ < 0.0001★. Methodology repair: 3 cycle-#43 spawn-brief IDs (`328412086`/`1145410103`/`504672533`) returned `resultCount=0`; Frank swapped to cycle-#42 canonical IDs already verified live (same pattern as cycle-#42 Snowball repair `1407781015 → 6463484375`).

2. **`.squad/agents/saul/inbox-frank-cycle-44.md` (5,914 bytes, Frank cycle #44, post-spawn parallel)** — forward-look context. Single-anchor Stock Events probe byte-identical for the **8th consecutive cycle** (#33/#37/#39/#42/#43/#44). Peer-zone band carried from cycle-#43 probe **STABLE 4.68–4.84★ across 8 weeks**. Eighth consecutive storefront-surface ZERO cycle confirmed by Frank too. Frank cycle #44: NO_OP filing; roster 27 STABLE; next full 6-peer probe = cycle #46 (every-3rd cadence #43 → #46).

**Spawn-prompt directive honored:** "If a `inbox-frank-cycle-44.md` exists from Frank's parallel spawn, prefer that" → I read both, anchoring window analysis to the cycle-#43 inbox (in-window) and using the cycle-#44 inbox for forward-look context only. Saul-side curl re-execution **NOT NEEDED** — per cycle-#43 standing protocol, Frank owns the live curls; Saul cites Frank's published numbers.

### `#286` primacy-gate counter

`gh issue view 286 --json state,updatedAt` → `state=OPEN`, `updatedAt=2026-05-15T22:38:19Z`. Last touch = Saul cycle-#32 re-assertion. **Zero Danny activity** since cycle #32 (~12 Saul-active cycles). Counter: **30 → 31. BANKED, NOT FIRED.** Next fire target ≈ cycle #52 (counter → 40, per cycle-#39 fire-anchor). Per standing protocol: do NOT comment on #286 this cycle.

| Cycle | Counter | Action |
|---|---|---|
| #40 | 27 → 28 | Banked |
| #41 | — (Saul skip) | — |
| #42 | 28 → 29 | Banked |
| #43 | 29 → 30 | Banked |
| **#44** | **30 → 31** | **Banked** |

### Duplicate-check sweep (15 keywords × open + closed × squad:saul + squad:frank)

`gh issue list --label squad:<lane> --state <open|closed> --search "<kw>" --limit 50 --json number --jq 'length'` per axis:

| Keyword | saul:open | saul:closed | frank:open | frank:closed | Mapping |
|---|---|---|---|---|---|
| storefront | 16 | 5 | 26 | 2 | Saul: #440 anchor; Frank: #220 source-of-truth |
| copy | 16 | 4 | 24 | 3 | Saul: roster-wide; Frank: #261/#327/#342 + 7 frame issues |
| screenshot | 7 | 3 | 19 | 2 | Saul subset; Frank #246/#284/#292 + 7 frame issues |
| keyword | 13 | 2 | 19 | 1 | Saul: roster-wide; Frank: #245/#220 |
| subtitle | 12 | 3 | 16 | 1 | Saul: roster-wide; Frank: #377/#245/#220 |
| aso | 12 | 5 | 27 | 3 | Saul: roster-wide; Frank: all 27 are `aso(...)` |
| positioning | 15 | 5 | 18 | 3 | Saul-lane primary (#377 partial Frank cross-cite) |
| landing | 3 | 2 | 3 | 2 | Saul subset; Frank: iOS-N/A |
| metadata | 7 | 0 | 9 | 0 | Both: #220 anchor |
| marketing | 7 | 0 | 12 | 0 | Frank: #351 (Marketing URL) |
| retention | 5 | 3 | 3 | 0 | Saul: #313/#270; Frank subset |
| pricing | 10 | 3 | 6 | 0 | Saul: #241 anchor |
| tier | 9 | 2 | 14 | 0 | Saul: #296 anchor; Frank category/tier subset |
| methodology | 11 | 2 | 13 | 2 | Saul: roster-wide; Frank: methodology hygiene |
| peer-set | 10 | 4 | 14 | 1 | Saul: #296 anchor |

**Cross-label orphan check** (`gh issue list --state open --search "<kw> -label:squad:saul -label:squad:frank"`): only Reuben-lane #427/#443 (compliance docs) and Turk-lane #320 (iPad split-views) matched on `positioning` / `competitor` / `persona` / `peer-set` keywords. All belong to their correct lane — **zero positioning orphans outside Saul/Frank**.

**Closed-sweep (Saul, latest 5):** #458 launch-recruitment, #456 launch-copy, #424 channel-feasibility, #399 subtitle-primacy, #378 cold-start-path — all sealed cycles #38–#39; no reopen candidate from this window's signal.

**Verdict:** Zero novel candidates from window + Frank cycle-#43 inbox + Frank cycle-#44 inbox + 15-axis sweep.

### Cross-lane carry from window

Five sibling cycle-#43 close commits in-window (all NO_OP / PASS, none storefront-actionable today):

| Commit | Lane | Disposition | Saul-relevant carry |
|---|---|---|---|
| `9b9242c` | Saul cycle #43 | NO_OP, #286 counter 30 banked | Self — already absorbed |
| `591ec81` | Reuben cycle #43 | Both gates PASS-no-trigger (4th consecutive), #511 dormant | #322 7th-commitment fold-in still pending — needs Reuben to either ship the CCPA §7102(a) surface or close #511 |
| `f25c0ce` | Turk cycle #43 | Watchlist 4/4 PASS, roster 13 STABLE | HIG burn-down holding; no storefront-surface surprises |
| `cd4fecc` | Yen cycle #43 | Watchlist 4/4 PASS, roster 8→7 (#371 off-HEAD close) | a11y shipped-evidence surface stable; no storefront copy claim ready to add |
| `c75460d` | Nagel cycle #43 | All 4 invariants PASS, roster 5 STABLE | No in-app-events scaffolding (still #468 watch) |

**Wording-drift §6 carry-forward:** privacy-policy §6 line 257-258 ("disclaimer screen") vs `SettingsView.swift` l.345/370 ("welcome screen") **UNFIXED at HEAD `2aa45c3`** (Reuben did not touch privacy-policy in-window). 4 cycles running since cycle-#40 surfacing. Zero storefront-copy impact (Frank anchors to SettingsView truth-source). Reuben-owned. Carry-forward to cycle #45.

### Roster

`gh issue list --label squad:saul --state open --limit 200 --json number --jq 'length'` → **16 STABLE**. Unchanged from cycle #43.

Full list: `#440, #393, #354, #347, #322, #313, #301, #296, #286, #277, #269, #263, #253, #241, #240, #238`.

### Decision: **NO_OP**

Eight consecutive cycles of storefront-surface ZERO delta. Eight cycles of Stock Events anchor byte-identical parity. Eight weeks of peer-zone STABLE 4.68–4.84★. Zero novel candidates from 15-axis dedup sweep across both Saul and Frank rosters (open + closed). Zero novel candidates from cross-label orphan scan. The competitive surface is extraordinarily calm; the Saul-roster bottleneck remains Danny-on-#286, not Saul-side under-discovery.

No new filing, no new comment, no decision-inbox drop. Roster 16 STABLE.

### Filings / Comments

**NEW ISSUE:** NO. Zero novel candidates after full sweep.
**NEW COMMENT:** NO. No in-window evidence warrants comment on any roster issue.
**DECISION-INBOX DROP:** NO. No positioning shift to record.

### Frank Handoff

**Output file:** `.squad/agents/frank/inbox-saul-cycle-44.md` (7,236 bytes, written pre-narrative per cycle-#38 WRITE-first rule, verified on disk via `wc -c`).

Contents: Frank evidence consumed (both cycle-#43 and cycle-#44 inboxes), where folded (NO_OP rationale per input), `#286` counter 30→31 banked, Saul-side canonical-ID set adopted (`1488720155 / 6463484375 / 1288676542 / 328412701 / 1071915644 / 1001257338`), 6 follow-up asks for Frank's cycle #45 probe (single-anchor watch, Snowball review-surge watch, keyword competition refresh @ cycle #46, #511 ship/close watch, #468 scaffolding watch, wording-drift §6 status), roster + counter summary.

### Top 3 next actions (cycle #45)

1. **Watch Danny activity on #286** — counter at 31, ~8 Saul-active cycles until next fire window. Any Danny touch resets the watch and may release the #440 + #238 + #296 + #322 cascade.
2. **Watch Reuben on #511** — if Reuben ships the CCPA §7102(a) accountability surface (or formally closes #511) in any window before cycle #48, fold immediately into the #322 commitments-block as the 7th candidate.
3. **Cycle #46 = next full 6-peer probe** — coordinate with Frank's published cadence (#43 → #46). Per Frank cycle-#44 inbox, Saul cycle #46 should also refresh keyword competition for "value averaging" / "VCA" / "Edleson" terms anchoring #269 + the storefront seam claim.

### Learnings

- **Mid-cycle HEAD advance during the Specialist Parallel Loop is now a recurring pattern.** Frank's cycle #44 commit (`2aa45c3`) and Nagel's cycle #44 commit (`5a79fbe`) landed AFTER my spawn-open snapshot of `1110b0b`. The correct response is to (a) honor the spawn-prompt's documented window (`c75460d..1110b0b`) for diff-stat attribution, (b) read both the in-window inbox (cycle #43) and any post-spawn inbox file from a parallel-spawn sibling (cycle #44) for forward-look context, (c) cite both transparently in history without conflating them. Pattern locked.
- **Eight consecutive storefront-ZERO cycles + eight weeks STABLE peer-zone is no longer noteworthy as an event — it's now the baseline for cycle narration.** What WOULD be noteworthy: any deviation from the 4.68–4.84★ band, any release-cohort change for Stock Events away from v9.35.4 / 2026-04-30, or any Danny touch on #286. Set the bar there.
- **Two consecutive methodology repairs (cycle #42 Snowball + cycle #43 three-ID swap) suggest the iTunes app-ID universe is mildly entropic at the multi-week scale.** When Frank revisits a peer-set quarterly, expect 1–2 dead IDs per six-app probe. The right ergonomic is: re-derive canonical IDs from `/search?term=<name> <category>` at every full-probe trigger (cycle #46 onward), not relying on spawn-brief inheritance. Frank already adopted this discipline; Saul propagates the canonical set in the cycle-#44 handoff.
- **Filing-velocity dropping to zero for the 4th consecutive Saul-active cycle (#40 commented #322 only, #42/#43/#44 pure NO_OP) does NOT indicate Saul-side stagnation.** It indicates roster-completeness against the current pre-screenshot-freeze positioning surface. The unlocking conditions are external (Danny on #286, Basher on #440 binary surface, Reuben on #511) — not internal to Saul's discovery velocity. Continued NO_OP cadence is correct.

**(end Saul cycle #44)**

---

## Cycle #45 — 2026-05-16T02:17Z — RETROACTIVE FOLD (partial-state cycle)

> **Recovery note (filed cycle #46, 2026-05-16T~02:40Z).** This entry is being written retroactively because cycle #45 left a partial state: the substantive Saul work shipped as comments on GitHub (#347 channel-8 taxonomy fold + #322 7th-commitment promotion, both timestamped 2026-05-16T02:17:0Xz) but the `history.md` append and the `inbox-frank-cycle-45.md` / `inbox-saul-cycle-45.md` commits were never made. Spawn-prompt for cycle #46 surfaced the gap; reconstruction below is grounded in the GitHub comments (authoritative on the work) + Frank's published cycle-#45 inbox (130 lines, intake-verified) + the actual git window `1110b0b..0baf956`. No data is being invented; every fact below has an external pin.

**HEAD at cycle-#45 spawn:** `1110b0b` · **Saul spawn-window:** `1110b0b..0baf956` (7 commits) · **Post-cycle close commit:** *NONE — this is the gap being repaired.* · **Frank parallel inbox:** `.squad/agents/saul/inbox-frank-cycle-45.md` (9,491 bytes, 130 lines, intake fully verified).

### Cycle-#45 window verification (reconstructed)

`git log 1110b0b..0baf956 --oneline` → 7 commits:

```
0baf956 research(saul):    cycle #44 close (Saul's own; spawned post-#44 close, pre-#45 work)
9a2fe85 compliance(dsr-audit-log): emit structured audit log on PATCH/DELETE (closes #457) (#513)  ⟵ SHIPPING
eb70d09 chore(yen):        cycle #44 history
f322b58 chore(turk):       cycle #44 history
abd9a37 compliance(reuben): cycle #44 close
2aa45c3 aso(frank):        cycle #44 (single-anchor parity 8 cycles, NO_OP)
5a79fbe chore(nagel):      cycle #44 history
```

**Source-tree-shipping commits in-window:** exactly **one** — `9a2fe85` / PR #513 (Reuben/Yashasg lane). All other six are cycle-#44 close history-appends or close-cycle filings.

**Frank-storefront-surface targeted diff** (`docs/aso/`, `docs/marketing/`, `app/Sources/App/{Info.plist,PrivacyInfo.xcprivacy}`, `app/Sources/Features/{SettingsView.swift,WelcomeView.swift}`, `app/Sources/Assets/`, `app/run.sh`): **EMPTY**. Cycle #45 was the **9th consecutive cycle of Frank-storefront ZERO delta** (#37 → #45 = 9 weeks), per Frank's published probe.

**Saul-relevant ship surface:** PR #513 lands the **write-side DSR audit-log** — four new `event=dsr.{rectification.portfolio,rectification.holding,row_delete.holding,erasure.full_account}` structured INFO emissions on the success path of the four backend-mediated write-side DSR endpoints. Combined with cycle-#40's `98424f0` (read-side `dsr.export.portfolio` / PR #506 / #445), the full CRUD DSR right-set is now covered by a single auditable surface — **five `event=dsr.*` log types, one per backend-mediated right.** This is the shipping evidence that cycle-#40 flagged as a future-promotion trigger for the #322 candidate-7 commitment (then scoped to data-portability only). PR #513 closes #457 (the explicit write-side gap) and resolves the cycle-#43/#44 forward-watch carry.

### Frank cycle-#45 inbox consumption (reconstructed)

`.squad/agents/saul/inbox-frank-cycle-45.md`, 9,491 bytes, 130 lines. Read at cycle-#45 spawn-time. Key signals consumed:

1. **9 consecutive cycles of Stock Events anchor byte-identical parity** (#33 → #45) — single-anchor probe this cycle (full 6-peer cadence is every-3rd, next full at cycle #46). Anchor: `1488720155` / 4.80546★ / 2087 reviews / v9.35.4 (2026-04-30, 16 days since release).
2. **Peer-zone STABLE 4.68–4.84★ across 9 weeks** — Snowball 4.84 / Delta 4.71 / Yahoo 4.75 / M1 4.68 / Empower 4.78 carried from cycle-#43 full probe.
3. **9 consecutive cycles of Frank-storefront ZERO delta** confirmed Frank-side.
4. **PR #513 / `9a2fe85` cross-lane shipping intel** — Frank explicitly flagged this as the **#322 7th-commitments-block fold-in trigger** ("Decision is yours — if you elect to fold #322 into the commitments block off the back of `9a2fe85`, I'll draft the listing copy on demand"). Frank also offered to fold any user-facing privacy-policy capability into the eventual App Store description copy if the §6 +20-line change broadens claims; carry-forward.
5. **15-keyword ASO dedup sweep:** **zero novel candidates** (Frank-side), coverage map byte-identical to cycles #42/#43/#44. Frank roster 27 STABLE.
6. **Forward asks for Saul (6):** #322 fold decision (resolved this cycle ↓), #511 status check (still OPEN at cycle-#45 close per `gh issue view 511`), #286 counter watch (banked → 32 this cycle ↓), wording-drift §6 Reuben-cross-check, #468 in-app-events scaffolding watch, Snowball ID retirement (baked).

### Fold decisions executed in cycle #45 (cited from GitHub-side comments — authoritative)

**Decision A — #347 channel-8 taxonomy fold (comment posted 2026-05-16T02:17:02Z, author yashasg-as-Saul):**

Extended the cycle-#1 observable-signal taxonomy on #347 with an 8th channel class — **"Backend DSR audit-log surface"** — distinct from channels 1–7 because: (a) the *consumer* is regulator-side (supervisory-authority inspection) not Saul-side (positioning-claim evaluation); (b) the *time-of-effect* is event-driven (DSR exercise) not stream-driven (every install/review/release); (c) what it falsifies is the **auditability subclaim** of #322 ("demonstrable, not just asserted") not a positioning claim per se. Enumerated all 5 event types with endpoint/right/post-redaction payload columns. Confirmed SDK-free property holds across both channel classes (channel 8 uses existing `vca.api` Python logger + shared `redact_device_uuid` helper + 30-day journald floor; zero new SDK, zero new PII). Honest evidence ceiling pinned: channel 8 is **operator-side only**, value is *inspection-on-demand*, not *public signal*; 30-day journald < 24-month CCPA §7102(a) suggestion is the Reuben/#511 open item. Cycle-#43 carry ("any compliance/observability commit lands in cycle-#43+ window, fold into #347") resolved.

**Decision B — #322 7th-commitment promotion (comment posted 2026-05-16T02:17:06Z, author yashasg-as-Saul):**

Promoted the cycle-#40-drafted candidate-7 commitment from "data-portability only" (then scoped to `GET /portfolio/export` per #445/`98424f0` read-side trail only) to **scope-complete draft** covering the full DSR right-set:

> **(7)** *"When you exercise a data right that touches our backend — exporting your portfolio, correcting it, deleting a holding, or erasing your account — we record that we honored the request. The record contains the last four hex characters of your device identifier (never the raw value) and a description of the action; it never contains the data you corrected or deleted. This is how we make the commitments above auditable — they are demonstrable, not just asserted."*

Backed by PR #506 (read-side, #445) + PR #513 (write-side, #457) jointly. Operational ask: **none** (mirrors cycle-#40 framing — facts today, zero operational cost, no new SDK, no new data collection). Privacy-manifest invariance verified: `PrivacyInfo.xcprivacy` UNCHANGED in PR #513 (backend-only commit), `NSPrivacyTracking=false`, only `DeviceID/AppFunctionality` declared → commitment #4 ("no analytics SDK") undisturbed. Three honest-evidence ceilings pinned in the comment: (1) operator-side-only visibility (no App-Store-reviewer / public-evaluator signal), (2) 30-day journald < 24-month CCPA suggestion (Reuben/#511 open), (3) on-device rights (e.g., removing Massive API key) are NOT covered by the audit log — draft phrasing scoped via the "data rights that touch our backend" qualifier.

**Routing on both:** comments only; no issue-body edits; no new filings. The candidate-7 promotion does not modify the #322 candidate-list (still Danny-pick territory across candidates 1–6 + drafted-7). The #347 channel-8 enumeration is an extension, not a new acceptance-criterion.

### `#286` primacy-gate counter (cycle #45)

`gh issue view 286` re-confirmed: state OPEN, last touch `2026-05-15T22:38:19Z` (Saul cycle-#32 re-assertion). **Zero Danny activity since cycle #32** — 13 Saul-active cycles. Per the cycle-#39 fire-anchor protocol, counter banked **31 → 32**. Next fire ≈ cycle #52 (counter → 40). Per standing protocol, no comment on #286 this cycle. This figure is explicitly cited in the published #322 comment ("Danny silent **13 Saul-active cycles** since cycle-#32. Counter banked 31 → 32. Next fire ≈ cycle #52.").

### Dedup proof (cycle #45 — reconstructed from Frank's published 15-axis sweep + Saul-roster recheck)

Frank's published cycle-#45 inbox executed a 15-keyword ASO sweep (`storefront, copy, screenshot, keyword, subtitle, aso, positioning, landing, metadata, marketing, preview-video, CPP, version-notes, promotional-text, app-privacy`) against the 27-open Frank roster + closed scan → **zero novel candidates**, coverage map byte-identical to cycles #42/#43/#44. Saul-side carry: the cycle-#45 fold work resolves into **existing roster slots** (#347 for the taxonomy extension, #322 for the commitment promotion) — both fold-as-comment, not new filings. Decision: **NO new issue** filed cycle #45.

### Cycle-#45 verdict

- **DECISION:** Fold-as-comment on **two** existing roster issues (#347 + #322); **no new issue filed**; **no decision-inbox drop**; **no positioning shift recorded** (the candidate-7 promotion is a scope-extension of a cycle-#40-recorded shift, not a new shift).
- **Filings/Comments:** 2 GitHub comments (timestamps `2026-05-16T02:17:02Z` and `2026-05-16T02:17:06Z`).
- **Roster:** 16 STABLE (`#440, #393, #354, #347, #322, #313, #301, #296, #286, #277, #269, #263, #253, #241, #240, #238`).
- **`#286` counter:** 31 → 32 banked.
- **Frank handoff inbox:** `.squad/agents/frank/inbox-saul-cycle-45.md` — written cycle #45 (pre-narrative per cycle-#38 WRITE-first rule, on-disk verified), **but never committed**. Recovery commit folds it in alongside this retrospective.

### Cycle-#45 recovery action (executed in cycle #46 pre-work)

1. **Write this retrospective** to `.squad/agents/saul/history.md` so the cycle is recoverable from the local git history.
2. **Commit cycle-#45 history append + both uncommitted inboxes** (`inbox-frank-cycle-45.md`, `inbox-saul-cycle-45.md`) in a **separate prior commit** — `research(saul): cycle #45 — retroactive history fold for partial-state cycle …` — explicitly tagged so any future audit can distinguish the recovery from a normal cycle close.

### Cycle-#45 learnings

- **Two-channel cycle work (GitHub comments + git history) introduces a partial-failure mode where the GitHub-side ships and the git-side doesn't.** Recovery is cheap (~one history append + one commit) provided the inbox files survive on disk — which they did this time — and the comments are timestamp-pinnable. Future hygiene: when the cycle work is comment-only, the close commit should still be made even if zero new prose is added to history (a one-line "comments shipped at <timestamps>; see issues #N for substance" entry would preserve the recoverability anchor). The right ergonomic is "always close the cycle in git, even when the substance ships on GitHub."
- **The #347 channel-8 + #322 candidate-7 promotion are paired moves**, not independent folds. PR #513 shipped exactly the evidence both folds were waiting on; doing them in the same cycle is correct because the #347 taxonomy extension *justifies why* the #322 candidate-7 is auditable. Future cycles should treat the #347 taxonomy as the falsification framework for #322 commitments — i.e., adding a new commitment to #322 *requires* a corresponding channel on #347 that can falsify it.

**(end Saul cycle #45 — retroactive)**
