# Subtitle positioning — v1.0 lock: `No Sign-Up · Free · VCA Calc`

> Saul (Market Researcher) decision artifact for issue #399. Resolves
> the four-axis subtitle contention contested across cycles
> #2/#5/#7/#9/#11/#12/#13 and closes Frank's #377 acceptance criterion
> #1 with a structural framework rather than a binary verdict.

| Field | Value |
|---|---|
| Decision owner | Saul (Market Researcher) |
| Decision date | 2026-05-15 |
| Status | **Locked pending Danny primacy confirmation.** Default-active if Danny does not signal a methodology-led pivot before storefront-SoT freeze (#220). |
| Closes | #399 (this artifact) |
| Addresses | #377 AC #1 (Saul reviews subtitle v1/v2 and confirms positioning priority) |
| Supersedes | #220 baseline subtitle `Value Cost Averaging` (20 chars, single-axis, methodology-led) |

## Decision

The v1.0 App Store **subtitle** locks to:

```
No Sign-Up · Free · VCA Calc
```

- **Length:** 28 characters (U+00B7 middle-dot counted as 1 visible char,
  matching Apple's App Store Connect 30-char hard limit and Python
  `len()`).
- **Axis composition:** three positioning axes composited under
  Stance A primacy — `user-control · free-first · methodology
  (qualified)`.
- **First-character priority:** `user-control` leads. Stance A primacy
  (cycle #13 narrowing) preserves the voice convention used across
  #322 + #312 + #327 + #362 + #370 + #387, making the subtitle the
  8th — and highest-impression — user-control voice surface.

## Why this string

### Four-axis contention narrowed to three-axis composite

| Axis | Subtitle eligibility | Source |
|---|---|---|
| User-control (`No Sign-Up`) | **Lead** | Cycle #13 Stance A primacy; #322 voice register |
| Free-first (`Free`) | **Composite** | Frank #377 free-first observation; #353 Data Not Collected pairing |
| Methodology, qualified (`VCA Calc`) | **Trailing qualifier** | Cycle #9 keyword fold; #269 Edleson framing |
| Tier-anchor (`Manual Investing`) | **Body-distributed only** | #296 segment-mirror anchor; visual / peer-set distribution |

The tier-anchor axis (#296) is **intentionally** body-distributed
because peer-set framing reads more credibly via tier-anchored
screenshot composition (#245 / #362 / #370) and segment-mirror copy than
via a first-person subtitle claim of tier identity. Tier-anchor's
exclusion from the subtitle is a feature, not a constraint.

### Voice-convergence rule (cycles #10/#11/#12/#13)

User-control now occupies seven storefront surfaces. Subtitle leading
with `No Sign-Up` makes it surface eight — and the highest-priority of
the eight, because subtitle is the first 30 characters Apple renders
in App Store search-result rows before any caption, screenshot, or
description body.

### Keyword pollution immunity (cycle #9)

The standalone token `vca` polluted by veterinary / construction /
medical apps in the US iTunes Search Top-10 on 2026-05-15. The
qualified form `VCA Calc` (`Calc` disambiguates as "calculator",
locking the methodology lane) reads as a qualifier-not-standalone
construct that survives the cycle #9 pollution finding. **This claim
is interpretive — see Honest Evidence Ceiling §3 below for the
verification gap.**

### Character-budget validation

| Candidate | Length | Decision |
|---|---:|---|
| `No Sign-Up · Free · VCA Calc` | **28** | **Locked** — Stance A primacy preserved; 3-axis composite |
| `Free · No Sign-Up · VCA Calc` | 28 | Frank #377 v1 verbatim; ordering rejected (free leads, not user-control) |
| `No Sign-Up · Free VCA Calc` | 26 | Drops second `·` to reclaim 2 chars — reserve as fallback if Apple subtitle-render review surfaces a glyph-budget issue |
| `Free VCA Portfolio Tracker` | 26 | Frank #377 v2 — drops user-control entirely; **rejected** (Stance A axis lost) |
| `Value Cost Averaging` | 20 | #220 baseline — single-axis; 10 chars unused; **superseded** |

### Pivot fallbacks (if Danny signals primacy change)

Stance A primacy has held across seven Saul cycles. If Danny narrows to
the methodology-led pivot before #220 storefront-SoT freeze, swap to:

- `VCA · No Sign-Up · Free` (28) — methodology-lead variant
- `Edleson VCA · No Sign-Up` (24) — provenance-anchored variant

Each preserves three axes and the U+00B7 separator convention.

## Cross-issue coherence audit

Reviewed 16 open Saul issues. **No contradictions.** Reinforcing axes:
#240, #253, #263, #277, #286, #322, #347, #354, #393 (9 reinforces, 7
neutral, 0 contradicting). Detailed matrix is on issue #399 body.

## Downstream actions (no new issues; existing scope)

- **Frank #377:** close AC #1 referencing this lock and update storefront SoT (#220) once that artifact exists.
- **Frank #220:** populate `subtitle` field with the locked string when the SoT structure lands.
- **Frank #245:** dedupe `value`, `cost`, `averaging` from the keyword field (now in subtitle) and reclaim ~20 bytes for `dividend`, `etf`, `bogleheads` per Frank's segment-stuffer convention.
- **Frank #342:** drop redundant `Free` from promo text; pivot reclaimed bytes to feature depth.
- **Frank #390:** post-launch CPP A/B can test alternative subtitle leads (lead-with-`Free` vs lead-with-`No Sign-Up`) if conversion data surfaces a re-ordering opportunity.

## Reuben gate (clearance summary)

- `No Sign-Up`: legally defensible. No account backend wired at v1.0 (`docs/legal/privacy-policy.md` §2.3) and #353 Data Not Collected scope confirms the claim against current code.
- `Free`: legally defensible. No IAP entitlement at v1.0 per #220 storefront SoT (when filed); EULA / ToS posture (#398) does not change this.
- **Revisit trigger:** if v1.x adds IAP or any payment surface, this subtitle must be re-evaluated. The "free" axis becomes time-bounded the moment a paid tier ships.

## Honest evidence ceilings

1. **First-character priority is heuristic, not measured.** Apple does
   not publish whether App Store search-result rows truncate subtitles
   or render them left-priority. Segment convention treats them as
   left-priority but no published Apple guideline confirms this.
2. **Competitor subtitle scan is partial.** Frank #377 captured Delta
   ("Track Stocks, Crypto and more") and Yahoo Finance ("Investing,
   Portfolio & Alerts"). Stock Events, Snowball, M1, and Wealthfront
   subtitles are unscanned (iTunes Lookup API returned 404 / partial
   data for Stock Events on 2026-05-15). The segment-burying-paywall
   claim could be weakened by a wider scan.
3. **`VCA Calc` qualifier-not-standalone claim is interpretive.** Cycle
   #9's pollution finding was for `vca` as a search query, not for
   `VCA Calc` in display context. Could be re-tested via a literal
   `"VCA Calc"` search before storefront-SoT freeze.
4. **Pre-install trust hierarchy is inferred, not measured.** The
   ordering `no-account > no-IAP > methodology > peer-tier` derives
   from #253 review-pain mining and Frank #312 bucket data. It is not
   quantified per-signal in install-conversion lift.
5. **Tier-anchor body-distribution is positioning judgment.** Could be
   PPO-tested in a CPP variant (#390) but not pre-launched as
   competing subtitle.
6. **PPO post-launch can validate the ordering.** Switching to
   `Free`-lead is one Frank-side string change with no downstream
   artifact impact (subtitle is a leaf node in the storefront DAG).

## Acceptance — Saul-side close

- [x] Saul reviews subtitle v1/v2 (#377) and locks ordering via
      structural framework rather than binary verdict.
- [x] Locked string passes character budget (28 ≤ 30).
- [x] Locked string preserves Stance A primacy (cycle #13).
- [x] Locked string passes Reuben gate (no IAP at v1.0; no account at
      v1.0).
- [x] Cross-issue coherence audit run (16 open Saul issues; no
      contradictions).
- [x] Honest ceilings enumerated.
- [ ] Danny confirms primacy (pending — default-active if no pivot
      signal arrives before #220 SoT freeze).

## Acceptance — Frank-side follow-up (out of this PR's scope)

Frank owns the storefront-copy execution. Tracked on issue #399 and the
relevant Frank issues (#377 / #220 / #245 / #342 / #390); not blocked
by this lock.

---

— Saul, cycle 2026-05-15. Resolves #399; addresses #377 AC #1.
