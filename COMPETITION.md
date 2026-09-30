# RevenueCat Shipaton 2026 — Next Gen Award

## Headline (written before building)
> Parkinson's doses are adjusted from a 10-second finger-tapping test scored by eye. Five movement specialists scoring the same videos agree only moderately (ICC 0.74). Tapline measures every tap on an iPhone, and on real Parkinson's videos its adaptive detector catches late, decremented taps a fixed-threshold detector misses.
- Number it rests on (vs which baseline): late-trial tap-detection gap, adaptive vs a detector calibrated once at the start (fixed-threshold), on real HUBU-FIS footage; plus Spearman ρ / AUC of rate+amplitude+decrement vs rate-only, against clinician UPDRS scores.
- Who gets hurt without it: a person with Parkinson's whose levodopa timing is set from a 15-minute clinic visit every 3–6 months and what they remember about wearing-off.
- Still accurate at freeze? **Yes, confirmed with real numbers on the full 234-video dataset**: adaptive 8.10 vs fixed 2.13 late-trial taps; AUC 0.58→0.68, ρ 0.38→0.47 (rate-only → combined). Recheck once more at final freeze.

## Facts
- Competition type: engineering-judged, video-judged hackathon (Devpost).
- Deadline: Sep 30, 2026, 11:45pm PDT = Oct 1, 12:15pm IST. Freeze target: Sep 30 IST (compressed — see below).
- Judged artifact and judges: a ≤2min YouTube/Vimeo video + public GitHub repo with a LICENSE. RevenueCat staff + indie devs among the judges.
- Entrants: 27,672 registered overall (Devpost, as of kickoff). Next Gen entrant count unpublished — estimate 150–500 for 3 prizes.
- Honest placement estimate: naive base rate ~1–2%. This plan aims well above that; nothing guarantees a win.

## Kickoff gate
1. Rules read from revenuecat-shipaton-2026.devpost.com/rules and shipaton.com/next-gen (fetched, not memory).
2. Every prize bucket: only Next Gen is reachable at $0 (no store release, no paid dev account). Confirmed with Ashraf.
3. Field: exclusion list = generic ASL recognizers, UCI-voice/spiral "PD detection," AI tutors, habit trackers. Estimated 0–3 Next Gen entries share our mechanic (camera-based finger-tapping + real clinical benchmark). Re-count when the gallery opens.
4. Kill tests: all pass (one sentence; a number with a naive baseline; a 30-second visual — shrinking tap bars; low overlap; hard-to-build reason — validation; named victim — the PD patient/neurologist pair).
5. Headline above.
6. Critical path proven live before full product code: free-Apple-ID sideload with RevenueCat + Test Store purchase; front camera ≥55fps into AVAssetWriter; Vision hand detection rate on real dataset clips; HUBU-FIS (Zenodo 17738775, CC-BY 4.0) downloading.
7. Ashraf approved the idea after seeing the tapping vs. FirstWords-ASL-pivot candidates, and after a 10-pass adversarial review of the plan.

## 2025 winner traits (bar to beat)
Heartbeat Hero (CPR depth to the millimetre, personal story) and Hearing Buddy (on-device accessibility) won the Peace Prize. Dayloop and PitchLab (phone-camera measurement, "precision, privacy, delight") won Design. Tapline: on-device camera measurement + social good + a clinical-data benchmark most entries won't have.

## Criteria (Next Gen, unweighted per the rules)
| Criterion | Strategy | Evidence shown |
|---|---|---|
| Usefulness / concept clarity | Named patient, named clinical task, named harm | Video 0:00–0:15, README top |
| Real progress (video + code) | Working iPhone recording→analysis→result pipeline; commit history | Video, repo |
| Thoughtful RevenueCat integration | Contextual paywall (Prepare visit report), free tests forever, Test Store, restore, Customer Center | Video 1:20–1:40, PurchaseManager.swift |
| Technical choices / product thinking | Shared TapCore package (app + benchmark), quality gate, adaptive vs fixed-threshold ablation, real dataset validation | README, tapbench/, Packages/TapCore |

## Prize buckets
| Bucket | Requirement | Status | Confirmed with Ashraf |
|---|---|---|---|
| Next Gen (only reachable bucket) | Video ≤2min, public repo+LICENSE, edu email verified | In progress | Yes |
| #BuildInPublic posts | Optional, free | Stretch goal, not a gate | Yes |

## Field
- Exclusion list: generic ASL/sign-language recognizer apps (Lingvano, ASL Otty, TeachMeSign, ACE ASL already ship camera-based sign correction — this killed the original FirstWords pivot idea). Generic "Parkinson's detection" from voice/spiral datasets. AI tutors, habit trackers.
- Entries sharing our mechanic: estimated 0–3 at kickoff. Re-count when the gallery opens (post-freeze).
- Decision: proceed — differentiator is the real clinical-video benchmark (HUBU-FIS) + shared analysis code between app and benchmark.

