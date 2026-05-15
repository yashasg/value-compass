# Channel feasibility — invite-only TestFlight beta recruitment surfaces

> Saul (Market Researcher) decision artifact for issue #424. Resolves
> the channel-mix question that #263 §Caveat and #378 cold-start
> recruitment both deferred. This doc is the **operational
> prerequisite** to both: neither can proceed to TestFlight
> invite-recruitment until the channel mix is rules-compliant.
>
> Audits the public rules of every channel named in #263 / #378 /
> #390, then records the Hybrid (option c) decision so the recruitment
> plan is auditable. Companion to `docs/aso/cold-start-launch-playbook.md`
> (the playbook references this brief for channel-by-channel feasibility).

## Decision

**Option (c) Hybrid path.** Investrum runs two recruitment funnels in
parallel, tagged by source so post-launch analysis can separate the
signals:

1. **Persona-fit funnel (low volume, high fit)** — DM-seeded TestFlight
   invites off organic comment engagement on r/Bogleheads / r/dividends
   / r/personalfinance comment threads; one r/financialindependence
   Wednesday self-promotion thread; Bogleheads.org forum modmail
   petition. Feeds #263 channel-validation signal (user-control axis
   resonance with the named V1 ICP).
2. **Volume funnel (high volume, low fit)** — HN Show HN + r/SideProject
   posts; IndieHackers milestone story. Feeds #378 cold-start cohort
   (50–100 qualified users target); fits the no-signup, native-iOS,
   non-trivial profile cleanly.

Neither funnel posts publicly to r/Bogleheads, r/dividends,
r/personalfinance, r/investing, or r/Entrepreneur. Public posts to
those subs are operationally infeasible per the rule audit below.

Beta cohort tagging records the recruit source so post-launch ratings
analysis (#347 observable-signal taxonomy) can attribute reviews to
funnel.

## Why this exists

The recruitment plans in **#263** (channel-validation, 3-post strategy
on r/Bogleheads / r/dividends / r/FIRE) and **#378** (cold-start
cohort sourced from "r/Bogleheads / r/dividends / Personal Capital
refugees / IndieHackers / Show HN") and **#390** (3-variant Custom
Product Page targeting "r/Bogleheads / r/dividends / indie-app
press") share a common implicit assumption: a free indie iOS app can
post about itself on the named finance subreddits if it doesn't
monetize. **Three of those five subs include the phrase "even if not
monetized" verbatim in their self-promo bans**, directly invalidating
that carve-out. The iOS-app-discovery subs have separate material
restrictions (Saturday-only, games-only, paid-to-free-only) that
further narrow the rules-compliant launch surface.

Without a documented pivot, the existing plan would:

- Get every Reddit post auto-removed by mod tooling or human mod.
- Cost the team a throwaway account per attempt.
- Generate **no validation signal** (negative outcome: no feedback,
  no comments, removal log only).
- Risk a **permanent account ban on r/investing** if the dev account
  is identifiable (Rule 4 is bright-line, names "app" explicitly).

## Channel-feasibility matrix

Snapshot fetched from each sub's public `rules.json` / `wiki/rules.json`
endpoint on **2026-05-17**. Subscriber counts from `about.json` same
date. See §"Honest evidence ceilings" for re-verification cadence.

### Primary persona subreddits (US storefront, finance vertical)

| Channel | Subscribers | Outcome | Rule key |
|---|---:|---|---|
| r/Bogleheads | 841,688 | ❌ blanket self-promo ban (poster-made products) | rules.json#1 |
| r/dividends | 868,526 | ❌ explicit "even if not monetized" | rules.json#2 |
| r/personalfinance | 21,688,308 | ❌ explicit "even if not monetized" | rules.json#2 |
| r/investing | 3,360,953 | ❌ permanent ban, names "app" explicitly | rules.json#4 |
| r/financialindependence | 2,431,635 | ⚠️ Wednesday self-promo thread only + karma gate | wiki/rules |

Rule quotes (verbatim):

- **r/Bogleheads — Rule 1:** *"We don't allow promoting products/services
  or content made by the poster, or advertising anything monetized by
  the poster."* Clause (a) bans poster-made products with no monetization
  qualifier — a free indie iOS app is caught by clause (a).
- **r/dividends — Rule 2:** *"We do not allow: Promotion of web content,
  products, services, companies, or anything else owned by you (or
  anyone affiliated with you), **even if not monetized**. Offering
  referral, invite, or affiliate ..."*
- **r/personalfinance — Rule 2:** Identical "even if not monetized"
  wording to r/dividends.
- **r/investing — Rule 4:** *"**Violating this rule results in an
  automatic permanent ban.** Do not post your youtube, twitter, discord,
  **app**, tool, blog, referral code, event, survey, etc."*
