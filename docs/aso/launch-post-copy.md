# Launch-day post copy — HN Show HN, r/SideProject, IndieHackers

> Frank (App Store Optimizer) draft artifact for issue #456. Writes the
> launch-day public-post copy for the volume funnel locked in
> `docs/aso/channel-feasibility.md` and
> `docs/aso/cold-start-launch-playbook.md`. This file is launch-ready
> copy, not launch authorization: Frank coherence sign-off and Reuben
> claim-vs-code sign-off remain open in the gate tables below.

| Field | Value |
|---|---|
| Decision owner | Frank (App Store Optimizer) |
| Decision date | 2026-05-15 |
| Status | **Drafted; sign-off pending.** |
| Closes | #456 once the Frank + Reuben gates below are signed and the launch-day-minus-1 parity pass is run |
| Surfaces | HN Show HN, r/SideProject, IndieHackers milestone story |
| Locks against | `docs/aso/subtitle-positioning.md`, #327 description-body scope-honesty block, screenshot-caption issues #362 / #370 / #387 / #400 / #409 / #431 / #442, `docs/legal/third-party-services.md`, `docs/legal/privacy-policy.md` |

## Decision

1. **H1 — title primacy:** every Show HN title draft leads with the
   user-control axis (`No Sign-Up` / `No account` / `No tracking`) before
   the methodology axis (`VCA` / `value cost averaging`).
2. **H2 — Massive-key disclosure:** the HN opening paragraph leads with a
   one-sentence disclosure that the current market-data path expects a
   user-supplied Massive API key.
3. **H3 — build-in-public arc:** the IndieHackers draft leads with the
   deliberate choice not to ship an analytics SDK, account system, or
   broker sync layer.
4. **All three surfaces ask for feedback, not ratings, reviews,
   referrals, or TestFlight signups.**
5. **Public-launch copy stays on the shipping-binary ceiling:** free at
   v1.0, manual entry only, no broker sync, no Android claim beyond
   saying it does not exist, no public TestFlight link.

## Rule anchors (verbatim)

> **HN Show HN:** "Show HN is for something you've made that other
> people can play with. ... Please make it easy for users to try your
> thing out, ideally without barriers such as signups or emails."
> — quoted in `docs/aso/channel-feasibility.md`

> **r/SideProject sidebar:** "r/SideProject is a subreddit for sharing
> and receiving constructive feedback on side projects."
> — quoted in `docs/aso/channel-feasibility.md`

> **Apple App Store Review Guideline 5.6.3 — Discovery Fraud:**
> "Participating in the App Store requires integrity and a commitment to
> building and maintaining customer trust. Manipulating any element of
> the App Store customer experience such as charts, search, reviews, or
> referrals to your app erodes customer trust and is not permitted."

> **TestFlight scope lock:** "TestFlight Public Link (invite-only only)."
> — `docs/aso/cold-start-launch-playbook.md`

## HN Show HN draft

### Title variants (H1)

| Variant | Title | Why it exists |
|---|---|---|
| **A — PRIMARY** | `Show HN: Investrum – No sign-up, free VCA calculator for DIY investors` | Closest to the locked subtitle order: user-control lead, free second, methodology third. |
| B | `Show HN: Investrum – No account, no tracking VCA app for DIY investors` | Stronger privacy/trust lead for HN readers who skim titles faster than bodies. |
| C | `Show HN: Investrum – No broker sync, no sign-up VCA planner for DIY investors` | Explicit anti-aggregator variant; useful only if operator wants the anti-Delta / anti-Plaid contrast in the title itself. |

### Paste-ready body

```text
Links: App Store {APP_STORE_URL} · Repo https://github.com/yashasg/value-compass · Privacy {PRIVACY_POLICY_URL}

First disclosure, because it changes whether this is useful: Investrum is free at v1.0, has no account and no tracking, ships without an analytics SDK, and the current market-data path expects a user-supplied Massive API key in Settings rather than a bundled feed.

What it is: a local-first iPhone/iPad app for DIY investors who want to run a monthly value cost averaging check without linking a brokerage. You enter categories, tickers, prices, and budget manually; the app calculates a per-ticker target contribution and keeps a local snapshot history for the next month.

Why it might be interesting: I wanted the product to stay smaller than the usual tracker stack — no account, no broker sync, no upsell, no live-ticker theater, just a monthly recalc loop for people who would otherwise keep this in a spreadsheet because every "free" tracker starts by asking for login or aggregation access.

Tech notes: native Swift app, local-first SwiftData storage, and TCA for state management. Portfolio data stays on-device; the current off-device path is the user-supplied Massive key validation flow.

I'd value feedback on the tradeoffs, not reviews: is the no-sign-up / no-tracking posture actually useful, is the Massive bring-your-own-key step too much friction, and what missing feature would make this a non-starter for you?
```

