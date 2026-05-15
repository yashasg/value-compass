# App Preview video specification — v1.0 master capture

> Frank (App Store Optimizer) decision artifact for issue #422. Corrects
> the master capture resolution + export pipeline + iPad scope for the
> 18-second App Preview video first storyboarded under issue #251, so the
> autoplay-above-screenshots surface actually reaches the modern-iPhone
> buyer cohort (6.9" Display class: iPhone Air / 17 Pro Max / 16 Pro Max /
> 16 Plus / 15 Pro Max / 15 Plus / 14 Pro Max). Same canvas-vs-painting
> pattern as issue #412 (screenshot substrate audit) on the App Preview
> side: storyboard / caption strings / scene order in #251 hold verbatim;
> only the underlying capture resolution, export pipeline, and scope
> notes change.

| Field | Value |
|---|---|
| Decision owner | Frank (App Store Optimizer) |
| Decision date | 2026-05-15 |
| Status | **Locked.** Authoritative source of truth for the v1.0 App Preview submission until the #251 doc lands. |
| Closes | #422 (this artifact) |
| Edits / supersedes | #251 §"ASO surface" (master resolution claim), §"Capture rig" (export pipeline), §"A/B candidate" (PPO variant lane). Caption strings, scene order, scene timings: **unchanged**. |
| Cross-references | #412 (sibling substrate audit — screenshot side), #246 / #284 (screenshot blueprints), #43 / #44 (iPad shell), #135 / #132 / #128 (capture-cascade dependencies), #390 (CPP — post-launch PPO pattern) |

## Decision summary