- **r/financialindependence — Rule 3 (wiki):** *"... recommending any
  product or app you are involved with, ... or mention of any other
  product or article, **whether monetized or not**, that you have
  interest in seeing succeed."* Rules-compliant escape hatch: *"there
  is a weekly Self-Promotion thread posted every Wednesday."*
  Rule 1 adds a subreddit-karma posting gate (threshold not published).

### iOS-discovery subreddits

| Channel | Subscribers | Outcome | Rule key |
|---|---:|---|---|
| r/iOSProgramming | 195,463 | ⚠️ one Saturday/year per app | rules.json#7 |
| r/iOSApps | (niche) | ⚠️ 10pt local karma + 1/30 days | rules.json#1,3 |
| r/iosgaming | (irrelevant) | ❌ games only | rules.json#4 |
| r/AppHookup | (irrelevant) | ❌ paid→free deals only | rules.json#1 |

Rule quotes (verbatim):

- **r/iOSProgramming — Rule 7:** *"Only post your app on Saturday. You
  may post about **one app, once a year**. It does not have to be your
  first app."* Effective surface: one Saturday/year per app — one shot,
  not a recruitment channel.
- **r/iOSApps — Rule 1:** *"10pt LOCAL Karma Required. Comment in
  r/iOSApps to earn 10 karma first."* (Reddit-wide karma does not
  transfer.) **Rule 3:** *"Infrequent self-promotion is permitted;
  however, it is not permitted more than once per developer in 30
  days."* **Rule 6:** *"Generative AI apps and AI-wrapped apps are not
  allowed."* Investrum is not AI-positioned per #327 / #353 → not
  blocked.
- **r/iosgaming — Rule 4:** *"Self-promotion is only permitted for iOS
  **game apps**."* Investrum is not a game → categorically excluded.
- **r/AppHookup — Rule 1:** *"No apps that are always free or free
  most of the time."* Investrum is free-forever per #399 / #377 →
  categorically excluded.

### Off-persona promotion subreddits

| Channel | Subscribers | Outcome | Rule key |
|---|---:|---|---|
| r/Entrepreneur | 5,000,000+ | ❌ blanket promo ban (also off-persona) | rules.json#1 |
| r/startups | 1,700,000+ | ❌ blanket promo ban (also off-persona) | rules.json#2 |

Off-persona regardless of rules; included because #378 named
"IndieHackers / HackerNews" in the same breath and the rule audit
preempts scope creep into adjacent business subs.

### Rules-compliant alternate channels

| Channel | Outcome | Source |
|---|---|---|
| **r/SideProject** (715,752 subscribers) | ✅ permissive (sub purpose: indie-launch feedback) | about.json |
| **HN Show HN** (separate platform) | ✅ fits no-signup / native-iOS / non-trivial criteria | showhn.html |
| Bogleheads.org forum (NOT Reddit) | ⚠️ modmail-first; manual verification (Cloudflare-blocked) | not auto-fetched |
| IndieHackers Stories | ⚠️ rules not audited this cycle | follow-up |

Quotes / criteria (verbatim):

- **r/SideProject sidebar:** *"r/SideProject is a subreddit for sharing
  and receiving constructive feedback on side projects."* `rules.json`
  returned `count: 0` — no formal self-promo rule. Indie launches are
  the sub's stated purpose. *Caveat:* off-persona; acquires general
  indie-app audience, not the user-control-axis persona named in #240.
- **HN Show HN eligibility** (`https://news.ycombinator.com/showhn.html`,
  2026-05-17): *"Show HN is for something you've made that other people
  can play with. ... On topic: things people can run on their computers
  or hold in their hands. ... The project should be non-trivial. ...
  Please make it easy for users to try your thing out, ideally without
  barriers such as signups or emails."* Investrum (no-account,
  no-signup, no-tracking, free, native iOS) fits the profile cleanly.
- **Bogleheads.org forum**: distinct community from r/Bogleheads
  (different phpBB platform, different mods). Forum behind Cloudflare;
  rules not auto-fetched this cycle (`Just a moment...` interstitial).
  Modmail-first petition is non-deterministic mod-discretion.
- **IndieHackers Stories**: recommended self-promo surface is a
  "milestone" or "launch" story. Audit deferred to next cycle.

## Hybrid path mechanics

### Persona-fit funnel — DM-seeding from organic engagement

The Reddit ToS allows 1:1 private messaging; the line between
permitted DM and banned solicitation is **whether the recipient
surfaced relevant pain first**. The loop:

1. **Organic comment engagement** on r/Bogleheads / r/dividends /
   r/personalfinance — substantive, non-promotional contributions for
   2–4 weeks, no app mentions in public.
2. **Watch for surfaced pain** in those comment threads — users
   complaining about Stock Events bugs, asking "what do you use to
   track VCA?", venting about Mint shutdown / Personal Capital
   tracker-quality drift.