### Operator notes

- Keep the Massive sentence in paragraph 1, sentence 1. Do **not** slide
  it into a reply comment.
- Use title A unless the operator deliberately wants privacy-led (B) or
  anti-broker-sync-led (C) framing.
- Do **not** add "please upvote," "please review," or "share with a
  friend" language in the thread opener or follow-up comments.

## r/SideProject draft

### Title

```text
[Investrum] - free, no-account VCA tracker for DIY investors
```

### Paste-ready body

```text
Indie dev here. First disclosure, because it's load-bearing: Investrum is free at v1.0, has no account and no tracking, ships without an analytics SDK, and the current market-data path expects a user-supplied Massive API key in Settings.

What it does: local-first iPhone/iPad VCA tracking for DIY investors who want manual entry instead of broker sync. You set categories, tickers, prices, and a monthly budget; the app calculates a per-ticker contribution target and keeps snapshot history on-device.

What it does not do in v1: no broker sync, no Android client, no tax-lot tooling, no real-time quote terminal. If those are the must-haves, this is probably not your app.

Why I built it: I kept defaulting back to a spreadsheet because a lot of "free" investing apps start with a login, an aggregator permission, or an upsell. I wanted the architecture to match the pitch.

Feedback I want: does the no-account / no-tracking angle make this more compelling, or does the Massive BYOK step cancel it out?

Repo: https://github.com/yashasg/value-compass
Privacy: {PRIVACY_POLICY_URL}
App Store: {APP_STORE_URL}
```

### Operator notes

- Keep the indie disclosure in sentence 1.
- Keep the "what it does not do" block intact; it is the Reddit-side
  version of #327's scope-honesty block.
- Do **not** add TestFlight language; public launch means storefront link
  only.

## IndieHackers milestone story draft

### Suggested title

```text
I shipped a free VCA app without analytics, accounts, or broker sync
```

### Paste-ready body

```text
I just shipped Investrum, a small iPhone/iPad app for DIY investors who want a monthly value cost averaging loop without giving a brokerage or an account system control of the workflow.

The most deliberate launch choice wasn't the calculator. It was the stuff I left out: no analytics SDK, no account creation, no broker sync. The app is free at v1.0, and the current market-data path expects a user-supplied Massive API key in Settings, so I disclose that up front instead of pretending the app has a bundled feed.

That constraint made v1 smaller but clearer. The app is manual entry only: categories, tickers, prices, monthly budget, per-ticker target contribution, and local snapshot history. It is not a brokerage, not a tax tool, and not an Android launch.

Why build it this way? Because the audience I care about is already skeptical of "free" tools that start by asking for login, aggregation permission, or tracking. If the architecture and the copy do not match, the launch post becomes fiction.

What I'd love feedback on from other builders: does "no analytics" read like a real differentiator or just a niche preference, and is a BYOK data-provider step acceptable if the product stays no-account and local-first?

Links:
- Repo: https://github.com/yashasg/value-compass
- Privacy Policy: {PRIVACY_POLICY_URL}
- App Store: {APP_STORE_URL}
```

### Operator notes

- This is a **milestone story**, not a subreddit-style launch blast.
- The no-analytics architecture choice is the editorial hook; keep it in
  paragraph 2 even if the title changes.
- If IH formatting supports link cards, use the App Store link first, the
  repo second, the privacy policy third.

## Pre-registered comment-response set

**Use these as the first reply shape, not as immutable scripture.** If the
current binary changes, the response changes with it.

### A. Massive-key gotcha

**Hypothesis:** top comment says the app is not really free or hides the
Massive dependency.

```text
That's fair to call out. v1 does not ship with a bundled market-data plan. If you want the current market-data path, you add your own Massive API key in Settings — that's why the opener discloses it in sentence 1 instead of burying it in a reply. The portfolio itself stays local, the key is stored in Keychain, and there is still no account or analytics SDK. If BYOK makes it a non-starter for you, that's useful feedback rather than a misunderstanding.
```

**Guardrail:** do not speculate about future bundled-data pricing and do
not upgrade "free at v1.0" into "free forever" in the reply.

### B. "Why no Android?"

**Hypothesis:** top comment treats platform scope as a credibility gap.

