# Tapline benchmark — HUBU-FIS

Generated 29/9/2026, 10:57 PM.

- Videos processed: 234
- Refused by the quality gate: 60 (25%)

## Claim 1 — late-trial taps caught, adaptive vs fixed-calibrated
On real footage, in the last third of each trial (where amplitude decrement is clinically the point):
- Adaptive detector: **8.10** taps/trial on average
- Fixed-calibrated detector: **2.13** taps/trial on average

(Exact-count validation of this mechanism against synthetic ground truth is in `Packages/TapCore/Tests`.)

## Claim 2 — clinical association (pre-declared protocol)
Dev split: 34 videos (seed 42) used only to fix composite weights. Reported below: the held-out 140.
- Rate-only vs clinician score: Spearman ρ = 0.38
- Rate + amplitude + decrement vs clinician score: Spearman ρ = 0.47
- Rate-only AUC (PD vs control): 0.58
- Rate + amplitude + decrement AUC (PD vs control): 0.68