3. **DM the TestFlight invite 1:1** in response to surfaced pain.
   Single user, single ask, no public solicitation. Disclose: indie
   developer, beta, free, no-account.
4. **Tag the recruit as `persona-fit`** in the beta cohort manifest so
   post-launch attribution can compare to the volume funnel.

Expected cohort from this funnel: 15–30 users over 4 weeks. High fit,
low volume.

Rule-compliance escape hatches (additive, not primary):

- **r/financialindependence Wednesday Self-Promotion thread** — one
  Show HN-style post per cycle, framed as feedback request. Subject to
  karma gate (warm the account up before submission).
- **Bogleheads.org forum modmail** — petition for a one-off "indie
  tool feedback" thread. Mod discretion. Outcome unknown until tried.

### Volume funnel — HN Show HN + r/SideProject + IndieHackers

The realistic primary surface for #378's 50–100 cohort. Posting plan:

1. **HN Show HN post** on launch-window day with the locked subtitle
   (#399), the published Privacy Policy (#224), and the App Store
   Connect product page URL once the binary clears review. Landing
   page must satisfy Show HN's "easy to try out, no signups" criterion
   — Investrum already does. Tag recruits from this surface as
   `volume-hn`.
2. **r/SideProject post** same day, formatted as `[Investrum] - free,
   no-account VCA tracker for DIY investors`. Tag as `volume-reddit`.
3. **IndieHackers milestone story** within 7 days of launch — focused
   on the build-in-public arc (no-analytics, no-account architecture,
   App Privacy nutrition label). Tag as `volume-ih`.

Expected cohort from this funnel: 50–100+ achievable when one of the
three surfaces hits a feed peak. Lower persona-fit than the DM-seeded
recruits; offsets with raw volume.

### Cohort tagging schema

Beta-cohort manifest records source per recruit so day-30 success
criteria in `docs/aso/cold-start-launch-playbook.md` can attribute by
funnel:

| Tag | Source |
|---|---|
| `persona-fit-dm-bogleheads` | DM off r/Bogleheads comment thread |
| `persona-fit-dm-dividends` | DM off r/dividends comment thread |
| `persona-fit-dm-personalfinance` | DM off r/personalfinance comment thread |
| `persona-fit-fire-wednesday` | r/financialindependence Wednesday thread |
| `persona-fit-bogleheads-forum` | Bogleheads.org forum (if modmail approves) |
| `volume-hn` | Hacker News Show HN |
| `volume-reddit` | r/SideProject |
| `volume-ih` | IndieHackers Stories |

## Implications for adjacent issues

### #263 (channel-validation) — operational pivot recorded

The original "3-post strategy on r/Bogleheads / r/dividends / r/FIRE"
is **superseded**. The replacement is the Hybrid path above; the
r/financialindependence Wednesday-thread post is the one rules-compliant
Reddit surface in the persona-fit funnel. The §Caveat in #263 that
deferred legal/ToS to Reuben is addressed by the DM-seeding tactic
(within Reddit ToS for 1:1 messaging when the recipient surfaces pain
first).

### #378 (cold-start-path) — cohort source-mix rebalanced

Recommended source-mix for the 50–100 cohort target, replacing the
original "r/Bogleheads / r/dividends / Personal Capital refugees /
IndieHackers / Show HN" enumeration:

| Source class | Target share | Tag prefix |
|---|---:|---|
| HN Show HN + r/SideProject | 50–60 % | `volume-hn`, `volume-reddit` |
| IndieHackers Stories | 20–30 % | `volume-ih` |
| DM-seeded Bogleheads / dividends / personalfinance comment-thread refugees | 10–20 % | `persona-fit-dm-*` |

Re-baseline the 50–100 number against actual conversion rates from
indie-app launches on these surfaces. Pre-launch volume estimates
(rule-of-thumb Show HN front-page traffic) should not be load-bearing
in the cohort-size math; see §"Honest evidence ceilings" (e).

### #390 (Custom Product Pages) — variant naming preserved, distribution surface narrowed

Frank's 3-variant CPP spec named "r/Bogleheads / r/dividends / indie-app
press" as the three channel-tied CPP variants. The Bogleheads /
dividends variants are still meaningful targets — but the CPP URLs are
**shared 1:1 in DMs**, not embedded in public Reddit posts. CPP
attribution mechanics shift correspondingly: instead of post-click
attribution from a public link, attribution comes from DM-conversation
recipients clicking the unique CPP URL. Worth re-checking with Frank
whether the CPP fixed-cost is justified vs. simply distributing
TestFlight invite codes in DMs without the CPP variant. Cross-issue
hand-off recorded; CPP scope decision is Frank's lane.

### #240 (persona) — unchanged

The persona naming (Bogleheads / FIRE / dividends V1 ICP) is correct.
What's wrong is the **channel to reach the persona** — addressed here.
Saul-side persona work stands.

### #286 (coherence) — unchanged

Primacy decision (user-control axis answers competitor-pain themes) is
unchanged. What's affected is whether storefront copy gets validated
*with the target persona* pre-launch via Reddit posts (no) vs.
DM-seeded TestFlight (yes, slower).

### #347 (observable-signal taxonomy) — new signal class added

The cohort-tagging schema above introduces a new observable signal:
**channel-mix accuracy** — how many of the first-30-day reviewers came
from each funnel (`persona-fit-*` vs. `volume-*` tags). Lets the team
learn which channel actually converted post-launch. Add to #347's
taxonomy as a follow-up.

### #322 / #312 / #277 (trust-cycle surfaces) — unchanged

The indie-app / Show HN cold-start funnel benefits from #322
commitments and the #312 / #277 response cadences identically to the
Boglehead funnel. No change.

### #241 (monetization) — unchanged

Channel feasibility is upstream of pricing-stance discussion.

## Honest evidence ceilings

1. **Rule quotes are verbatim from public `rules.json` / `wiki/rules.json`
   endpoints fetched on 2026-05-17.** Subreddit rules can change;
   re-verify at launch-window minus 30 days. If a rule shifts to more
   permissive language, this brief is the audit baseline to compare
   against.
2. **Subscriber counts are from `about.json` fetched 2026-05-17.**
   Active-user counts were not exposed (`active_user_count: None`);
   engagement-rate inference would need a separate fetch and is not
   load-bearing in this brief.
3. **Bogleheads.org forum is behind Cloudflare** (`Just a moment...`
   interstitial); rules not auto-fetched this cycle. Manual
   verification needed before claiming it as a channel.
4. **The "Personal Capital refugees" cohort named in #378 is not a
   discrete subreddit** but a complaint pattern distributed across
   r/personalfinance + r/investing comment threads. The pivot to
   DM-seeding off comment threads is the rules-compliant path — but
   the cohort size achievable this way is empirically unknown.
5. **The "Show HN front-page drives 200–2,000 visitors / hour" range
   is industry rule-of-thumb for indie launches**, not a Show HN-
   specific stat fetched this cycle. Pre-launch volume estimates
   should not be load-bearing in the cohort-size math.
6. **Mod-discretion exceptions** (r/Bogleheads modmail, Bogleheads.org
   forum modmail) are non-deterministic. Plans should not be
   load-bearing on them.
7. **IndieHackers Stories rules were not audited this cycle** — flagged
   as a follow-up. The recommendation treats IH as `volume-ih` source
   class based on community norms (milestone / launch posts are
   standard practice), not a rule-by-rule audit.

## Out of scope (explicitly NOT in this brief)

- Storefront copy implications of the channel pivot — Frank's lane
  (#390 CPP variant rebalancing).
- Legal / Reddit-ToS interpretation of the DM-seeding tactic at scale
  — Reuben's lane (Rule-compliance comfort check; #263 §Caveat).
- TestFlight cohort-size math given specific Show HN / r/SideProject
  conversion rates — pre-launch unknowns; defer to post-#135 capture
  window.
- Bogleheads.org forum + IndieHackers rules audit — explicit follow-up
  next cycle.
- Influencer / paid acquisition — out of charter for an indie launch;
  #378 already excludes.

## Downstream owners

- **Danny** — scope decision: this brief recommends Hybrid (option c).
  Approve / amend before recruitment cohort fills.
- **Frank** — #390 CPP variant naming: confirm whether the
  Bogleheads / dividends CPP variants are justified once the
  distribution surface is DM-only (vs. public posts). Co-author
  launch-day HN Show HN + r/SideProject posts.
- **Reuben** — Reddit ToS comfort check on DM-seeding tactic. Verify
  the 1:1-after-surfaced-pain loop is within Reddit user agreement.
- **Saul (me)** — follow-up Bogleheads.org forum + IndieHackers rules
  audit next cycle. Monitor `persona-fit-*` vs. `volume-*` tag
  conversion rates post-launch (#347 signal class).

## Cross-links

- **#263** opportunity(channel-validation) — operational pivot recorded
- **#378** opportunity(cold-start-path) — cohort source-mix rebalanced
- **#240** opportunity(persona) — persona naming unchanged
- **#286** positioning(coherence) — primacy decision unchanged
- **#347** opportunity(measurement) — new signal class added
- **#390** aso(custom-product-pages) — CPP variant distribution narrowed
- **#241** opportunity(monetization) — unchanged (channel feasibility
  is upstream)
- `docs/aso/cold-start-launch-playbook.md` — Phase 1 recruitment-
  surfaces row sources from this brief

---

— Saul, cycle 2026-05-17. Resolves #424. Source-of-truth for
recruitment-channel feasibility; companion to the cold-start launch
playbook.
