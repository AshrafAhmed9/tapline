# Devpost submission draft (Next Gen Award)

Fill in the `[ ]` placeholders once the benchmark finishes and the video is recorded.
Keep the headline number in the first line — judges skim.

## Project name
Tapline

## Tagline (one line)
The finger-tapping test that decides Parkinson's medication, measured on your iPhone.

## Description

**On 234 real, clinician-scored Parkinson's and control videos, Tapline's adaptive
tap detector catches 8.1 taps on average in the last third of a trial — the part
where amplitude decrement actually shows up — versus 2.1 for a fixed-threshold
detector. Adding amplitude and decrement to tap rate improves separation of
Parkinson's from control from AUC 0.58 to 0.68 over rate alone.**

Neurologists track Parkinson's disease with a simple test: tap your thumb and index
finger together, as wide and as fast as you can, for 10 seconds. It's part of the
MDS-UPDRS exam, and it happens once every few months, scored by eye. Five movement
disorder specialists scoring the same recorded trials only agree moderately (ICC
0.74 — [VisionMD, npj Parkinson's Disease
2025](https://www.nature.com/articles/s41531-025-00876-6)). What matters clinically
isn't just tap speed — it's whether the taps get smaller as the trial goes on
(amplitude decrement), which a stopwatch or a screen-tapping app can't see. A camera
can.

Tapline runs that exact test on an iPhone camera, entirely on-device:
- Prop your phone up, tap for 10 seconds.
- Apple Vision tracks your thumb and index fingertip, frame by frame.
- Tapline measures tap count, rate, per-tap width, and how much the taps shrink by
  the end — the same signal a clinician watches for, quantified.
- A quality gate refuses a trial it can't measure reliably (hand out of frame, too
  much movement) instead of guessing.
- History links results to medication timing, so a patient can show a neurologist
  what a whole day — not a 15-minute visit — actually looks like.

**This isn't a novel signal.** [VisionMD](https://github.com/mdlab-org/VisionMD)
(open-source, desktop, clinician-facing) already computes it for researchers.
Tapline's contribution is putting it in the patient's pocket: on-device, repeatable
at home, and linked to dose timing — the part a clinic visit every few months
structurally can't do.

**We didn't just build it — we checked it.** `tapbench`, a small command-line tool
built on the exact same analysis code the app runs, evaluates Tapline against
[HUBU-FIS](https://zenodo.org/records/17738775), a public, clinician-scored dataset
of 234 real Parkinson's and control finger-tapping videos. The results (methodology
pre-declared before the full run) are in the repo at `bench/summary.md`.

**Not a medical device.** Tapline doesn't diagnose anything or output a clinical
score — it's a log to bring to a neurologist, not a verdict.

**RevenueCat:** tests are free, forever. Tapline Plus (monthly, annual with a 7-day
trial, or lifetime) unlocks full history and a one-tap visit report. The paywall
appears contextually — when you ask for the report, not as an upfront wall — and
every gated feature checks the RevenueCat entitlement live, never a local flag.

## What's next
[ Fill in post-submission: what you'd build with more time — patient-camera
Sign-off/ tremor detection, a companion Apple Watch app, or expanding the benchmark
to a second public dataset. ]

## Built with
Swift, SwiftUI, SwiftData, Apple Vision (`DetectHumanHandPoseRequest`), AVFoundation,
Swift Charts, RevenueCat (Test Store, RevenueCatUI), XcodeGen.

## Links
- GitHub: [ repo URL ]
- Demo video: [ YouTube/Vimeo URL, ≤2:00 ]
- Dataset: https://zenodo.org/records/17738775 (CC-BY 4.0)

## Submission checklist (Next Gen — no store listing needed)
- [ ] Text description (above, with real numbers filled in)
- [ ] Demo video, ≤2:00, public on YouTube/Vimeo
- [ ] Public GitHub repo with LICENSE (already present)
- [ ] 1024×1024 app icon (`Tapline/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`)
- [ ] Screenshot, 1179×2556, no device frame — capture the Result screen with the
      shrinking bars chart
- [ ] Devpost account has a verified student/academic email
- [ ] Submitted by 12:00 PDT Sep 30, 2026 (not 11:45pm — leave a buffer)
