# Tapline demo video — shot-by-shot production script

Target runtime: **1:50** (hard cap 2:00 — Devpost judges stop watching past it).
Every number below is already verified and sitting in `bench/summary.md` / `COMPETITION.md` — don't round up.

## Why you should record the voiceover yourself, not TTS

The whole submission's credibility rests on "a student built this because it's a
real problem," not "AI generated a hackathon project." A synthetic voice undercuts
that in the first three seconds. Your own voice, read a few times until it's smooth,
is free, sounds human because it is human, and matches the narrative. Judges have
heard a lot of TTS narration this cycle — a real voice stands out.

Recording setup (zero cost): iPhone Voice Memos in a quiet room, phone ~6 inches
from your mouth, off-axis (not directly in front) to reduce plosives. Read each
segment 3-4 times, pick the cleanest take per segment rather than trying one
perfect full read.

## Editing / captions (free tools)

- **CapCut** (iOS/Mac, free): auto-captions with word-level highlight, easy to trim
  screen recordings to exact timestamps below. This is the fastest path.
- Alternative: iMovie + YouTube's auto-caption editor (upload unlisted, download the
  auto-generated .srt, hand-correct against `captions.srt` in this folder, re-upload
  burned-in or as a caption track).
- Either way, **hand-correct the auto-captions** against the script below — auto-caption
  engines mangle "Tapline," "UPDRS," and the numbers.

## Screen recordings you need (record these raw clips first, narrate after)

1. **HUBU-FIS patient clip, hands only** — crop any dataset clip to hands-only framing (no face) in QuickTime/CapCut. Caption on screen: "Real patient footage — HUBU-FIS dataset, CC-BY 4.0" (bottom third, small, throughout this shot). This satisfies attribution for CC-BY reuse.
2. **Full live trial on your iPhone**: launch Tapline → countdown → camera view with the hand skeleton overlay visible and tapping clearly happening → result screen with the shrinking tap-amplitude bars. Record this in one continuous take if you can — a real unedited trial is more convincing than cuts.
3. **`bench/summary.md` or a simple bar chart** showing 8.10 vs 2.13 (screen record scrolling to it, or build a 2-bar chart image if you want it cleaner — Keynote/Numbers, export as PNG, 3 seconds is enough).
4. **History screen** with a couple of logged trials, ON/OFF tags visible.
5. **Tapping "Prepare visit report"** → the RevenueCat PaywallView appears → complete a **real Test Store purchase** on-device → report/PDF appears. This is the RevenueCat proof — don't skip or fake this step, it's a quarter of the judging criteria and judges can tell a mocked paywall.
6. **One refused trial**: cover the camera partway through a trial or move your hand out of frame, so the quality gate actually refuses it with its stated reason on screen.

## Script

### 0:00–0:14 — The problem (14s)
**Screen:** Clip 1 (patient hand, hands only, credited).
**VO:** "Parkinson's medication timing is set from a ten-second finger-tapping test — scored by eye, once every few months. Five movement specialists watching the same recording only agree with each other seventy-four percent of the time."
**On-screen text:** "ICC 0.74" fading in as you say the number.

### 0:14–0:48 — The product, live (34s)
**Screen:** Clip 2, full trial: countdown → skeleton overlay tapping → result screen with shrinking bars.
**VO:** "Tapline runs that exact test on an iPhone, entirely on-device. Prop your phone up, tap for ten seconds. Apple's Vision framework tracks your thumb and index finger, frame by frame — and Tapline measures what a clinician actually watches for: how many taps, how fast, and how much smaller they get by the end."
**On-screen text:** "Rate · Amplitude · Decrement" then "100% on-device — nothing uploaded."

### 0:48–1:10 — The proof (22s)
**Screen:** Clip 3, the 8.10 vs 2.13 chart/summary.
**VO:** "We didn't just build it — we checked it, on two hundred thirty-four real, clinician-scored patient videos. In the part of the trial that matters most — where taps start shrinking — our adaptive detector catches eight taps on average. A fixed threshold, the obvious approach, catches two."
**On-screen text:** "8.10 vs 2.13 taps/trial — real patient footage, not synthetic."

### 1:10–1:35 — RevenueCat (25s)
**Screen:** Clip 4 (history/ON-OFF) → Clip 5 (paywall → real Test Store purchase → report).
**VO:** "Adding amplitude and decrement to tap rate alone improves how well the score tracks the clinician's — from an AUC of point five eight to point six eight. This is Tapline Plus: a one-tap visit report, and history that shows a neurologist what a whole day looks like, not fifteen minutes. Tests stay free, forever — this is what's actually gated."
**On-screen text:** "RevenueCat Test Store — real purchase" then "Tests always free. Reports are Plus."

### 1:35–1:50 — The honest limit, close (15s)
**Screen:** Clip 6, refused trial with its stated reason visible.
**VO:** "And when Tapline can't measure reliably, it says so — instead of guessing. Not a diagnosis. On-device. Open source."
**On-screen text (end card):** "Tapline — github.com/<your-repo>"

## Checklist before you export
- [ ] Total runtime ≤ 1:55, ideally landing at 1:50 like the script
- [ ] Every number spoken matches `bench/summary.md` exactly (8.10, 2.13, 0.58, 0.68, 0.74)
- [ ] Captions burned in or attached, hand-corrected against this script
- [ ] HUBU-FIS clip is hands-only, no patient face, with the CC-BY credit line visible
- [ ] The RevenueCat purchase in the video is a real Test Store transaction, not a mock
- [ ] Uploaded to YouTube or Vimeo as public/unlisted, link works in a private tab
