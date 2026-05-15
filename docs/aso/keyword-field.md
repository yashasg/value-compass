# Keyword field allocation — v1.0 en-US lock

> Frank (App Store Optimizer) decision artifact for issue #467. Locks the
> post-#418 100-byte App Store Connect Keyword field allocation for the
> `Investrum` v1.0 en-US listing. Supersedes the pre-subtitle-lock keyword
> sections in #245 and #220 (v1 + alt seeds).

| Field | Value |
|---|---|
| Decision owner | Frank (App Store Optimizer) |
| Decision date | 2026-05-15 |
| Status | **Primary locked.** PPO holdback retained for post-launch `tracker`-query rank pivot. |
| Closes | #467 (this artifact) |
| Supersedes | #245 keyword-field section (subtitle section already superseded by #418); #220 v1/alt keyword seeds (pre-lock, byte-wasteful against the locked subtitle corpus) |
| Locks against | #418 subtitle lock (PR #418, merged) + [`docs/aso/subtitle-positioning.md`](subtitle-positioning.md) |

## Decision

The v1.0 App Store Connect **Keyword field** (en-US) locks to:

```
value cost averaging,dollar cost averaging,portfolio planner,offline,dividend,etf,long term
```

- **Length:** 91 bytes (UTF-8), 91 ASCII characters — confirmed by
  `len(s.encode('utf-8'))` against the literal string above.
- **Apple cap:** 100 bytes (App Store Connect 2025 spec).
- **Headroom:** 9 bytes reserved for a single-token swap-in
  post-launch without re-allocating (e.g. a Frank PPO experiment
  trading `analytics` ↔ `tracker` ↔ `planner` once query-rank data
  arrives).
- **Token count:** 7 comma-delimited tokens after Apple's compound
  tokenizer (Apple splits each comma-delimited entry on space + hyphen
  + punctuation, so the indexed token list is: `value`, `cost`,
  `averaging`, `dollar`, `portfolio`, `planner`, `offline`,
  `dividend`, `etf`, `long`, `term` — `averaging` and `cost` index
  once across both `value cost averaging` and `dollar cost
  averaging`).

## Why this string

### Dedup-against-corpus mechanics (Apple App Store Connect)

Apple's indexer reads the **app name + subtitle + keyword field** as
one corpus and ranks each unique token once for search relevance. Any
keyword-field byte spent on a token already indexed from the app name
or subtitle is structurally wasted shelf space.

Tokens already indexed at the corpus level after PR #418:

| Source | Tokens added to the indexed corpus |
|---|---|
| App name `Investrum` | `investrum` |
| Subtitle `No Sign-Up · Free · VCA Calc` ([subtitle lock](subtitle-positioning.md)) | `no`, `sign`, `up`, `sign-up`, `free`, `vca`, `calc` |

The locked keyword field above contains **zero** tokens drawn from
that corpus — every byte purchases a new indexed signal.

### Three-candidate matrix (byte-verified)

The byte counts in the table below were computed by encoding each
literal string to UTF-8 and measuring `len()`; the strings are
copy-paste safe (all ASCII, comma delimiter only).

| Candidate | Bytes | String |
|---|---|---|
| A | 93 | `value cost averaging,dollar cost averaging,portfolio,offline,long-term,dividend,etf,analytics` |
| **B (PRIMARY)** | **91** | `value cost averaging,dollar cost averaging,portfolio planner,offline,dividend,etf,long term` |
| C (PPO holdback) | 91 | `value cost averaging,dollar cost averaging,portfolio tracker,offline,dividend,etf,analytics` |

### Why **Candidate B** is primary

