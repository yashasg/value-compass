# DM-seeding outreach script — persona-fit funnel for #448 channel pivot

> Saul (Market Researcher) operational artifact for issue #458.
> Operationalizes the persona-fit funnel that `docs/aso/channel-feasibility.md`
> §"Persona-fit funnel — DM-seeding from organic engagement" (closed #448)
> defined and routed but did not script. Companion to the cold-start
> launch playbook (`docs/aso/cold-start-launch-playbook.md` Phase 1).
>
> This is a planning + compliance artifact. **No DM ships before
> Reuben sign-off** (recorded in §"Reuben compliance gate" below).
> Cohort manifest entries live operator-side only and never enter
> `app/` binary, backend persistence, or the public repo — see
> §"Cohort manifest schema" / §"Honest evidence ceilings" #6.

## Decision

When the persona-fit funnel opens its DM channel (after the 2-4 week
organic-engagement gate in `docs/aso/channel-feasibility.md`
§"Persona-fit funnel" step 1), every DM uses one of the four templates
below, sent through an account that satisfies the §"Pre-conditions
checklist," and tagged in the local cohort manifest at send time. The
abort thresholds in §"Abort criteria" hard-stop the funnel; a single
Reddit account warn or sub-ban halts the tactic and forces a fallback
to volume-funnel-only recruitment (#456 HN + r/SideProject + IH).

## Why this exists (root cause, not a defence)

`docs/aso/channel-feasibility.md` §"Persona-fit funnel" specifies a
four-step loop — organic engagement → surfaced pain → 1:1 DM with
TestFlight invite → cohort-tag — as the rules-compliant alternative
to the rules-banned public Reddit posts. **The doc never wrote the
DM.** An unscripted DM-seeder will improvise, an improvised DM is the
highest-variance failure mode for an indie launch (account warns, mod
removals, segment-pain backlash), and Reddit's User Agreement on
solicitation has a non-zero gray zone for 1:1 invites tied to a free
indie tool. The funnel cannot open until both gaps close: the script
artifact below + the companion Reuben compliance issue cross-linked
in §"Hand-offs."

## Pre-conditions checklist (sender side)

Every DM the sender drafts must satisfy **all** of the following
before the message ships. Failure on any single line aborts the send
and the recipient is left unaddressed; do not "send a slightly worse
DM to a slightly weaker recipient." The checklist is structural — it
is the only thing standing between the 1:1-surfaced-pain pattern and
the 9:1-rule-violating self-promo pattern that mods enforce.

- [ ] **Reddit account age ≥30 days.** Throwaway / freshly minted
      accounts are pattern-matched as spam by mods and recipients
      alike. Strict floor; no exceptions.
- [ ] **Non-zero karma in the target sub.** The sender has at least
      one non-promotional comment on the same sub in the prior 14
      days; ideally three. This satisfies the 9:1-rule convention
      Reddit mods enforce (`docs/aso/channel-feasibility.md`
      §"Honest evidence ceiling 1" routes the verbatim audit to
      Reuben).
- [ ] **≥3 substantive non-promotional comments in the target sub in
      the prior 2-4 weeks**, none of which mention Investrum, the
      TestFlight beta, or the sender's developer status. This is the
      `docs/aso/channel-feasibility.md` §"Persona-fit funnel" step 1
      gate.
- [ ] **Surfaced-pain comment ≤14 days old.** DMs sent in response
      to comment threads older than two weeks read as cold-message;
      the recipient has no recent context for the pain reference.
- [ ] **24-hour cooling-off** between the sender's last public reply
      in the target thread and the DM. Comment-then-immediate-DM
      reads as a pivot; the cool-off makes the DM read as
      "I thought about your comment overnight."
- [ ] **Reuben sign-off recorded.** §"Reuben compliance gate" below
      must show a recorded sign-off date; without it, no DM ships.
- [ ] **Sender's most recent action on the sub is not a removed
      comment / mod warning.** If a warn or removal lands during the
      organic-engagement window, the sender's account is no longer a
      valid DM-seed; rotate to the secondary persona-fit funnel
      (`persona-fit-fire-wednesday` per
      `docs/aso/channel-feasibility.md` §"Cohort tagging schema").
- [ ] **9:1-rule satisfied for the rolling 30-day window.** The
      sender has performed at least 9 non-promotional community
      actions (comments, helpful answers, link-free contributions)
      per 1 self-promotional action; the DM counts as a single
      self-promotional action. If the ratio dips below 9:1 *after*
      the DM, no further DMs ship from that account for at least 7
      days.

## Surfaced-pain detection patterns

Sender scans target-sub comment threads for verbatim or near-verbatim
matches of the following phrase patterns (derived from #253 RSS pulls
+ #277 fresh-2026-05 cycle competitor review mining). Each pattern
maps to a numbered DM template in §"DM templates"; a recipient whose
comment matches pattern P1 receives template T1, etc.

| ID | Pattern (verbatim and paraphrase variants) | Pain theme | Template |
|---|---|---|---|
| P1 | "lost my watchlist," "Stock Events broke and now I can't find," "the app forgot all my holdings" | Data hostage — competitor app loses or refuses to export user-entered data | T1 |
| P2 | "Mint shutdown left me," "Personal Capital used to," "Empower is way more cluttered than the old PC," "looking for an alternative to PC tracker" | Lost control — incumbent disappeared or changed beyond the user's tolerance | T2 |
| P3 | "wish I could just enter prices manually," "I don't want to link my brokerage," "tracking a spreadsheet of allocations is getting unwieldy," "anyone tracking VCA without an account?" | Forced-account / spreadsheet drift — user has explicit privacy-or-friction preference incompatible with brokerage-link trackers | T3 |
| P4 | "the IAP for portfolio count is silly," "free tier is too limited," "had to pay for [feature that should be free]," "$X/month just to track positions" | Hidden fees — user surfaced explicit dissatisfaction with the trial-to-paywall or feature-gated tier of a competitor | T4 |

The phrase-match list is **incomplete by design**. The 2-4 week
organic-engagement window is also a continuous-listening window;
sender adds new verbatim phrases to this table as they surface, and
new variants must be cross-checked against the §"Forbidden patterns"
list (no template extension that violates Apple 5.6.3 or the 9:1 rule
ever ships).

## DM templates

Each template is **≤120 words** including the opt-out line. Each
opens with explicit reference to the recipient's surfaced-pain
comment (the *recipient's* phrasing, lifted verbatim where possible
— "I noticed your comment about X"). Each names **exactly one**
Investrum capability that addresses the pain — never a feature
list, never plural value props. Each ends with the same opt-out
sentence and CPP-or-TestFlight URL placeholder. **The same opening
template is never sent twice; the recipient's surfaced phrasing is
the single point of variation** so that mass-copy detection on the
sub mod side does not pattern-match a template-bot.

The CPP URL placeholders (`{CPP_BOGLEHEADS_URL}`, `{CPP_DIVIDENDS_URL}`,
`{CPP_PRESS_URL}`) consume Frank's #390 variant naming — the DM is
the only surface they are shared on per
`docs/aso/channel-feasibility.md` §"#390 implications." For
recipients who do not match a CPP audience, fall back to the bare
TestFlight invite URL (`{TESTFLIGHT_URL}`) — never a CPP variant
that does not match the surfaced-pain channel.

### T1 — Data hostage (P1 match)

> Hi — I noticed your comment about `{verbatim phrase from
> recipient's comment, ≤16 words}`. I'm the indie developer of a
> small free iOS app called Investrum (no account, no tracking) that
> keeps every holding you enter on-device and exports it as plain
> JSON whenever you ask. Beta is open, free, no IAP. If that sounds
> useful, here's the TestFlight invite: `{CPP_BOGLEHEADS_URL or
> TESTFLIGHT_URL}`. No worries if not — reply "no thanks" and I
> won't message again.

### T2 — Lost control (P2 match)

> Hi — I saw your comment about `{verbatim phrase, ≤16 words}`. I'm
> building Investrum, a small free iOS app for folks who want a
> manual-entry portfolio tracker that doesn't link to a brokerage
> and doesn't depend on any server you can't see. It runs entirely
> on-device. Free beta, no account, no IAP. TestFlight invite if
> you'd like to try: `{CPP_DIVIDENDS_URL or TESTFLIGHT_URL}`. Reply
> "no thanks" and I won't message again.

### T3 — Forced-account / spreadsheet drift (P3 match)

> Hi — your comment about `{verbatim phrase, ≤16 words}` resonated.
> I'm the indie dev of Investrum, a free iOS app where you enter
> tickers and prices manually — no brokerage link, no signup, no
> account at all. Replaces the "VCA in a spreadsheet" workflow.
> Free, no IAP. Here's the TestFlight invite if you'd like a look:
> `{CPP_BOGLEHEADS_URL or TESTFLIGHT_URL}`. Reply "no thanks" if not
> — I won't message you again.

### T4 — Hidden fees (P4 match)

> Hi — saw your comment about `{verbatim phrase, ≤16 words}`. I'm
> the indie developer of Investrum, a free iOS portfolio tracker.
> No IAP, no paid tier, no upsell — every feature is free at v1.0
> and the App Privacy label is "Data Not Collected." If you'd like
> to try it: `{CPP_PRESS_URL or TESTFLIGHT_URL}`. Reply "no thanks"
> if not — I won't message again.

## Forbidden patterns

The following patterns are **never** in a DM that ships. Each is a
hard-no because it either violates Apple 5.6.3 (review
incentivization), the 9:1 rule (self-promo ratio), or the
positioning honesty rules baked into #322 / #353 / #418.

- **Review asks of any kind.** Not "leave a review," not "rate the
  app," not "tell others." Apple App Store Review Guideline §5.6.3
  is the bright line; the DM channel is the closest-to-the-line
  surface in the whole funnel and the rule is non-negotiable. Per
  `docs/aso/cold-start-launch-playbook.md` §"Phase 1 / Phase 2 Out
  of scope," reviews are recipient-initiated only.
- **Plural recipients per comment-thread.** One DM per surfaced-pain
  comment, full stop. Mass-DMing multiple users in the same thread
  is the spam-pattern Reddit mods can detect across modmail reports.
- **Comment-then-immediate-DM.** Minimum 24-hour cooling-off (per
  §"Pre-conditions checklist"). The DM must not read as a pivot
  from a public reply.
- **Links beyond TestFlight + (optionally) the repo URL.** No
  Medium posts, no IndieHackers stories, no YouTube. The DM is a
  TestFlight invite, not a content distribution surface.
- **"Join our community" / "spread the word" / "invite your
  friends" CTAs.** Multi-recipient framings violate the 1:1 ToS
  posture; the DM is recipient-only.
- **Promises of features not in the current v1.0 build (per
  `docs/aso/subtitle-positioning.md` §"Decision" + #241 monetization
  posture).** Only `Free` + `No IAP` + `Data Not Collected` +
  `No account` are defensible against the shipped binary. No
  "coming soon," no "we plan to add."
- **Positioning claims that contradict the #418 subtitle or the
  #322 commitments inventory.** The DM voice register must ladder
  to the storefront's locked
  `No Sign-Up · Free · VCA Calc` framing, not propose a parallel
  pitch.
- **Sender's developer status concealed.** Every DM discloses
  "indie developer" in the first sentence. The 1:1-after-surfaced-
  pain pattern's only defence against ToS-solicitation framing is
  full transparency about who the sender is; an undisclosed sender
  is structurally a spam DM no matter how thoughtful the body is.
- **Apology language ("sorry for the unsolicited DM," "I know this
  is unusual").** Apology framing pattern-matches to solicitation-
  awareness which mods read as a self-admission. The DM is
  not unsolicited (surfaced-pain reference) and the structural
  defence is the surfaced-pain reference itself, not the apology.
- **Variants that re-use a previous DM template body verbatim.**
  The recipient's surfaced phrasing in the first sentence is the
  single point of variation. Re-using the body sentence-for-
  sentence across multiple recipients is what mass-DM-bot
  detection flags.

## Reuben compliance gate

**No DM ships before Reuben sign-off is recorded here.** Reuben (or
the legal/compliance specialist) reviews this artifact against:

- Reddit User Agreement, esp. §"Conduct" / §"Content Policy"
  (https://redditinc.com/policies/user-agreement, fetched on
  Reuben's sign-off cycle).
- Reddit Self-Promotion guidelines / the 9:1 rule convention
  (https://support.reddit.com/hc/en-us/articles/360043071072).
- Reddit DM-specific rules surfaced in
  https://support.reddit.com/ at sign-off time (in case the
  product surfaces a "Chat" vs. "Message" distinction with
  different policies).
- Apple App Store Review Guideline §5.6.3 — no review
  incentivization, including indirect (the DM channel is the
  closest-to-the-line surface in the whole funnel).
- The third-party-services register at
  `docs/legal/third-party-services.md` (closed #294) — confirm the
  DM does not need to surface Massive's terms (the canonical
  surface is the in-binary API-key entry).

Sign-off is recorded as a row in this section with: Reuben issue
number (linked from §"Hand-offs"), sign-off date, evidence URL set
that Reuben cited, any required template edits that resulted from
the review.

| Reuben issue | Sign-off date | Evidence URLs cited | Required edits |
|---|---|---|---|
| _(pending — see §"Hand-offs")_ | _(blocked)_ | _(blocked)_ | _(blocked)_ |

Until this table has at least one signed row, the DM funnel is
**closed**. Sender does not send the first DM; abort and re-route
recruits to the volume funnel (#456 HN + r/SideProject + IH).

## Sniff-test (pre-sign-off, qualitative validation, n=5)

Before the Reuben gate clears, Saul sends the four template bodies
(template only, no real recipient names) to **five indie-app founder
contacts** (Twitter / IndieHackers peer set; non-Investrum-affiliated)
with the single question:

> "If you received one of these as a DM after I'd seen you complain
> about [pain theme], would you read it as spam or as a thoughtful
> invite?"

Outcome is recorded in this artifact as qualitative validation
(n=5, **explicitly non-statistical**); the goal is to surface
template-body issues a founder peer can flag that the Reuben gate
might not (tone, length, register).

Result table to be filled in pre-sign-off:

| Founder ID (hash) | Template reviewed | Read as | Suggested edit | Action taken |
|---|---|---|---|---|
| _(pending)_ | | | | |

If 3+ of the 5 founders read any one template as spam, that template
is rewritten before Reuben sees it. If 3+ founders read **all four**
as spam, the entire tactic is escalated to Danny for an abort/pivot
decision before the Reuben cycle runs.

## Pre-launch sample test (post-Reuben-gate)

Exactly **five DMs** ship in the first cohort. They go to the first
five surfaced-pain comments matched after Reuben sign-off, one per
template (or fewer templates if fewer than five pain themes surface
in the matching window — the test is template-coverage, not
template-saturation). Hard-abort on first warn (see §"Abort
criteria").

Outcome metric thresholds (H1 from issue #458):

- **≥30 % non-negative response rate** ⇒ H1 holds, scale to the
  full persona-fit funnel cohort.
- **15–30 %** ⇒ template edits required, second 5-DM batch sent
  post-edit before scaling.
- **<15 %** ⇒ H1 broken; halt the persona-fit funnel, recruit
  remaining cohort from the volume funnel only.

Sentiment classification rubric (single-rater Saul, **explicit
ceiling: not blinded, not multi-rater, single-pass coding** — see
§"Honest evidence ceilings" #4):

- **Positive:** recipient accepted invite, asked follow-up
  question, or replied with thanks.
- **Neutral:** recipient acknowledged but declined, replied with
  the canonical "no thanks," or did not reply within 7 days.
- **Negative:** recipient flagged the DM as spam, replied with
  hostility, reported to mods (where surfaceable), or otherwise
  signalled that the DM was read as solicitation.

Result table populated post-test:

| DM # | Surfaced pain (P1-P4) | Template | Response sentiment | Conversion (TestFlight Y/N) | Account warn / mod action observed | Notes |
|---|---|---|---|---|---|---|
| _(pending Reuben gate)_ | | | | | | |

## Cohort manifest schema

Per `docs/aso/channel-feasibility.md` §"Cohort tagging schema." Each
DM produces a manifest entry at **send time** (not at conversion);
the entry stays even if conversion = N so the manifest is the
complete sent-DM ledger, not just the conversion list. The
conversion column flips post-TestFlight-accept.

Schema (one row per sent DM, append-only):

| Column | Type | Notes |
|---|---|---|
| `sent_at` | ISO-8601 timestamp, sender-local | Send time, not draft time. |
| `recipient_handle_hash` | SHA-256(handle + per-cohort salt), hex-truncated to 16 chars | **Hashed, not stored in plaintext** — preserves the no-analytics / no-PII posture (#322 / #353). The plaintext handle is never stored in the manifest; the sender uses Reddit's own UI to track the conversation. |
| `surfaced_pain_pattern` | enum `P1`-`P4` | Per §"Surfaced-pain detection patterns." |
| `surfaced_pain_evidence_phrase` | string, ≤120 chars, **paraphrased not verbatim if the comment is identifiable** | The verbatim phrase used in the DM is the recipient's; recording it verbatim in the manifest with a hashed handle would allow re-identification by anyone who searches the sub. The paraphrase-if-identifiable rule mirrors the data-minimization posture in `docs/legal/data-retention.md`. |
| `template_variant` | enum `T1`-`T4` | Per §"DM templates." |
| `cohort_tag` | enum from `docs/aso/channel-feasibility.md` §"Cohort tagging schema" — `persona-fit-dm-bogleheads`, `persona-fit-dm-dividends`, `persona-fit-dm-personalfinance`, `persona-fit-fire-wednesday` | Drives the #347 channel-mix accuracy signal class. |
| `response_sentiment` | enum `positive` / `neutral` / `negative` / `pending` | Per the §"Pre-launch sample test" rubric. Updated by sender at most 7 days after send; if no response by then, lock to `neutral`. |
| `conversion_testflight_accepted` | enum `Y` / `N` / `pending` | Flips to `Y` only when TestFlight reports an install + first session; `N` after 14 days post-send with no accept. |
| `account_warn_observed` | enum `Y` / `N` | `Y` triggers §"Abort criteria." |
| `mod_action_observed` | enum `none` / `message_removed` / `sub_ban` / `account_warn` / `account_suspend` | Any value other than `none` triggers §"Abort criteria." |
| `notes` | string, optional | Free-form sender notes; no PII. |

Storage rules (operator-side only, **never enters the repo**):

- File path: `.squad/.scratch/dm-seeding-manifest.csv` (a path
  already covered by `.gitignore`; the `.squad/.scratch/` tree is
  the gitignored scratch surface — see §"Honest evidence ceilings"
  #6 for verification cadence).
- Format: CSV, append-only, sender-local. Not synced to any
  cloud backup that is not encrypted-at-rest.
- Retention: 30 days post public launch, then deleted. Parallels
  the retention schedule in `docs/legal/data-retention.md` for
  app-internal data (no operator-side retention beyond the
  attribution-analysis window).
- **Never committed to git, never uploaded to any backend, never
  embedded in `app/` binary.** This commitment mirrors the
  no-analytics / no-tracking posture (#322 commitment #2 and
  #353). If a manifest entry accidentally lands in `app/` or
  `backend/` code, the no-analytics-SDK posture takes a
  credibility hit — strict gitignore + naming convention is the
  structural guard.

## Abort criteria

The funnel **halts** on the first occurrence of any of the
following. There is no graded response; the threshold is binary on
purpose because mod tolerance is non-deterministic
(`docs/aso/channel-feasibility.md` §"Honest evidence ceiling 6") and
a graded threshold load-bearings on a signal that cannot be
calibrated pre-launch.

| Trigger | Action | Escalation |
|---|---|---|
| ≥1 Reddit account warn | Halt funnel | Notify Danny within 24h; cohort-tag remaining recruits as `volume-*` only |
| ≥1 sub ban or sub mute on the sender account | Halt funnel | Notify Danny within 24h; rotate sender account is **not** an acceptable continuation — the tactic itself failed, not the account |
| ≥1 mod-removed DM with public follow-up post by mod or recipient ("received DM spam from Investrum dev") | Halt funnel | Notify Danny within 6h (faster cadence — reputational signal); escalate to Reuben for Reddit-ToS revisit; consider public response per #312 / #277 cadence |
| ≥1 Reddit T&S notice (formal sender-account action by admins) | Halt funnel + indefinite pause | Escalate to Reuben + Danny within 6h; this is a step beyond mod-level — admin action signals the structural pattern was read as ToS-violating, not a one-mod judgement call |
| Sample-test response rate <15 % | Halt funnel | H1 falsified; escalate to Danny for fallback-to-volume-only decision |
| Three sample-test recipients flag the DM as spam | Halt funnel | Template rewrite + Reuben re-sign-off required before resuming; do **not** continue sending the same template against a different sub |

**Fallback path** when any abort condition fires: recruit remaining
cohort from `volume-hn` + `volume-reddit` + `volume-ih` per
`docs/aso/channel-feasibility.md` §"Volume funnel — HN Show HN +
r/SideProject + IndieHackers" (issue #456 owns the volume-funnel
launch copy). The cohort-size target in
`docs/aso/cold-start-launch-playbook.md` Phase 1 is unchanged; only
the funnel mix shifts.

## Hand-offs

| Owner | Responsibility | Filing |
|---|---|---|
| **Reuben** | Compliance gate — Reddit User Agreement + Reddit Self-Promotion + Apple §5.6.3 review of this artifact and the four template bodies. Sign-off recorded in §"Reuben compliance gate" before any DM ships. | Companion compliance issue cross-linked from #458 (`compliance(reddit-tos): review DM-seeding script against Reddit User Agreement + Apple 5.6.3 for #448 persona-fit funnel`). Filed by Saul; owned by Reuben once filed. |
| **Frank** | Template register coherence with `docs/aso/storefront-sot.md` once #220 lands. The DM's "what makes this different" capability claim per template must match the storefront's locked capability framing per pain theme; the #418 subtitle anchors the voice register. Also: confirm `{CPP_*_URL}` placeholders consume #390 CPP variant naming as expected. | Cross-link from #458 to #220 and #390; no separate Frank-side issue required (Frank's CPP filing #390 is the consumption surface for the URL placeholders). |
| **Danny** | Abort-criteria escalation. The §"Abort criteria" table escalates any binary trigger to Danny within 6-24h depending on severity. Danny owns the abort/pivot/continue decision; Saul executes. | No new issue; existing #378 / #420 lead-decisions are the escalation surface. |
| **Saul (me)** | Post-test cycle audit — once the sample 5 DMs ship, this artifact is updated with the §"Pre-launch sample test" result table populated, and the H1 outcome is logged. Continuously expand §"Surfaced-pain detection patterns" as new verbatim phrases surface during the 2-4-week organic-engagement window. | This issue (#458) is the closing artifact; follow-up cycles use new Saul filings. |

## Tie-back to Frank findings and adjacent issues

- **#312 (review-response templates):** The four DM templates map
  structurally to the four 1★/3★/5★ buckets — same pain-theme
  axis, different surface (DM is pre-install, the #312 / #277
  response template is post-install). The voice register ladder is
  the trust-cycle continuity #322 commits to: the DM is the *first*
  trust-cycle surface, the App Store review response is the
  *second*. The recipient who later leaves a public review hears
  the same voice from the developer.
- **#220 (storefront SoT):** The DM names exactly ONE capability
  per pain theme; that capability claim must match the storefront
  SoT field once Frank lands #220. Coherence sync is Frank's lane
  per §"Hand-offs."
- **#390 (CPP variants):** Bogleheads / dividends / press CPP
  variants per `docs/aso/channel-feasibility.md` §"#390 implications"
  are shared 1:1 in the DM via the `{CPP_*_URL}` placeholders, not
  embedded in public posts. Confirms the CPP fixed-cost vs.
  bare-TestFlight-invite cost-justification decision sits on the
  DM-distribution side, not the public-post side; Frank's lane.
- **#387 (Frame 3 privacy differentiator):** The "what makes this
  different" line in templates T1-T4 lifts directly from Frame 3's
  pull-tab convention per the Frank 2026-05-19 voice-consistency
  rule (`docs/aso/channel-feasibility.md` §"#286 (coherence) —
  unchanged" depends on this).
- **#312 / #277 (developer-response cycle):** When a DM recipient
  eventually leaves an App Store review post-launch, the response
  template register (#312 / #277) handles the response. Continuity
  of voice is the cycle, not the individual surface.
- **#347 (observable-signal taxonomy):** The cohort manifest's
  `persona-fit-dm-*` tags are an observable-signal class per the
  "channel-mix accuracy" signal introduced by closed #448 — cross-
  reference recorded in `docs/aso/channel-feasibility.md` §"#347
  (observable-signal taxonomy) — new signal class added."
- **#456 (HN + r/SideProject + IndieHackers launch copy):** Fallback
  path per §"Abort criteria." The two funnels are co-equal in the
  cold-start playbook Phase 1; if persona-fit aborts, volume-funnel
  absorbs the remaining cohort target. Cross-linked in
  §"Abort criteria."
- **#322 / #353 (trust-commitments / Data Not Collected positioning):**
  The DM's "no IAP, no paid tier, no upsell" + "App Privacy label is
  Data Not Collected" lines in T4 are the in-channel re-assertion
  of these commitments. The DM is operator-side proof that the
  Saul-lane is honoring #322 commitment #2 (no-analytics) and #353
  privacy-label positioning at the recruitment surface, not just on
  the storefront.

## Honest evidence ceilings

1. **Reddit User Agreement and Self-Promotion-guideline quotes are
   not auto-fetched in this artifact.** The verbatim-quote audit is
   the Reuben gate's responsibility per §"Reuben compliance gate."
   This mirrors `docs/aso/channel-feasibility.md` §"Honest evidence
   ceiling 1" for the same reason: subreddit-rules-quote audits and
   ToS-quote audits are Reuben's lane, not Saul's. The artifact
   structurally cannot ship a DM without that audit recorded.
2. **H1 response-rate threshold (>30 % non-negative) is segment-
   judgment.** No measured baseline for indie-iOS-app DM-seeding
   response rates exists in the public segment data. <15 % as
   "broken" is a structural floor (a tactic that talks to <1 in 6
   people is not a tactic) but the 15-30 % grey band is a
   subjective cut. Could be 10-25 % or 20-40 % in practice; H1 is
   falsifiable but the threshold is not load-bearing on a measured
   baseline.
3. **H2 (no-review-ask still produces voluntary reviews) inherits
   the followthrough caveat** from
   `docs/aso/cold-start-launch-playbook.md` §"Honest evidence
   ceiling 1" — 40 % review-followthrough is segment-conservative
   from Stock Events / Snowball trial-to-free models, could be
   10-60 % for the DM-seeded cohort specifically. Not load-bearing
   on the cohort-size math.
4. **Sample-test sentiment coding is single-rater (Saul), single-
   pass, not blinded.** This is a known qualitative-research
   ceiling and is recorded in §"Pre-launch sample test." A
   second-rater pass would raise the qualitative confidence but is
   out of scope at the n=5 sample size; the structural defence is
   that any single negative classification triggers §"Abort
   criteria" — the bar is low for halting, not for continuing.
5. **Surfaced-pain phrase-match list is incomplete.** Four pain
   themes × ~3 verbatim phrases each = 12 patterns at filing time.
   Continuous additions expected as the 2-4-week organic-engagement
   window surfaces new pain vocabulary. The structural guard is
   §"Forbidden patterns" — no new pattern ships without cross-check
   against the forbidden list.
6. **Cohort manifest is operator-side / local-only by commitment,
   not by code.** No in-binary mechanism enforces the gitignore +
   non-commit + non-upload posture. If the manifest accidentally
   lands in `app/`, `backend/`, or git history, the no-analytics-
   SDK posture (#322 / #353) takes a credibility hit. The
   structural guard is `.gitignore` coverage of `.squad/.scratch/`
   (verified in `.gitignore` line `.squad/.scratch/`, this cycle)
   and the naming-convention rule (`dm-seeding-manifest.csv` only
   under `.squad/.scratch/`). Verification cadence: pre-launch
   gitignore audit by Saul (this cycle) + Reuben's compliance-gate
   review of the storage rules in §"Cohort manifest schema."
7. **Mod-tolerance abort threshold (1 warn = halt) is strict.**
   Could be softened to 2-3 warns if the tactic proves reliably
   mod-tolerant over the first 5-DM cohort. The strict threshold
   is intentional pre-launch — a single warn invalidates the
   entire DM-funnel rules-compliance claim and the structural
   recovery cost (sender-account rotation is **not** acceptable
   per §"Abort criteria") makes "try again with a less-strict
   threshold" structurally unsound.
8. **CPP cost-justification is Frank's lane and not resolved here.**
   The `{CPP_*_URL}` placeholders assume the CPP variants from #390
   ship. If Frank decides CPP fixed cost is not justified in the
   DM-only distribution model, fall back to the bare TestFlight
   invite URL in every template. Templates remain ≤120 words either
   way.
9. **Apple §5.6.3 enforcement is Apple-side discretion.** The
   bright-line rule is "no review incentivization" — the DM is
   structurally compliant (no review-ask, no implicit review-ask)
   but Apple's monitoring of review-pattern correlation is
   non-deterministic. The structural guard is the §"Forbidden
   patterns" review-ask block + Reuben's §5.6.3 sign-off in
   §"Reuben compliance gate."

## Cross-links

- **#458** opportunity(launch-recruitment) — this issue, closing
  filing.
- **#448** (closed) — channel-feasibility brief that defined the
  persona-fit funnel and routed but did not script.
- **#456** opportunity(launch-copy) — HN + r/SideProject + IH
  launch-copy artifact; sibling artifact for the volume funnel.
- **#440** opportunity(seam-observability) — seam-axis observability
  decision that affects what capability T1-T4 can name once locked.
- **`docs/aso/channel-feasibility.md`** — source-of-truth for the
  funnel architecture; this artifact is the DM-side execution.
- **`docs/aso/cold-start-launch-playbook.md`** — Phase 1
  recruitment-surfaces row sources both this artifact and the
  volume-funnel artifact (#456).
- **`docs/aso/subtitle-positioning.md`** — voice-register anchor
  for templates T1-T4.
- **`docs/legal/third-party-services.md`** — Massive register;
  Reuben confirms the DM does not need a Massive-terms surface.
- **`docs/legal/data-retention.md`** — retention-schedule mirror
  for the §"Cohort manifest schema" 30-day rule.

---

— Saul, cycle 2026-05-15 #27. Operationalizes the persona-fit
funnel that closed #448 defined and routed but did not script.
Companion Reuben compliance issue cross-linked from #458.
