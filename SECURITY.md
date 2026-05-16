# Security policy

> ⚠️ **Not legal advice.** This file is the engineering record of how Value
> Compass / Investrum receives, handles, and discloses vulnerability reports
> for the iOS app binary, the FastAPI backend, and the Massive credential
> flow. The safe-harbor language, the response-time commitments, and the
> disclosure-window number must be reviewed and approved by qualified
> counsel before they are relied upon by an external researcher (CFAA
> exposure is jurisdiction-sensitive). Until that review lands, treat
> every commitment in this file as a *good-faith starting point*, not a
> contractual obligation, and consult `docs/legal/app-review-notes.md`
> for the broader "not investment advice" classification posture.

## Reporting a vulnerability

The preferred intake channel is **GitHub's private vulnerability reporting**
on this repository:

1. Open <https://github.com/yashasg/value-compass/security/advisories/new>
   (also reachable from the repo's **Security** tab → **Report a
   vulnerability**).
2. Fill in the advisory form. GitHub keeps the report private to the
   maintainer team — it is not indexed, not searchable, and not visible
   in the public issue tracker.
3. We will acknowledge receipt within the [Response SLAs](#response-slas)
   below.

If GitHub's private reporting is unavailable to you (for example, your
employer prohibits creating a GitHub account, or the report contains
material a researcher prefers not to upload to GitHub), email
**security@valuecompass.app** as a fallback. Treat the email contents as
"to be PGP-encrypted once a published key is available" — until then,
keep the email body limited to a high-level vulnerability class plus a
request to switch to a private GitHub advisory for the proof-of-concept
exchange.

**Do not** file vulnerabilities as public GitHub issues, post them in
discussions, or DM maintainers on social media. Doing so converts a
private report into public disclosure and forfeits the coordinated
disclosure expectations set out below.

## Scope

### In scope

- **iOS app binary** distributed via the App Store under bundle ID
  `com.valuecompass.VCA` — the SwiftUI/SwiftData client under `app/`.
- **FastAPI backend** at the published production host
  (`https://api.valuecompass.app`, or whichever host the binary is
  pinned to at the time of report) — the Python service under `backend/`.
