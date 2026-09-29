# Benchmark protocol (fixed before the full run)

Written before `tapbench` is run on the complete HUBU-FIS dataset, so the
method can't be adjusted after seeing which version of it looks best.

## Dataset
[HUBU-FIS Finger Tapping dataset](https://zenodo.org/records/17738775), 234
videos of Parkinson's patients and controls performing the MDS-UPDRS
finger-tapping task, each labeled with a clinician UPDRS rating. CC-BY 4.0.

## Split
- Deterministic shuffle with a fixed seed (`--seed 42`, default in `tapbench`).
- **Dev split (20%)**: used only to sanity-check that the pipeline runs and
  produces sane-looking numbers. No metric weights are learned or tuned on
  it — the composite score's weights are fixed (equal-weighted z-scores),
  not fit to any split.
- **Held-out split (80%)**: reported once, in `bench/summary.md`. Results
  are published whatever they show.

## Claim 1 — late-trial detection gap (no labels needed)
For every video that passes the quality gate: count of taps detected in the
last third of the trial (by adaptive-threshold detection) vs. the same count
under a detector whose thresholds are calibrated once from the first 2
seconds. Reported as an average across all scored videos — this doesn't
depend on the label CSV at all, so it runs on every processable video.

## Claim 2 — clinical association (needs the label CSV)
Two composites, both **fixed, not learned**:
- **Rate-only**: tapping rate (taps/sec), negated (slower = more severe).
- **Combined**: equal-weighted sum of z-scored (rate, negated) and z-scored
  (mean amplitude adjusted for decrement, negated).

Reported on the held-out split only:
- Spearman ρ against the clinician's numeric score (if the label CSV has one).
- AUC separating PD from control (if the label CSV has a group/diagnosis
  column), via the Mann-Whitney U statistic.

## Refusals
Every video the quality gate refuses is counted and reported, with no
attempt to force a score out of a trial it flagged as unreliable.

## Quality gate calibration (done once, before the full run)
The gate's two data-quality thresholds (missing/low-confidence hand fraction,
and hand-scale drift toward/away from the camera) were written before any
real footage was seen, using round guesses. Run once against a random
20-video sample (seed 42, disjoint from nothing — this sample is not reused
in the reported split) to check they weren't simply wrong for
handheld/webcam recordings: the original thresholds (10% missing, 20% scale
drift) refused 50% of that sample, mostly on scale drift, which a clinical
home recording will naturally have more of than Tapline's own guided
in-app capture. Loosened once to 15% / 35%, dropping the sample's refusal
rate to 20% — still a real filter, not "accept everything." **These
thresholds are now fixed for the full run and for the shipped app; they are
not touched again after seeing the full-dataset correlation numbers.**

## Honest expected limitations (stated before running, not after)
- Camera framing, distance and lighting in HUBU-FIS almost certainly differ
  from Tapline's own guided setup, which may weaken correlations that would
  hold on Tapline's own recordings.
- HUBU-FIS's PD severity range may be narrow (mild-to-moderate), which
  compresses achievable correlation regardless of method quality.
- This is a retrospective benchmark on public research footage, not a
  prospective clinical validation.