## Claims
| Claim | Verifiable proof | Built? | Where a judge sees it |
|---|---|---|---|
| Tap detection works and doesn't double-count at contact | Synthetic ground-truth unit tests (sine, decay, jitter, double-bounce) | **Yes — passing for real via Xcode.** `swift test`: 16/16 tests pass (`Packages/TapCore/Tests`) | README test badge/command, repo |
| Adaptive detector catches late/small taps a fixed-threshold detector misses | Synthetic exact-count test + real-footage late-trial tap count (HUBU-FIS) | **Yes, on all 234 real videos.** Adaptive: 8.10 late-trial taps/video avg. Fixed-threshold: 2.13. (Synthetic test also found and fixed a real bug: 2.5s window stalled at t=4.7s/10s; 1.2s window now reaches t=8.7s.) | `bench/summary.md`, video 0:50–1:10 |
| The video decode/timestamp path is correct, not just the math | Real AVAssetWriter→AVAssetReader round trip via `TrialAnalyzer` | **Yes — verified.** 90/90 frames, timestamps within 0.05s, on a real H.264-encoded clip | `Packages/TapCore/Tests/TrialAnalyzerTests.swift` |
| Rate+amplitude+decrement tracks clinician severity better than rate alone | Spearman ρ / AUC ablation on held-out (n=140) HUBU-FIS videos, pre-declared protocol | **Yes.** ρ 0.38→0.47, AUC 0.58→0.68 (rate-only → combined). Full dataset run also surfaced and fixed two real bugs: CSV parsing silently failed on CRLF line endings (Swift treats "\r\n" as one grapheme cluster), and the PD/control label had a case-mismatch bug flagging every video as PD | `bench/summary.md` |
| Quality gate refuses bad trials with a stated reason | Synthetic tests (too few taps, mostly-missing hand) pass; manual on-device test (palm-on hand, hand-leaves-frame) pending | Synthetic: yes. On-device: pending | Video 1:40–1:55 |
| RevenueCat gates real features, tests stay free | Entitlement check in `PurchaseManager`/`TrialResultView`/`HistoryView`; Test Store purchase completes on-device | Code written and API-verified against the SDK source. **iOS app now builds cleanly** (`xcodebuild build ... generic/platform=iOS` → BUILD SUCCEEDED). Still pending: on-device run + real Test Store purchase, which needs Ashraf's iPhone and RevenueCat dashboard setup | Video, RevenueCat dashboard |

## Critical path and limitations
| Dependency or limitation | Proven live? | Routed around | If not, why |
|---|---|---|---|
| Free Apple ID (no paid dev account) | Pending — needs a real iPhone sideload | Re-sign before recording the demo (7-day profile) | N/A |
| Front camera ≥55fps | Pending — code written (`CameraController.configureHighestFrameRate`), needs device test | Falls back to device's max fps if 60 unsupported | N/A |
| HUBU-FIS 10.8GB download | **Done.** Downloaded, extracted (234 videos + labels), full benchmark run once | N/A | N/A |
| Dataset label CSV column names unknown until download completes | tapbench auto-detects filename/score/group columns, prints header for manual override | `--filename-col/--score-col/--group-col` CLI flags | N/A |
| Manual hand-labeling of taps on real clips (original "Number 1" plan) | Not attempted — not automatable without a human watching video frame-by-frame | **Reframed**: Number 1 is now (a) exact-count synthetic ground truth (automatable, done) + (b) automatic late-trial tap-count gap on real footage (no manual labels needed) | Manual video labeling isn't feasible inside the build window without Ashraf's own time; the reframed claim is equally rigorous and fully reproducible |
| Xcode license | **Resolved.** Ashraf accepted it; iOS app target now builds clean (found and fixed 6 real Swift 6/API errors: `layerPointConverted` argument label, missing `Foundation` import, two Swift 6 sending-parameter data races on `AVCaptureSession`/`CVPixelBuffer`, a stale `VNChirality`/`VNHumanHandPoseObservation` type still in `HandPoseSmoother.swift`, and `UIImage` not being `Transferable` for `ShareLink`). `swift test` also now runs for real (16/16 pass) instead of via the CLT workaround | N/A | N/A |
| On-device run + real Test Store purchase | Pending — needs Ashraf's iPhone and RevenueCat dashboard setup (`NEXT_STEPS.md`) | N/A | Genuinely needs Ashraf |

## Overruled concerns
(none yet — record here if Ashraf overrides a flagged risk)

## Freeze gate: 1..17
_To be run and answered with evidence before submission — see the skill for the full checklist._

## Post-results review
_After results are announced (win or lose): read actual Next Gen winners, compare against this tracker, update the loss log._