```text
Because I would rather ship one local-first client honestly than promise two half-finished ones. v1 is iPhone/iPad only, and I have not shipped an Android client. If Android is the only way you'd try it, that's valid signal — but I don't want to fake certainty on a timeline that doesn't exist.
```

**Guardrail:** do not promise a roadmap date, waitlist, or "coming soon"
claim.

### C. "Why no broker sync?"

**Hypothesis:** top comment assumes broker sync is the obvious missing
feature.

```text
That's a deliberate scope cut, not an accident. I built this for people who do not want a Plaid-style aggregator or another account requirement just to run a monthly allocation check. Manual entry is the product, not the temporary placeholder. If you want automatic broker sync, there are better apps for that job today.
```

**Guardrail:** do not imply broker sync is secretly in progress.

### D. "This is just a spreadsheet"

**Hypothesis:** top comment says the product is indistinguishable from a
sheet.

```text
The overlap is real, and if your spreadsheet already handles the loop cleanly you may not need this. The bet here is that a local iPhone/iPad app with per-ticker targets, saved snapshots, and no account/no tracking is a better monthly workflow than maintaining the formulas and state by hand. But manual entry is still the model — I'm not claiming it replaces every spreadsheet use case.
```

**Guardrail:** do not get defensive about the comparison; concede the
overlap and explain the narrower workflow bet.

### Post-launch fold rule

If a top comment on any surface lands one of the four gotchas above,
record: **platform, hypothesis, reply used, whether it defused the
concern, and what copy changed next cycle**. The comment-response set is
not evergreen. A pre-empted gotcha that still becomes the top comment is
follow-up-cycle evidence, not operator bad luck.

## Coherence audit