- **Voice continuity with the locked subtitle.** `portfolio planner`
  carries the actor-noun voice (`Calc` → `Calculator` → `Planner`)
  established by the subtitle's trailing `VCA Calc` qualifier and
  re-used across the user-control voice register in
  #322 / #312 / #327 / #362 / #370 / #387. `tracker` (Candidate C)
  reads as segment-vernacular (Stock Events, Snowball, DivTracker
  subtitles per #245 evidence) — useful as a query-rank backstop, but
  voice-incongruent with the v1.0 storefront stack.
- **9-byte headroom.** B leaves the most room for a post-launch
  single-token swap-in without forcing a re-allocation that would
  ripple through #220 / #324 / #327. A leaves 7 bytes; C leaves
  9 bytes too but locks in `tracker` which is the harder voice
  rollback.
- **Long-tail gateway capture.** `dollar cost averaging` is the
  segment's highest-volume gateway query (Bogleheads / r/dividends /
  FIRE per #240 persona evidence) and the term DIY-investor users
  actually type into App Store Search before discovering VCA. Pairing
  it with `value cost averaging` (segment-empty per #245) captures
  both the gateway and the differentiator with one allocation —
  exactly the `DCA-curious → VCA-adoption` funnel surfaced in #393.
- **Persona-vocabulary tokens.** `dividend` and `etf` index against
  the Bogleheads/FIRE persona vocabulary (#240) without spending on
  segment-saturated low-distinguish tokens (`investment`,
  `investment tracker`, `monthly contributions`).
- **First-position weight.** `value cost averaging` retains the
  leading position; Apple's keyword-best-practices doc notes that
  leading tokens carry a slightly higher relevance signal (the gain
  is unmeasured; treat as a tiebreaker, not a primary driver).

### Tokens deliberately dropped vs the pre-lock candidates

| Dropped token | Source(s) | Reason |
|---|---|---|
| `vca` | #245 A/B, #220 alt | Subtitle-deduped (`VCA Calc` in [subtitle lock](subtitle-positioning.md)) |
| `calculator` / `calc` | #245 A/B, #220 alt | Subtitle-deduped (`VCA Calc`) |
| `vca calculator` | #220 alt | Both halves subtitle-deduped — full 15-byte waste |
| `investment tracker`, `investment` | #220 v1, #245 B | Low-distinguish; segment-saturated across the 7-app peer set (#245 evidence) |
| `monthly contributions` | #220 v1 | Apple tokenizer breaks the compound; the constituent `monthly` is segment-saturated |
| `monthly investing` | #220 alt | Same compound-breakdown waste as above; `investing` is segment-saturated |
| `planner` (as bare token without `portfolio` prefix) | n/a | Reserved as part of the `portfolio planner` compound to anchor the actor-noun voice (Candidate B) |
| `analytics` | #220 v1, #245 A | Held for the PPO swap lane (#467 follow-up) — segment-saturated but Bogleheads/FIRE-adjacent; not the strongest v1.0 byte |

### Tokens deliberately kept across all three candidates

- `value cost averaging` — exact-intent term; segment-empty per #245
  case-insensitive scan across the 7-app peer description corpus;
  matches the `app/Sources/Backend/...` and `docs/app-tech-spec.md`
  product-claim language verbatim.
- `dollar cost averaging` — gateway-query capture (#240, #393);
  segment-empty in the same #245 scan; pairs with `value cost
  averaging` to share the `cost averaging` compound-tokenized signal
  across both phrases.
- `offline` — segment-empty per #245 across the 7-app peer set;
  aligns with `docs/legal/privacy-policy.md` data-not-collected
  posture (#353 / #354).
- `dividend` — Bogleheads/FIRE persona vocabulary (#240); adjacent to
  the holding-categorization seam in the binary.
- `etf` — same persona vocabulary cluster; 3-byte token that no
  reasonable substitute beats on signal-per-byte.

## Impact

- **Reclaims 4-15 bytes** vs the pre-lock candidate strings (4 bytes
  if comparing against #245 A/B `vca` redundancy; 15 bytes if
  comparing against #220 alt `vca calculator` redundancy). Those
  bytes purchase `dollar cost averaging` (22 bytes including its
  leading delimiter) — the highest-volume gateway query no prior
  Frank artifact captured.
- **Signal upgrade**, not signal-multiplication: Apple ranks one
  signal per unique indexed token, so re-allocating bytes from a
  subtitle-redundant `vca` to a corpus-new `dollar` is a strict
  +1 indexed-token gain.
- **Description-body coherence (#327).** Locking
  `dollar cost averaging` in the keyword field obligates the
  description body to use the term at least once for indexer
  coherence (Apple ranks description-body matches at lower weight
  but rewards corpus consistency). Coordinate the description-draft
  paragraph that introduces the DCA → VCA bridge with the #327
  scope-honesty block.
- **Localization (#324) downstream.** This lock is en-US only;
  en-GB / en-CA financial-terminology variance pass is queued as a
  follow-up. `dividend` and `etf` read identically; `analytics`
  (held in the PPO lane) may need locale variance.

## Implementation

The acceptance criterion calling for a literal
`app/AppStore/en-US/keywords.txt` is deferred until #220 (storefront
SoT) ships that directory structure. Until then, **this document is
the authoritative source of truth for the locked en-US keyword field
string**. App Store Connect submission paste-target is the literal
fenced block under [Decision](#decision) above.

When #220 lands the `app/AppStore/en-US/` tree, the submitter copies
the locked string from this doc into `keywords.txt` and amends the
storefront SoT issue with the cross-link back here.

## Acceptance criteria

- [x] Frank's byte-accounting matrix (A/B/C) committed to this doc
      with byte counts independently verified by Python
      `len(s.encode('utf-8'))`.
- [x] Candidate B locked as primary; C retained as PPO holdback.
- [ ] Saul reviews and confirms primary lock against #286 primacy
      axis (Frank flags as decoupled at the keyword-field layer —
      every candidate is multi-axis-tolerant — but Saul's market
      intel may rank B vs C differently).
- [ ] Reuben gate: confirm `dollar cost averaging` and
      `value cost averaging` are not registered USPTO trademarks
      (CFA Institute publishes about both; surface scan shows no
      registered marks — Reuben to verify before App Store
      submission).
- [ ] `app/AppStore/en-US/keywords.txt` filed when #220 storefront
      SoT lands the directory structure (deferred dependency).
- [ ] #245 marked as superseded for the keyword-field section
      (subtitle section already superseded by #418).
- [ ] #220 v1/alt keyword seeds retired in the next #220 iteration.
- [ ] #327 description-body draft uses `dollar cost averaging` once
      in the paragraph-1 or scope-honesty block.
- [ ] #324 localization picks the en-US lock as the next-locale
      seed.

## Honest evidence ceiling

1. Apple does **not** publish per-token keyword-field weight; the
   "subtitle-redundant tokens waste bytes" assertion is paraphrased
   from Apple's App Store Connect developer-doc keyword-best-practices
   page. The 1-for-1 byte-to-signal claim is heuristic, not measured.
2. iTunes Lookup, Search, and RSS APIs do not expose competitor
   keyword-field strings. The competitor footprint inference comes
   from description-body text (#245), which is a correlate of the
   hidden field, not a direct read.
3. `dollar cost averaging` query-volume is unmeasured for Investrum's
   geography mix; the term is segment-vocabulary per #240 but not
   Apple-Search-volume-verified.
4. PPO variant testing on keyword-field strings is post-launch only.
5. The "leading tokens weight slightly higher" claim is from Apple's
   developer-doc keyword-best-practices page; not byte-measurable.
6. Localization (#324) treats the keyword field as locale-specific —
   en-GB / en-CA may need different allocations once the en-US lock
   proves durable. This doc only locks en-US.

## Cross-references

- **Parent / supersedes:** #245 (general competitor-gap; keyword
  section superseded here; subtitle section superseded by #418).
- **Supersedes:** #220 (storefront SoT keyword v1/alt seeds — pre-
  lock; retire in next #220 iteration).
- **Locks against:** #418 subtitle lock (PR #418, merged) +
  [`docs/aso/subtitle-positioning.md`](subtitle-positioning.md).
- **Coheres with:** #327 (description body must use
  `dollar cost averaging` once for coherence) + #322 (trust-commitment
  block — keyword field is indexer-only, no claim conflict).
- **Cascades to:** #324 (en-GB / en-CA variance pass downstream) +
  #220 (storefront SoT next iteration).
- **Decoupled from:** #286 (primacy axis — every candidate is multi-
  axis-tolerant at the keyword layer).
- **Persona evidence:** #240 (Bogleheads / dividends / FIRE —
  `dividend`, `etf`, `long term` are persona-vocabulary tokens).
