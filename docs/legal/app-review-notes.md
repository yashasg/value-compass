# App Review submission notes — financial-tool classification

> ⚠️ **Draft, not legal advice.** This file is a pre-submission template. The
> exact wording that goes into App Store Connect's _Notes to Reviewer_ field
> must be reviewed and approved by qualified counsel before the first
> external submission. The content below is a starting point that locks the
> "analysis tool, not investment advice" classification into a single
> reviewable file (issue #254).

## Why this document exists

Apple App Review Guidelines §1.1.6 and §1.5.4 require financial apps to
accurately represent their functionality and not imply regulatory licensing
the developer does not hold. App Store Connect's _App Review Information →
Notes_ field is the designated channel for proactively explaining
non-advisory classification to a reviewer — without it, a reviewer
encountering screens like the Invest Action surface (per-ticker target
contribution amounts) may classify the app under a more restrictive
financial-services bucket and request regulatory documentation the team has
no obligation to maintain, extending the review cycle or triggering
rejection.

## How to use this document at submission time

1. Open App Store Connect → the app build → **App Review Information** →
   **Notes**.
2. Paste the [canonical Notes-to-Reviewer block](#canonical-notes-to-reviewer-block)
   verbatim. Adjust only the placeholders explicitly bracketed in
   `[SQUARE_BRACKETS]`.
3. Confirm the disclaimer surfaces listed in [What the app shows the
   user](#what-the-app-shows-the-user) still match the live build — they
   are what the reviewer will see in the simulator if they tap through.
4. Save the build for submission.

Repeat verbatim for every build that goes to external review until the file
itself is updated by a licensed counsel pass.

## Canonical Notes-to-Reviewer block

Paste this into the **App Review Information → Notes** field in App Store
Connect at submission time:

```
What this app is

Value Compass (Investrum) is a personal portfolio analysis tool. It helps
the user track their own existing holdings, define their own target
allocation across user-defined categories, and compute how much new money
the user could add per allocation to move toward their own target. All
calculations are run locally on the user's device against data the user
typed in themselves.

What this app is NOT

- It does not provide regulated investment advice, financial planning, or
  any kind of fiduciary service.
- It does not execute trades, route orders, or integrate with any
  brokerage, exchange, or other financial institution.
- It does not custody assets, manage accounts, or move money.
- It does not personalize recommendations based on the user's risk
  profile, financial situation, age, tax bracket, or any other regulated
  suitability criterion. The "target" the calculator works toward is the
  user's own self-declared target weight per category — the app never
  proposes what the target should be.

Data handling

- All portfolio data (holdings, categories, target weights, contribution
  history, calculation snapshots) is stored locally on the device using
  SwiftData. No portfolio data is transmitted to any server we control.
- The only optional network traffic is symbol-lookup / market-data
  requests routed through the Massive API using an API key that the user
  supplies in Settings. Symbols leave the device only after the user
  enters an API key and only as ticker strings — never as portfolio
  weights, account values, or any personally identifying information
  beyond what the user has typed.
- Push notifications are NOT used in this build. The app does not request
  notification permission on first launch.

Disclaimers shown in-app

- First-launch onboarding presents an investment-advice disclaimer that
  must be acknowledged before the user can create their first portfolio.
- The disclaimer text reads: "This tool is for informational and
  educational purposes only. It does not constitute investment advice.
  Past price trends do not guarantee future performance. Consult a
  licensed financial advisor before making investment decisions."
- The disclaimer is re-accessible from the Settings surface at any time
  during normal app use.

Reviewer test account

- No account is required to evaluate the app. All functionality is
  exercisable on a fresh install with locally-typed sample data.
- Optional: to test market-data refresh, [REVIEWER_TEST_API_KEY] can be
  pasted into Settings → Massive API key. This is a test-tier key with a
  rate-limited quota.

Contact for review questions

- Primary: [SUBMITTER_NAME] <[SUBMITTER_EMAIL]>
- Backup:  [BACKUP_NAME]   <[BACKUP_EMAIL]>
```

Bracketed placeholders to replace at submission time:

| Placeholder              | What to fill in                                                                 |
|--------------------------|---------------------------------------------------------------------------------|
| `[REVIEWER_TEST_API_KEY]`| A throwaway Massive API key whose rate-limit budget is acceptable to burn on review traffic. Rotate after acceptance. |
| `[SUBMITTER_NAME]`       | The team member listed on the App Store Connect submission.                    |
| `[SUBMITTER_EMAIL]`      | Email at which the team can respond to reviewer questions within 24h.          |
| `[BACKUP_NAME]`          | A second team member available if the primary is unreachable.                  |
| `[BACKUP_EMAIL]`         | Backup contact email.                                                          |

## What the app shows the user

Before submitting, confirm these in-app surfaces still match what the Notes
block claims the reviewer will see:

- **Onboarding disclaimer gate** — `app/Sources/Features/OnboardingView.swift`
  via `OnboardingFeature.acknowledgeDisclaimerTapped` (the user cannot
  proceed to `startSetupTapped` until they tap the acknowledgement). Per
  `docs/app-tech-spec.md` §10 the disclaimer text is the same verbatim
  string used in the Notes block above.
- **Settings disclaimer re-access** — see `SettingsView` and
  `SettingsFeature`. The Notes block claims this is reachable "at any time
  during normal app use"; that must remain true at submission. Issue #233
  tracks persisting the disclaimer on calculation-output surfaces if/when
  that lands; if it does, this file's "Disclaimers shown in-app" section
  must mention the new surface too.
- **Onboarding does NOT request push permission** — per #305 / issue #233's
  intersection. The Notes block claims "the app does not request
  notification permission on first launch" — verify by running the app on
  a clean simulator and confirming no `UNUserNotificationCenter`
  permission alert appears.
- **No brokerage / order-routing screens exist** — search the
  `app/Sources/Features/` tree for any view that takes the user past a
  "buy"/"sell"/"order" affordance. There should be none. If a future
  feature adds one, this file's "What this app is NOT" claim is wrong and
  must be revised.

## Cross-references with other compliance issues

This file is the App-Store-facing version of disclosures that already exist
in the codebase, the privacy policy, and other compliance documents. Keep
them in sync at every submission:

- `docs/legal/encryption-compliance.md` — `ITSAppUsesNonExemptEncryption`
  declaration; reviewer may ask about encryption export classification.
- `docs/legal/privacy-manifest.md` — Apple privacy manifest (`PrivacyInfo.xcprivacy`)
  must match the "Data handling" section of the Notes block.
- `docs/legal/trademark-clearance.md` — trademark / freedom-to-operate
  posture for the `Investrum` word mark, `UnevenInvestrumGlyph` logo, and
  `VCA` trigram (issue #314). Until licensed counsel signs off on each
  search row and on the `VCA` trigram disposition, external TestFlight /
  App Store submission is gated.
- Issue #224 — privacy policy and in-app legal link for the Massive API
  network flow. The published privacy policy text must be consistent with
  the "Data handling" claims in the Notes block.
- Issue #233 — investment-advice disclaimer on calculation-output surface.
  If/when it lands, the "Disclaimers shown in-app" section above gets a new
  bullet.
- Issue #294 — Massive ToS & Privacy Policy surfaced at API key entry. If
  this lands, the "Data handling" section can reference it as additional
  user transparency.
- Issue #305 — onboarding APNs prompt removal. Already merged; the Notes
  block accurately claims no notification permission is requested on first
  launch.

## Legal review log

Each time a licensed attorney reviews the Notes-to-Reviewer block above,
append a row here so the team can audit which build went out with which
approved language. Do not submit a build whose language has not been
attorney-reviewed.

| Date       | Reviewer             | Build / SHA     | Notes |
|------------|----------------------|-----------------|-------|
| _(pending)_| _(licensed counsel)_ | _(first submission)_ | Initial review of the canonical block above. |