| Surface | Locked reference | HN draft | r/SideProject draft | IH draft | Audit |
|---|---|---|---|---|---|
| Subtitle lock (#418 surfaced in `docs/aso/subtitle-positioning.md`) | `No Sign-Up · Free · VCA Calc` | Title variants keep user-control lead ahead of free and methodology | Title keeps `free, no-account VCA` ordering close to the lock | Body keeps no-account + free at v1.0 + VCA framing | **Pass** — no free-led or methodology-led rewrite |
| Description body (#327) | Not a brokerage; no broker sync; not a subscription/paywall; BYOK Massive key; not a tax tool; not a real-time quote engine | Says manual entry, no broker sync, no upsell, BYOK Massive, no live-ticker theater | Explicit "what it does not do" block names no broker sync / no Android / no tax-lot / no real-time quote terminal | Says manual entry only; not a brokerage; not a tax tool; not an Android launch | **Pass** — scope-honesty block preserved across all three |
| Frame 1 (#362) | `Plan your monthly investing` / `Your categories` / `Your budget` | Uses monthly-investing / budget / categories language | Uses categories, tickers, monthly budget | Uses monthly loop / categories / budget | **Pass** — same job-to-be-done lane |
| Frame 2 (#370) | `Value cost averaging` / `Math, not guesswork. Per-ticker target each month.` | Spells out value cost averaging and per-ticker target | Uses `VCA` in title and per-ticker contribution in body | Uses VCA and per-ticker target language | **Pass** — no yield / performance / alpha claims |
| Frame 3 (#387) | `No account. No tracking. Your portfolio stays on your device.` | Says no account, no tracking, local-first; avoids `data never leaves your phone` | Same | Same | **Pass** — narrowed privacy claim remains truthful |
| Frame 4 (#400) | `Organize how you invest` / `Group tickers into categories. Search NYSE & ETFs.` | Mentions manual categories/tickers organization; no search-feed overclaim | Same | Same | **Pass** — organizational frame preserved without live-data implication |
| Frame 5 (#409) | `See how your plan plays out` / `Snapshots over time. Per-ticker charts.` | Mentions local snapshot history and monthly recalc | Same | Same | **Pass** — history loop named; no returns claim |
| Frame 6 (#431) | Working placeholder `Bring your own strategy`; safe fallback = truthful local-calculator / user-owned-math frame only | Avoids any claim of user-selectable strategies or rule-builder UI | Same | Same | **Pass** — no selector/pluggability overclaim |
| Frame 7 (#442) | `Built for the desk` / `iPad split-view: portfolio and result side-by-side.` | HN body says iPhone/iPad app only | Reddit body says iPhone/iPad only | IH body says iPhone/iPad only | **Pass** — cross-device support stated narrowly; no Android inflation |
| Trust commitments (#322) | user-control voice; no upsell; no account; no ads/trackers | No upsell / no account / no tracking all present | Same | Same | **Pass** — voice stays declarative, not hype-led |
| Claim-vs-code gate (#353) | no analytics SDK / Data Not Collected posture / free at v1.0 / no account | Says no tracking + no analytics SDK + free at v1.0 | Same | Same | **Pass** — no `free forever` upgrade in primary drafts |
| Massive disclosure (#294) | third-party flow must be named at consent + public copy must not pretend the feed is bundled | Sentence 1 disclosure in opener | Sentence 1 disclosure in opener | Paragraph 2 disclosure in story hook | **Pass** — BYOK Massive dependency disclosed before comments can weaponize it |

## Hard-fail checklist

> **5.6.3 bright line:** "Manipulating any element of the App Store
> customer experience such as charts, search, reviews, or referrals to
> your app erodes customer trust and is not permitted."

> **Beta-distribution bright line:** "TestFlight Public Link (invite-only
> only)."

| Check | Hard-fail condition | Why it hard-fails |
|---|---|---|
| [ ] | Any line asks for reviews, ratings, upvotes, referrals, or "support the launch" | Violates Apple 5.6.3 discovery-fraud line |
| [ ] | Any public TestFlight link appears in title, body, comments, profile, or follow-up edit | Launch plan is public-storefront-only; TestFlight remains invite-only |
| [ ] | **Launch-day-minus-1 claim-vs-code parity row is not re-run** for `no analytics SDK / no account / free at v1.0 / user-supplied Massive API key required` | Public copy exceeded current code truth |
| [ ] | Any draft implies broker sync, Android availability, tax tooling, live quotes, or a bundled data plan | These are not shipping-binary claims |
| [ ] | HN opener loses the first-sentence Massive disclosure or the Show HN title drifts off the user-control lead | Breaks H1/H2 and reopens the top-comment trap |

## Honest evidence ceilings

1. **Show HN is effectively one shot per project.** H1 title learning gets
   one clean launch-window read, not a repeatable pre-launch A/B rig.
2. **No measured baseline traffic or CTR exists for these three launch
   surfaces.** Any pre-launch traffic expectation is convention, not
   repo-owned data.
3. **`r/SideProject` `rules.json count: 0` does not mean "no mod
   discretion."** It means no formal rules were exposed on that endpoint
   when `docs/aso/channel-feasibility.md` was drafted.
4. **The IndieHackers milestone recommendation is community convention,
   not a rule-audited surface in this cycle.** Treat the IH draft as a
   best-practice story shape, not a guaranteed rules-safe formula.
5. **A 5–7 person founder/squad sniff-test is qualitative, not
   statistical.** If the copy gets a positive small-sample read, that is
   useful tone evidence, not proof of launch-surface conversion.

## Reuben compliance gate

Reuben's gate is the **same claim-vs-code discipline as #353**. Public
copy stays on the narrower wording (`free at v1.0`) unless Reuben
explicitly clears a stronger claim.

Claims to verify against the current code + policy stack before launch:

- `free forever` — **not used in the primary drafts; blocked unless
  Reuben explicitly clears it**
- `no tracking`
- `no account`
- user-supplied Massive API key disclosure / requirement

| Reuben issue | Sign-off date | Evidence URLs cited | Required edits |
|---|---|---|---|
| _(pending — same gate as #353)_ | _(blocked)_ | _(blocked)_ | _(blocked)_ |

## Frank coherence gate

Frank confirms this artifact stays coherent with:

- the locked subtitle ordering in `docs/aso/subtitle-positioning.md`
- the #327 description-body scope-honesty block
- the Frame 1 / Frame 3 above-fold caption logic (#362 / #387)
- the full caption-stack continuity recorded in the audit table above

| Frank issue | Sign-off date | Surfaces checked | Required edits |
|---|---|---|---|
| _(pending — #456 coherence pass)_ | _(blocked)_ | _(blocked)_ | _(blocked)_ |

## Cross-links

- `docs/aso/channel-feasibility.md` — names HN / r/SideProject / IH as
  the public-launch volume funnel
- `docs/aso/cold-start-launch-playbook.md` — Phase 2 launch-day routing
  + invite-only TestFlight constraint
- `docs/aso/subtitle-positioning.md` — locked subtitle order
- `docs/aso/dm-seeding-script.md` — sign-off-table precedent and 5.6.3
  no-review-ask discipline
- `docs/legal/third-party-services.md` — Massive disclosure source of
  truth
- `docs/legal/privacy-policy.md` — no-account / no-analytics / local-
  first claim floor
- `docs/testflight-readiness.md` — launch-day-minus-1 claim-vs-code
  parity row
