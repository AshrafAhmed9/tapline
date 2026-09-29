# Tapline

**Parkinson's doses get adjusted from a 10-second finger-tapping test that a neurologist scores by eye, once every few months. Five movement specialists scoring the same recorded trials only agree moderately (ICC 0.74, [VisionMD, npj Parkinson's Disease 2025](https://www.nature.com/articles/s41531-025-00876-6)). Tapline runs that same test on an iPhone camera and measures every tap: how many, how wide, and how much they shrink by the end.**

Built for the [RevenueCat Shipaton 2026](https://revenuecat-shipaton-2026.devpost.com/) — Next Gen Award.

<!-- TODO before submission: screenshot / GIF of the result screen (shrinking tap bars) -->

## Why this exists

The clinical task (MDS-UPDRS item 3.4) is: tap your thumb and index finger together, as wide and as fast as you can, for 10 seconds. What matters clinically isn't just speed — it's **amplitude decrement**: whether the taps get smaller as the trial goes on. That's the actual sign of bradykinesia. A stopwatch, or a screen-tapping app that only measures rate (à la mPower), can't see it. A camera can.

This isn't a novel signal — [VisionMD](https://github.com/mdlab-org/VisionMD) (open-source, MediaPipe-based, desktop, clinician-facing) already computes it for researchers. Tapline's contribution is putting the same measurement **in the patient's pocket**, running fully on-device, repeatable at home, and linked to medication timing — the thing a clinic visit every few months structurally can't do.

**Not a medical device.** Tapline doesn't diagnose anything or output a clinical score. It's a log to bring to a neurologist, not a verdict.

## How it works

1. **Record** — 10 seconds of front-camera video at the highest frame rate the device supports (≥60fps where available), written directly to disk.
2. **Analyze** — read every frame back with Apple Vision's hand-pose detector (no dropped frames, no live-preview smoothing) and track the thumb tip and index tip.
3. **Signal** — thumb–index distance, normalized by the trial's own median hand scale (wrist→middle-MCP), so hand rotation toward/away from the camera doesn't fake a decrement.
4. **Detect** — a hysteresis tap detector with thresholds that adapt to a trailing window of the signal, so it keeps tracking taps even as they shrink. (See "The ablation" below for why this matters.)
5. **Measure** — tap count, rate, per-tap amplitude, amplitude decrement (last 3 taps vs. first 3), hesitations, rhythm variability.
6. **Gate** — a trial with too much missing hand data, too much hand-scale drift, or too few taps is **refused with a stated reason**, never silently scored.

All of the above (steps 2–6) lives in `Packages/TapCore`, a plain Swift package with no UI and no camera code — the same package the iPhone app and the `tapbench` command-line benchmark both call. There's one analysis path, not a demo path and a real path.

## The ablation: why adaptive thresholds matter

A detector that calibrates its open/closed thresholds once, from the first couple of seconds of a trial, works fine while taps are still large — and then misses the smaller, decremented taps later in the trial, which is exactly the clinically important part. Tapline's detector recomputes its thresholds from a trailing window instead.

```
packages/TapCore/Tests/TapCoreTests/TapMetricsTests.swift
  fixedCalibratedDetectorMissesLateSmallTaps()
```

This is checked two ways:
- **Synthetic, exact ground truth** (unit-tested, `swift test`): a signal with a known, constructed amplitude decay, where the true tap count and timing are known by construction.
- **Real footage** (`tapbench`, below): on real Parkinson's patient videos, how many taps each strategy detects in the last third of the trial.

## Benchmark: run on real clinical video

[HUBU-FIS](https://zenodo.org/records/17738775) is a public, CC-BY 4.0 dataset of 234 finger-tapping videos of Parkinson's patients and controls, each scored by clinicians. `tapbench` (a macOS command-line target, also built from `TapCore`) runs Tapline's exact analysis pipeline over the dataset and reports:

- **Claim 1 (no labels needed):** average taps detected in the last third of each trial, adaptive vs. fixed-calibrated.
- **Claim 2 (needs the dataset's label CSV):** Spearman ρ against the clinician score, and AUC separating PD from control, for a **rate-only** composite (what a screen-tapping app can measure) vs. **rate + amplitude + decrement** (what the camera adds) — reported on a held-out split under a protocol fixed before the full run (`bench/PROTOCOL.md`).

```bash
# 1. Download and unzip the dataset (10.8GB)
curl -L -o bench/dataset/HUBU-FIS_FT.zip \
  "https://zenodo.org/api/records/17738775/files/HUBU-FIS_FT.zip/content"
unzip bench/dataset/HUBU-FIS_FT.zip -d bench/dataset

# 2. Build and run the benchmark
xcodebuild -scheme tapbench -destination 'platform=macOS' build
.build/release/tapbench bench/dataset --labels bench/dataset/<labels>.csv --out bench
```

**Results: see `bench/summary.md`, generated by the command above.** <!-- TODO: run before submission and paste the headline numbers here -->

## RevenueCat

- **Tests are free, forever.** Nothing about running a trial or seeing today's result is gated.
- **Plus** (monthly, annual with a 7-day trial, or lifetime) unlocks full history beyond 14 days and the one-tap visit report for a neurologist appointment.
- The paywall (`RevenueCatUI.PaywallView`) appears contextually — when you tap "Prepare visit report" or try to see older history — not as an upfront wall.
- Every gated feature checks the `plus` entitlement live via `PurchaseManager`, never a local flag, so Restore Purchases and the Customer Center work correctly everywhere.
- Runs against a RevenueCat **Test Store** key by default — no App Store Connect or Google Play account needed to build and test this yourself.

## Running this yourself

```bash
brew install xcodegen   # if you don't have it
cp Config/Secrets.template.xcconfig Config/Secrets.xcconfig
# edit Config/Secrets.xcconfig — set REVENUECAT_API_KEY to a RevenueCat
# Test Store key (dashboard → Project → Apps & providers → Test Store)
xcodegen generate
open Tapline.xcodeproj
```

Run `TapCore`'s tests with no device needed:

```bash
cd Packages/TapCore && swift test
```

## Limits

- Not clinically validated prospectively — the benchmark is a retrospective check against public research footage, not a trial with our own device and our own recording conditions.
- Requires a side-on, steady hand in frame; the quality gate refuses trials that don't meet that (rather than silently scoring a bad trial).
- 60fps front-camera capture isn't available on every iPhone; Tapline falls back to the device's maximum and reports the real rate used.
- One hand at a time by design — a tapping trial only needs one.

## Project layout

```
Tapline/              iOS app: camera, recording, UI, SwiftData history, RevenueCat
Packages/TapCore/     Shared analysis engine (iOS + macOS): TrialAnalyzer, TapDetector,
                      TapMetrics, QualityGate — and its test suite
tapbench/             macOS CLI: runs TapCore over the HUBU-FIS dataset
bench/                Benchmark protocol, dataset (gitignored), and results
```