- **Massive API credential flow** — the in-app entry, in-memory handling,
  Keychain persistence, and outbound transmission of the user-supplied
  Massive API key (see `app/Sources/Backend/Networking/Massive*.swift` and
  the SettingsView consent surface; background is `docs/legal/third-party-services.md`
  and #294).
- **Device-identity flow** — generation and transmission of the
  `X-Device-UUID` header documented in `docs/legal/privacy-manifest.md`
  (issue #271 / closes #223).
- **Privacy-manifest declarations** — divergence between the declared
  `PrivacyInfo.xcprivacy` data surface and what the binary actually
  transmits (issue #357 / #369 lineage).
- **Backend persistence boundaries** — any flaw that lets a request
  authenticated with one `X-Device-UUID` read, modify, or delete rows
  scoped to a different `X-Device-UUID`.

### Out of scope

- **Third-party SaaS dependencies** — Cloudflare, Supabase, the VM host,
  Massive, Apple APNs, and any other processor registered in
  `docs/legal/processor-register.csv`. Report those vulnerabilities to
  the vendor directly using the vendor's published policy; we will
  coordinate downstream if the issue affects our integration.
- **Social engineering** of maintainers, contractors, or Apple/Google
  support staff.
- **Physical access** attacks against a researcher's own device.
- **Denial of service** that requires sustained traffic against the
  production backend; please describe the class theoretically rather
  than demonstrating it live.
- **Self-XSS or other findings that require the victim to paste
  attacker-supplied content** into their own client.
- **Vulnerabilities in dependencies** that have not been fixed upstream
  — please file with the upstream project first; we will track via
  Dependabot / SPM resolution.
- **Reports that depend on a jailbroken device, a rooted Android
  emulator, or a modified iOS Simulator**, unless the same primitive
  also reproduces on a stock device.

## Disclosure expectations

- **Coordinated disclosure window**: 90 days from acknowledgement, by
  default. The window can be shortened by mutual agreement once a fix
  ships, or extended (with researcher consent) if the fix requires
  upstream-vendor coordination. The 90-day default is informed by
  industry CVD norms (Google Project Zero, GitHub Security Lab) and is
  a starting point; specific reports may negotiate a different number.
- **Public credit**: opt-in. By default we will not name a reporter in
  release notes or advisories; if you want public credit, say so in
  your report and indicate the name / handle to use. We will not credit
  researchers who do not request it.
- **Monetary bounty**: not offered at v1.0. We may revisit this stance
  post-launch, but reports filed today carry no expectation of payment.
  We will offer a written thank-you and (with your consent) public
  credit; that is the extent of the v1 program.
- **Embargo coordination**: when a fix is in flight, we will share a
  draft advisory and timeline with the reporter before publication so
  the reporter can flag inaccuracies. We will not surprise reporters
  with a publication date.

## Response SLAs

These are calendar-week, business-day targets, not contractual
commitments. v1.0 is operated by a small maintainer team; we
under-promise rather than over-promise so that researchers know what
to expect when the team is on holiday.

| Stage | Target |
|---|---|
| Initial acknowledgement (the report has been seen by a human, not yet triaged) | **5 business days** from submission. |
| Triage decision (in scope / out of scope / needs more info, plus initial severity estimate) | **15 business days** from submission. |
| Fix or documented mitigation in a shipped build / deployed backend | **90 calendar days** from triage decision for in-scope reports. |
| Researcher status updates while a fix is in flight | At least every **30 calendar days** with no progress to report; sooner when a fix lands. |

If a target slips, we will tell the reporter why and propose a revised
target — silence is not an acceptable response and should be
escalated to **security@valuecompass.app** (or, once published,
the maintainer's GitHub Security Advisories contact).

## Safe harbor

We will not pursue legal action against, or report to law enforcement,
any researcher who acts in good faith within the scope above, including:

- **Testing only against the researcher's own account / device.** Do
  not test using accounts, devices, or `X-Device-UUID` values
  belonging to third parties. Create your own test installation.
- **Avoiding privacy violations, data destruction, and service
  degradation.** If your proof-of-concept would expose, exfiltrate,
  modify, or delete data belonging to a real user — stop and describe
  the class of vulnerability in the report instead of demonstrating
  it. We will reproduce against a test fixture once the report is
  triaged.
- **Stopping at the first indication of a successful exploit.** Do
  not continue probing once you have established that a primitive
  works; collect the minimum reproduction needed to communicate the
  flaw, and report it.
- **Not publicly disclosing details** before the coordinated
  disclosure window above has elapsed or we have mutually agreed to
  publish earlier.
- **Not violating any other law** in the course of research.

This safe-harbor commitment is intended to align with the spirit of
the [disclose.io Open Source Safe Harbor template](https://github.com/disclose/diodb)
(CC0). It binds the Value Compass / Investrum maintainer team — it
does **not** bind Apple, Google, Cloudflare, Supabase, Massive, or any
other third party in the request path. Research against those
services is governed by the vendor's own policy.

If your good-faith research nonetheless touches a vendor in a way
that the vendor's policy treats as out-of-bounds, contact us first;
we will work with the vendor as best we can but we cannot grant safe
harbor on a vendor's behalf.

> ⚠️ **Counsel review pending.** The safe-harbor wording above is a
> CFAA-aware *draft* and has not yet been reviewed by qualified
> counsel. Researchers should treat it as a good-faith intent
> statement, not a binding legal release, until this caveat is
> removed in a subsequent commit signed off by counsel.

## What happens after a report

1. **Acknowledge** the report (see SLAs above) and confirm we have
   reproduced the issue on a test fixture, or request the additional
   information needed to reproduce.
2. **Triage** the report against the [Scope](#scope) section and
   assign an initial severity estimate (informational / low / medium
   / high / critical). We use the same severity language GitHub
   Security Advisories uses, which maps cleanly to CVSS v3.1 base
   severity bands.
3. **Fix or mitigate** within the disclosure window. If the fix
   requires changes to a third party in the request path, we will
   coordinate with that party and update the reporter on the revised
   timeline.
4. **Publish a GitHub Security Advisory** for in-scope reports
   describing the affected component, severity, the fix commit /
   release, and (with consent) the reporter credit.
5. **Update post-mortem references** in `docs/legal/data-retention.md`
   or `docs/legal/data-subject-rights.md` if the vulnerability
   affected a documented data-flow boundary, so the engineering
   record stays consistent with the public advisory.

## What is *not* covered by this policy

- **Data-subject rights requests** (GDPR Arts. 15–22, CCPA §1798.100
  et seq.) — those are user-triggered, not researcher-triggered.
  Routes documented in `docs/legal/data-subject-rights.md` (see also
  #224, #329, #333, #374).
- **Data-breach notifications** (GDPR Art. 33/34, Cal. Civ. Code
  §1798.82) — the maintainer-side notification procedure is a
  separate document (issue #408). The CVD policy is the *intake*
  side; breach notification is the *outbound* side.
- **Bug bounty payouts** — explicitly declined at v1.0 (see
  [Disclosure expectations](#disclosure-expectations)).
- **Threat-model documentation** — out of scope here; see
  `docs/services-tech-spec.md` and `docs/db-tech-spec.md` for the
  authoritative system shape.

## References

- **EU Cyber Resilience Act (Regulation (EU) 2024/2847)** — Art. 13(8)
  + Annex I §2(2): manufacturers shall maintain a coordinated
  vulnerability disclosure policy and a vulnerability-reporting
  contact address (enforcement begins 11 Dec 2027). This file is the
  Art. 13(8) artifact for Value Compass / Investrum.
- **NIST SP 800-218 (SSDF) — practice RV.1.1**: "Have a Vulnerability
  Disclosure Policy and implement roles, responsibilities, and
  processes for receiving, analyzing, and responding to reports."
- **ISO/IEC 29147:2018** — Vulnerability Disclosure (process for
  receiving reports and publishing advisories).
- **ISO/IEC 30111:2019** — Vulnerability Handling Processes
  (internal-handling counterpart to 29147).
- **GDPR Art. 32(1)(d)** — controllers must implement "a process for
  regularly testing, assessing and evaluating the effectiveness of
  technical and organisational measures." This CVD policy is the
  Art. 32(1)(d) organizational measure for the project.
- **Apple App Review Guidelines §5.1.2(i)(iii)** — "adequate security
  measures" for apps that collect user data. The published CVD policy
  is evidence-quality input to the §5.1.2 adequacy claim (App Review
  Notes block, `docs/legal/app-review-notes.md` per #254).
- **CCPA §1798.150** — private right of action for breaches; the
  California Attorney General has cited published vulnerability
  disclosure policies as a component of "reasonable security
  procedures and practices."
- **GitHub Security Advisories** — private intake and advisory
  publication: <https://docs.github.com/en/code-security/security-advisories>.
- **disclose.io Open Source Safe Harbor template (CC0)** — source for
  the safe-harbor wording above: <https://github.com/disclose/diodb>.
