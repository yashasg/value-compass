# Cold-start launch playbook — invite-only TestFlight beta → public launch

> Saul (Market Researcher) decision artifact for issue #378. Frames
> the pre-public-launch TestFlight phase as a **cold-start credibility
> investment**, not just a channel test (#263), so the first 30–90 days
> of public availability are not dominated by single-review rating
> swings.
>
> This playbook is a planning artifact. Execution decisions
> (cohort size, exact start date, recruitment ad-copy) are Danny's call
> at scope-lock time; this artifact records the *why* and the
> *measurable success criteria* so the decision is auditable.

## Decision

Investrum launches via a **2–4 week invite-only TestFlight beta** with
50–100 qualified users before flipping to the public App Store
listing. Beta cohort is recruited from the #240 V1 ICP (Bogleheads /
FIRE / dividends Reddit communities; spreadsheet refugees) and
qualifies on willingness to leave an App Store review on public
launch day.

The playbook stacks with — does not replace — three existing
strategies: #263 (channel-validation), #312 (responsive-template
review handling), and #277 (trust-cycle engagement). Cold-start is the
*first 90 days*; those three are the steady state after.

## Why this exists

### Competitor cold-start baseline (US storefront, iTunes Lookup, 2026-05-15)

| App | Rating | Ratings count | Cold-start observation |
|---|---:|---:|---|
| Stock Events | 4.81 | 2,087 | Established; engagement-quality win |
| Snowball Analytics | 4.84 | 2,045 | Documented 14-day trial (no credit card); staged onboarding |
| Yahoo Finance | 4.75 | 617,871 | Brand incumbent; not a cold-start comparable |
| Delta (eToro) | 4.71 | 11,373 | Brand-halo from eToro |
| M1 Finance | 4.68 | 72,536 | Brokerage; KYC + funding delays first-value |
| Wealthfront | 4.79 | 17,370 | Advisory incumbent |

**The two highest-rated manual-entry-tracker apps (Stock Events
4.81 / Snowball 4.84) are also the two with the smallest ratings
counts (~2,000).** Engagement quality, not raw volume, dominates the
segment. Cold-start credibility investment for Investrum should
optimize for the same shape: 20–40 high-quality reviews in the first
72 hours instead of chasing scale.

### Snowball trial / engagement model (verbatim from pricing page, 2026-05-15)

> "After registration you get full access to all functions of Snowball
> Analytics. The only exception is – you can add only 2 portfolios. To
> add more portfolios, you can upgrade to the Investor plan.
> [...] If you exceed limits of the free plan, you will be asked to
> upgrade or remove portfolios/holdings. **We NEVER remove your data
> without your permission.**"

Signals that map directly to Investrum's #322 user-control / #353 Data
Not Collected stance: trial-to-free (not trial-to-paywall) reduces
abandonment, and explicit data-respect language addresses the #253
"data hostage" pain cluster from competitor review mining.

### Frank #312 support-response evidence (correlation)

From the 6-app, 300-review competitor mining in #312:

- `support_response` complaint bucket = **16/132 low-star reviews
  (12%)** — "Feedback ignored," "Dev doesn't seem to care," "Emailed
  support — never got back."
- Stock Events and Snowball — the two highest-rated apps — had the
  fewest `support_response` complaints in the sample.

Beta is the rehearsal: when the public binary ships, the developer-
response muscle is already warm and beta testers' reviews cite
responsiveness.

## Phase plan

### Phase 1 — Invite-only TestFlight beta (2–4 weeks pre-launch)