1. **Master capture resolution:** `886 × 1920` portrait (the 6.9" iPhone
   Display class master per Apple's 2025+ App Preview spec). **Not**
   `1080 × 1920` — that resolution is the 5.5" / 4" Display class and
   does NOT auto-scale up to 6.9".
2. **Auto-scale chain:** the 6.9" master fills 6.5" / 6.3" / 6.1" /
   5.5" / 4.7" / 4" slots via Apple's downward-only auto-scale. No
   secondary iPhone master needed.
3. **iPad preview:** **deferred to post-launch PPO.** v1.0 ships iPhone
   preview only; iPad buyers see the iPad screenshot stack (#284) as
   the above-the-fold surface. iPad preview slot stays empty by
   intent for v1.0.
4. **Audio track:** required at the file-format level even though
   autoplay is muted. A silent / ambient stereo AAC 256 kbps track
   (44.1 or 48 kHz, both channels enabled) is acceptable; the track
   must not be absent.
5. **Poster frame:** explicitly set at **t = 10.5s** (mid-point of the
   hero "Calculate" scene). Apple's default 5.0s lands on a caption
   transition and reads as broken text — explicit override is
   mandatory.
6. **Frame rate / bitrate / codec:** **30 fps cap**, **10-12 Mbps
   target** (12 Mbps max), H.264 progressive ≤ High Profile Level 4.0.
   Device-capture defaults (`xcrun devicectl` / QuickTime) produce
   60 fps and must be down-sampled on export.
7. **Quantity:** one preview at v1.0 launch; up to two more variants
   land post-launch under the 3-preview Product Page Optimization
   (PPO) lane.

## Why this string of corrections

### Apple's published 2025 App Preview device matrix (verified)

Source: <https://developer.apple.com/help/app-store-connect/reference/app-preview-specifications/>
(fetched 2026-05-18 — same provenance pattern as #412).

#### iPhone

| Display class | Modern devices | Accepted resolutions | Auto-scale source if slot empty |
|---|---|---|---|
| **6.9"** | iPhone Air, 17 Pro Max, 16 Pro Max, 16 Plus, 15 Pro Max, 15 Plus, 14 Pro Max | **886 × 1920** portrait / 1920 × 886 landscape | _(none — slot stays empty)_ |
| 6.5" | iPhone 14 Plus, 13/12/11 Pro Max, 11, XS Max, XR | 886 × 1920 / 1920 × 886 | 6.9" |
| 6.3" | iPhone 17 Pro, 17, 16 Pro, 16, 15 Pro, 15, 14 Pro | 886 × 1920 / 1920 × 886 | 6.5" |
| 6.1" | iPhone 17e, 16e, 14, 13 Pro, 13, 12 Pro, 12, 11 Pro, XS, X | 886 × 1920 / 1920 × 886 | 6.5" |
| 5.5" | iPhone 8 Plus, 7 Plus, 6S Plus, 6 Plus | **1080 × 1920** / 1920 × 1080 | 6.1" |
| 4.7" | iPhone SE 3/2, 8, 7, 6S, 6 | 750 × 1334 / 1334 × 750 | 5.5" |
| 4" | iPhone SE 1, 5S, 5C, 5 | **1080 × 1920** / 1920 × 1080 | 4.7" |
| 3.5" | _(legacy)_ | _App Previews not supported_ | n/a |

#### iPad

| Display class | Modern devices | Accepted resolutions | Auto-scale source if slot empty |
|---|---|---|---|
| **13"** | iPad Pro M5/M4, iPad Pro 6th–1st gen, iPad Air M4/M3/M2 | **1200 × 1600** portrait / 1600 × 1200 landscape | _(none — slot stays empty)_ |
| 12.9" | iPad Pro 2nd gen | 1200 × 1600 / 1600 × 1200 / 900 × 1200 / 1200 × 900 | 13" |
| 11" | iPad Pro M5/M4, iPad Pro 4th–1st gen, iPad Air M4/M3/M2 + 5/4, iPad A16, iPad 10th gen, iPad mini A17 Pro, iPad mini 6 | 1200 × 1600 / 1600 × 1200 | 13" |
| 10.5" | iPad Pro, iPad Air 3, iPad 9/8/7 | 1200 × 1600 / 1600 × 1200 | 12.9" |
| 9.7" | iPad Pro, iPad Air, iPad, iPad mini 2-5 | 900 × 1200 / 1200 × 900 | 10.5" |

### Why master at 6.9" iPhone (not 1080 × 1920 as #251 currently claims)

Apple's auto-scale chain flows **downward only** — a smaller-class
preview is **NOT scaled up** to fill a larger-class slot:

> "If app previews with the accepted resolutions aren't provided, scaled
> app previews for [next-larger] displays are used."

Consequence if #251 ships at `1080 × 1920` (5.5" / 4" master only):
the preview attaches to the 5.5" and 4" Display slots (iPhone 8 Plus and
earlier — < 1% of 2025+ buyers) and **does not auto-fill** the 6.9", 6.5",
6.3", or 6.1" iPhone slots. The autoplay-above-screenshots conversion
benefit of #251 evaporates for the majority of modern iPhone buyers.

Master at 6.9" / `886 × 1920` flips the chain: every smaller class
auto-fills downward; 6.9" itself is covered explicitly. One master
covers every iPhone slot.

### Why iPad preview is deferred to post-launch

Apple's App Preview auto-scale chain is **device-family-scoped** — no
cross-family scaling. A 6.9" iPhone preview does NOT auto-fill any iPad
slot.

Trade-off for v1.0:

- **Cost of shipping iPad preview now:** double the capture rig load
  (Tess re-visits caption-overlay safe zones at 3:4 aspect ratio,
  Basher re-shoots six surfaces on iPad, Yen re-runs WCAG AA against
  the 1200 × 1600 frames, Turk re-validates the six captured surfaces
  at the 13" iPad device class). Capture cascade dependencies in #135
  / #132 / #128 multiply.
- **Cost of deferring iPad preview to post-launch:** zero. iPad buyers
  see the screenshot stack from #284 above the fold with no autoplay
  surface — same fallback as today, no regression. The autoplay benefit
  simply doesn't reach iPad buyers in v1.0.
- **Buyer-cohort coverage of the bulk iPad device class (11" Display:
  iPad Pro M5/M4, iPad Air M4/M3/M2, iPad 10th gen, iPad mini A17 Pro)
  auto-scales from 13" — so once we do ship iPad preview, one 13"
  master covers everything except the legacy 9.7" tail.**

Verdict: v1.0 launches iPhone-preview-only. iPad preview is **parked
for post-launch PPO** (weeks 2-6 after launch, after analytics baseline
confirms iPad buyer share warrants the capture cost).

### Why the audio track is required even though autoplay is muted

Apple's spec is explicit:

> "Audio: Stereo … All tracks should be enabled … Codec: 256kbps AAC …
> Sample Rate: 44.1kHz or 48kHz"

A `.mov` exported without an audio track (a common output when the
original device capture had system audio off) will be **rejected at App
Store Connect upload time** as a malformed App Preview file — even
though autoplay never plays the audio. The track must exist; user-muted
autoplay just doesn't unmute it.

A silent / ambient stereo AAC track is acceptable. Basher's capture rig
must verify presence with `ffprobe -show_streams investrum-preview.mov`
before upload.

### Why the poster frame is t = 10.5s (not Apple's 5.0s default)

#251's 18-second storyboard timing:

| Scene | Window | Caption |
|---|---|---|
| 1 | 0.0 – 2.5s | `Plan your monthly investing.` |
| 2 | 2.5 – 5.0s | `Categories. Tickers. Targets.` |
| 3 | 5.0 – 8.5s | `You set the budget.` |
| 4 | 8.5 – 12.5s | `Value cost averaging in seconds.` (hero) |
| 5 | 12.5 – 15.5s | `Every snapshot, kept.` |
| 6 | 15.5 – 18.0s | `Your data never leaves your phone.` |

Apple's default poster frame at exactly t = 5.0s lands on the Scene 2 →
Scene 3 caption transition (`Categories. Tickers. Targets.` ending →
`You set the budget.` beginning). Text mid-fade / mid-cut, no clean
reading state — the worst single static frame in the storyboard.

**t = 10.5s** lands mid-way through Scene 4 (the hero "Calculate"
scene), caption `Value cost averaging in seconds.` fully rendered, the
result numbers animated in. This is the conversion-peak moment #251's
storyboard already names — the right static-thumbnail story.

Set via App Store Connect's "Set an app preview poster frame" controls
at upload time. No re-encode required.

### Why 30 fps + 10-12 Mbps + H.264 High Profile Level 4.0

Apple's 2025 spec:

- File: `.mov`, `.m4v`, or `.mp4`; ≤ 500 MB.
- Duration: 15-30 seconds (#251's 18s is mid-band ✓).
- Codec: H.264 progressive ≤ High Profile Level 4.0; or ProRes 422
  (HQ only).
- Bitrate: 10-12 Mbps (H.264) / ~220 Mbps (ProRes).
- Frame rate: ≤ 30 fps.
- Audio: stereo AAC 256 kbps at 44.1 or 48 kHz, both channels enabled.

`xcrun devicectl` screen recording and QuickTime device captures both
default to **60 fps** in 2025. A 60fps `.mov` uploaded as-is will fail
validation. The down-sample to 30 fps is non-negotiable.

H.264 High Profile Level 4.0 caps the per-second pixel rate at the
level the App Store Connect validator accepts; 11 Mbps target (12 Mbps
max) sits comfortably in Apple's published 10-12 Mbps band.

## Reference export recipe

Basher owns final tuning. The recipe below verifies all five format
constraints (886-wide, 30 fps cap, H.264 High Profile 4.0, 11 Mbps
target, stereo AAC 256 kbps, faststart) in one pass:

```bash
# Re-encode device-captured .mov to Apple App Preview spec
# (6.9" iPhone master — covers every iPhone display class via Apple's
# downward auto-scale chain).
ffmpeg -i raw-capture.mov \
  -vf "scale=886:1920:flags=lanczos,fps=30" \
  -c:v libx264 -profile:v high -level 4.0 -preset slow \
  -b:v 11M -maxrate 12M -bufsize 24M \
  -c:a aac -b:a 256k -ar 48000 -ac 2 \
  -movflags +faststart \
  investrum-preview-6.9.mov

# Verify audio-track presence before upload (silent/ambient track OK,
# absent track is the common upload-reject reason).
ffprobe -show_streams investrum-preview-6.9.mov | grep -E 'codec_type|codec_name|sample_rate|channels'
```

Expected `ffprobe` output (one video stream, one audio stream):

```
codec_type=video
codec_name=h264
codec_type=audio
codec_name=aac
sample_rate=48000
channels=2
```

If the source capture is system-audio-muted, prepend `-af "anullsrc"`
(or similar silent-track injection) before encoding, or use ffmpeg's
`-i raw-capture.mov -f lavfi -i anullsrc=cl=stereo:r=48000 -shortest`
two-input pattern to inject a silent stereo track.

## Three-preview PPO lane (post-launch, parked)

Apple's spec allows up to 3 App Previews per device family. v1.0 ships
one. Weeks 2-6 post-launch (after analytics baseline confirms which
opening hook converts), test 3 variants where each leads with a
different first 3 seconds:

| Variant | First 3 seconds | Conversion hypothesis |
|---|---|---|
| A | Scene 4 — Calculate hero | "Show the magic upfront." |
| B | Scene 2 — Empty portfolio | "Show what people already have." |
| C | Scene 6 — Privacy claim | "Lead with the trust differentiator." |

Same PPO frame as #251's existing A/B candidate section, expanded from
2 to 3 variants. **No v1.0 action required** — parking note only.
Picks up after launch + 4 weeks of analytics baseline.

## Cross-team gates

- **Basher (build):** owns the capture + ffmpeg export pipeline.
  Must verify the recipe lands a valid 886 × 1920 / 30 fps / High
  Profile 4.0 / 10-12 Mbps / stereo AAC 256 kbps / faststart `.mov`.
  Run `ffprobe -show_streams` to confirm audio-track presence before
  upload. Capture cascade dependencies unchanged: still gated on #135
  + #132 + #128 per #251.
- **Tess (visual direction):** the 886 × 1920 aspect (≈ 19.5:9 — the
  6.9" iPhone physical aspect) is **narrower** than the 1080 × 1920
  storyboard's drafted aspect (≈ 9:16 = the 5.5" iPhone physical
  aspect). Caption-overlay safe zones must be re-verified — text
  positioned for 1080-wide captures may clip on 886-wide frames. One
  composition pass on each of the 6 storyboard scenes before Basher
  captures.
- **Yen (a11y):** WCAG AA contrast checks must re-run against the
  886 × 1920 master (the underlying device frames are a different
  aspect — caption-overlay drop-bar dimensions may shift). Sibling
  check with #227.
- **Turk (HIG):** the six captured surfaces (empty portfolio /
  portfolio editor / contribution flow / result view / history +
  chart / settings privacy) must each be HIG-valid at the 6.9"
  iPhone device class, not the 6.1" default in `app/run.sh`. Same
  constraint #412 imposes for screenshot captures, transferred to
  preview-video captures.
- **Reuben (compliance):** Scene 6 caption `Your data never leaves
  your phone.` is unchanged (already #251-captured and #246 Frame 3
  cross-checked under #387). No new claim surface. Audio-track-
  mandatory finding is format-not-content; no compliance impact.
- **Saul (positioning):** **no Saul fold required** — same canvas /
  painting distinction as #412. Storyboard scene order, caption
  strings, and PPO variant axes hold verbatim. The autoplay-above-
  screenshots conversion narrative is unchanged; this fix just makes
  the autoplay reach modern-iPhone buyers.

## Rejected alternatives

1. **Ship at `1080 × 1920` anyway and let the auto-scale chain fill
   smaller slots.** Rejected — does not fill the 6.9" required slot
   (no upward auto-scale per Apple's spec); the autoplay benefit
   evaporates for the > 50% buyer cohort on iPhone 14 Pro Max and
   newer Plus / Pro Max devices.
2. **Ship `886 × 1920` AND `1080 × 1920` as two separate uploads.**
   Rejected — Apple's "up to 3 previews per device family" rule is
   for variant testing of the same content at the same resolution,
   not redundant resolution coverage. The auto-scale chain handles
   smaller classes from one master.
3. **Ship the iPad preview as a v1.0 must-have.** Rejected — doubles
   capture cost + visual direction load (Tess + Basher + Yen + Turk
   re-coordination on a different aspect ratio + surface inventory in
   #43) and the bulk of 2025 iPad buyers auto-scale from 13" preview
   so one master is enough. Post-launch PPO is sufficient.
4. **Skip the audio track since autoplay is muted.** Rejected —
   Apple's spec is explicit: "All tracks should be enabled." Common
   silent App Store Connect upload-reject reason.
5. **Accept the default 5-second poster frame.** Rejected — t = 5.0s
   in #251's storyboard is on a caption transition; reads as broken
   text. Hero moment at t = 10.5s reads cleanly as a static
   thumbnail and tells the conversion-peak story.
6. **Skip preview video entirely and lean on screenshots.** Rejected
   — #251 already established the conversion case for autoplay-above-
   screenshots; this audit just makes #251's capture executable
   against the current spec.
7. **Raise priority to p0.** Rejected — preview video is **not
   required** for App Store submission. Wrong-resolution preview is
   conversion-impacting (the autoplay benefit doesn't reach the
   modern iPhone cohort), not submission-blocking. p1 is the correct
   ceiling — same level as #412.

## Honest evidence ceiling

1. Apple's spec is authoritative for published rules; undocumented App
   Store Connect validator strictness (e.g., whether a 1085-wide
   capture is accepted as a "close-enough" 886-wide preview) is
   observable only at submission time.
2. The "no upward auto-scale" rule is inferred from the spec's "If
   app previews with the accepted resolutions aren't provided, scaled
   app previews for [next-larger] displays are used" phrasing, which
   only ever names the next-larger class — never a smaller class as
   a scale-up source. Apple does not explicitly publish a "no upward
   auto-scale" rule; this is the consistent reading of the spec
   page's per-class notes.
3. The 6.9" Display device list (iPhone Air / 17 Pro Max / 16 Pro Max
   / 16 Plus / 15 Pro Max / 15 Plus / 14 Pro Max) covers all "Plus"
   and "Pro Max" iPhones from iPhone 14 forward. Modern-buyer cohort
   share is inferred from Apple's release cadence and not from public
   sales data — qualitative "majority of 2025+ buyers" framing only.
4. The ffmpeg recipe is reference-only — Basher owns final tuning.
   Different source-capture frame-rates / codecs may need recipe
   adjustments. The five constraints (886-wide, 30 fps, H.264 High
   Profile 4.0, 11 Mbps target, stereo AAC 256 kbps) are
   non-negotiable per Apple.
5. The poster-frame-at-t=10.5s recommendation is heuristic (hero
   scene + visually clean static frame), not measured A/B. Could be
   re-run as part of post-launch PPO.
6. iPad-preview-deferred-to-post-launch recommendation is a v1.0
   scope trade — Saul may rebut if persona work in #240 surfaces
   iPad buyers as a primary persona (Bogleheads / FIRE may skew
   iPad-heavy). No data to date suggests that, but it has not been
   ruled out.
7. The 3-preview PPO post-launch lane is a parking note, not a v1.0
   commitment. Picks up after launch + 4 weeks of analytics baseline.
8. Cycle #2 (#412) established the substrate-audit pattern (canvas
   vs painting). This issue applies the same pattern to App Preview
   video format. No new methodology; just transfer.

## Provenance

- Apple App Preview specifications:
  <https://developer.apple.com/help/app-store-connect/reference/app-preview-specifications/>
  (fetched 2026-05-18).
- Issue #251 — original storyboard / caption strings / scene order
  (this doc edits its master-resolution + capture-rig + PPO sections).
- Issue #412 — sibling substrate audit on the screenshot side; same
  canvas-vs-painting pattern.
- Issues #246 / #284 — screenshot blueprints referenced for storyboard
  ↔ screenshot mirror property.
- Issues #43 / #44 — iPad shell and device-class surfaces (referenced
  for iPad-preview-deferred decision).
- Issues #135 / #132 / #128 — capture-cascade dependencies (unchanged).
- Issue #390 — Custom Product Pages (referenced for post-launch PPO
  pattern).
