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