| Field | Value |
|---|---|
| Cohort size | 50–100 qualified users (Danny picks within this band) |
| Recruitment surfaces | **Hybrid funnel per `docs/aso/channel-feasibility.md` (#424):** volume funnel — HN Show HN + r/SideProject + IndieHackers Stories; persona-fit funnel — DM-seeded TestFlight invites off organic comment engagement on r/Bogleheads / r/dividends / r/personalfinance, single r/financialindependence Wednesday Self-Promotion thread, Bogleheads.org forum modmail petition. **Public posts to r/Bogleheads / r/dividends / r/personalfinance / r/investing are rules-banned** ("even if not monetized" / permanent-ban clauses); the original "r/Bogleheads, r/dividends, r/personalfinance" enumeration is superseded by the audit in #424 |
| Qualification gate | (a) Self-identifies as DIY investor; (b) Currently uses Stock Events / Snowball / spreadsheet / no tracker; (c) Agrees in writing to leave an App Store review on public launch day |
| Build flag | TestFlight build with v1 feature scope, "Beta" marker visible in onboarding (no production privacy-policy URL until #224 hosting lands; in-app link points to repo source-of-truth) |
| Feedback channel | Discord server **or** Reddit megathread (single channel; not both — avoid splitting attention). Developer responds within 48 h |
| Bug SLA | 48 h turnaround on crash reports; pre-public-launch fixes only |
| Testimonial collection | Optional "What did you like?" email after week 1 and week 3; only verbatim quotes used downstream |
| Cohort tagging | Manifest tags every recruit with funnel source per `docs/aso/channel-feasibility.md` §Cohort tagging schema (`persona-fit-dm-*` / `persona-fit-fire-wednesday` / `persona-fit-bogleheads-forum` / `volume-hn` / `volume-reddit` / `volume-ih`) so post-launch attribution (#347) can separate signals |

### Phase 2 — Public launch day (coordinated single-day flip)

| Action | Owner |
|---|---|
| TestFlight cohort updates to production binary | Beta users |
| In-app SKStoreReviewController prompt fires **once** on launch day | App (per #345 prompt cadence) |
| Launch post to **HN Show HN + r/SideProject** (volume funnel per `docs/aso/channel-feasibility.md`), plus an IndieHackers milestone story within 7 days. **No public posts to r/Bogleheads / r/dividends / r/personalfinance / r/investing** — rules-banned per #424. DM-seeded `persona-fit-*` recruits receive direct launch-day notification (1:1) | Frank / Saul co-author |
| Frank's storefront copy (#220), screenshots (#246), promo text (#342) all go live simultaneously | Frank |
| Privacy Policy hosting (#224), App Privacy nutrition label (#271 closed), age-rating questionnaire (#287), DSR paths (#329 / #333), retention schedule (#339), and EULA posture (#398) all confirmed green | Reuben |

**Target outcome (day 1–3):** 20–40 App Store reviews, average ≥4.0★,
seeding credibility before random discovery traffic dilutes the rating
pool.

### Phase 3 — Post-launch (days 4–30)

| Mechanism | Issue | Note |
|---|---|---|
| Developer-response on every review | #312 | Templates pre-written; beta is the rehearsal |
| Keyword rank + rating-trend telemetry (observable-signal only; no analytics SDK) | #274 / #347 | Daily checks for 30 days; weekly thereafter |
| In-app ratings prompt cadence | #345 | Positive-moment qualification only; segment-pain anti-patterns avoided |
| Trust-cycle engagement (response on segment-pain reviews) | #277 | Anti-#312-`support_response`-bucket |

## Success criteria (day 30 post-public-launch)

- **Reviews count:** ≥ 20 App Store reviews (beta-seeded + organic).
- **Rating:** ≥ 4.0★ average.
- **Zero `support_response` complaints** in reviews per #312 bucket
  taxonomy (i.e., no review cites "developer didn't respond").

If achieved → cold-start credibility investment validated; continue
the #345 + #313 (monthly retention loop) cadences.

If missed → triage by candidate cause: (a) beta cohort didn't
convert; (b) product-persona mismatch (#240 segment drift); (c)
competitor dynamics shifted (Saul re-runs the segment scan); (d)
ratings-prompt timing wrong (#345 re-tunes positive-moment trigger).

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Beta cohort doesn't convert to reviews | Recruitment-form explicit consent: "We'll ask you to leave a review on launch day"; only confirmed-willing users get an invite. |
| Beta reveals MVP-blocking bugs | Better to find pre-launch than post-launch. Public launch delays are within Danny's call; the 2–4 week window absorbs one slip. |
| Beta testimonials read as astroturfing | Only quote verbatim user feedback; disclose "beta tester" provenance in every Reddit / Show HN post. Never paraphrase a tester's sentiment. |
| First organic review post-launch is 1★ | #312 responsive templates + #277 trust-cycle engagement absorb this; cold-start strategy stacks with — does not replace — those steady-state mechanisms. |
| App Store Review Guidelines 5.6.3 violation via review incentivization | Out of scope. Beta-tester ask is "we'll *request* a review", never *incentivize*. |

## Out of scope — explicitly NOT proposed

- Paid user acquisition (no ads, no influencer budget).
- TestFlight Public Link (invite-only only).
- Multi-month beta (2–4 week ceiling; longer delays public revenue
  with no marginal credibility lift past 4 weeks per segment
  observation).
- Review incentivization (App Store Review Guideline 5.6.3 violation).
- Cross-platform beta (iOS only at v1.0; Android is post-v1 if at
  all).

## Integration with open issues

| Issue | Direction |
|---|---|
| #240 (Bogleheads / FIRE / dividends persona) | Recruitment targets same persona; channel mix lives in `docs/aso/channel-feasibility.md` per #424 |
| #263 (channel-validation) | This playbook extends #263 with cold-start framing; #424 records the public-post → DM-seeding pivot |
| #274 (keyword-rank / rating telemetry) | Phase 3 measurement reads from #274 |
| #277 (trust-cycle response) | Beta is the rehearsal; steady state post-launch |
| #296 (manual-entry tier anchor) | Tier-mirror peer set (Stock Events / Snowball) sets engagement-quality benchmark |
| #312 (response templates) | Beta is the dry run |
| #313 (monthly retention loop) | Post-cold-start mechanism |
| #322 (trust-commitment register) | Recruitment ad-copy leads with the #322 commitments |
| #345 (ratings-prompt cadence) | Phase 2 + Phase 3 cadence |
| #347 (observable-signal taxonomy) | Cold-start success criteria use #347's signal set; #424 cohort tagging adds a new `channel-mix accuracy` signal class |
| #353 / #354 (Data Not Collected pairing) | Trust-signal stack in recruitment ad-copy |
| #399 (subtitle lock) | TestFlight build ships with the locked subtitle if Apple's TestFlight metadata exposes it |
| #424 (channel feasibility) | Source-of-truth for the recruitment-surfaces row in Phase 1 above |

## Honest evidence ceilings

1. **"20–40 reviews within 72 h" is a projection, not a guarantee.**
   Math: 50 beta users × 40 % review-followthrough = 20 reviews; 100
   beta users × 40 % = 40. The 40 % followthrough is the segment
   conservative estimate (Snowball / Stock Events review-volume vs.
   plausible install base) and could be 10 % to 60 % in practice.
2. **Snowball / Stock Events cold-start trajectory is unobserved.** We
   see the current state (4.8★, ~2 k reviews) but not how those apps
   got there. The "engagement-quality > scale" inference is the
   segment-mirror observation, not Snowball's documented strategy.
3. **Beta cohort representativeness depends on recruitment surfaces.**
   r/Bogleheads + r/dividends + Show HN over-index for the #240
   primary ICP; if cold-start data ends up positioning-mismatched, it
   could be because the cohort was too narrow rather than the product
   being off.
4. **48 h bug-fix SLA is operational, not measured.** Danny / Basher
   / Virgil capacity during the beta window determines whether this
   target holds. If capacity is tight, the SLA stretches and the
   #312 `support_response` clearance benefit shrinks.
5. **2–4 week beta-length ceiling is segment judgment, not measured.**
   Public-launch revenue cost of additional beta weeks (no IAP at
   v1.0 → no direct revenue cost; opportunity cost is reviewer
   attention drift) is interpretive.
6. **Apple's TestFlight metadata exposure is not a guarantee.** If
   App Store Connect does not surface the subtitle / screenshots in
   TestFlight builds, beta testers see only the "What to test" field
   and the description body. Confirm at the operational step.

## Downstream owners

- **Danny:** approve 2–4 week beta phase; pick cohort size within the
  50–100 band; set public-launch date.
- **Frank:** beta-invitation email copy; launch-day Reddit / Show HN
  posts (with consented testimonials); coordinate #220 / #246 / #342
  go-live.
- **Basher / Virgil:** ensure TestFlight build is v1-feature-complete;
  hold 48 h bug-fix SLA during beta.
- **Reuben:** confirm the eight pre-submission sync surfaces (binary,
  `PrivacyInfo.xcprivacy`, Privacy Policy #224, App Privacy nutrition
  label, age rating #287, third-party-ToS #294, retention schedule
  #339, DSR paths #329 / #333) are green before public-launch flip.
- **Saul (me):** monitor beta feedback for positioning adjustments;
  collect testimonials for launch-day Reddit post; re-run segment
  scans if success criteria miss at day 30.

---

— Saul, cycle 2026-05-15. Resolves #378. Extends #263 channel plan
with cold-start credibility framing.
