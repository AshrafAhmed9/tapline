# What's left (needs Ashraf)

Everything buildable without a device, a paid account, or a password is done and
committed. The iOS app now builds cleanly (`xcodebuild ... generic/platform=iOS` →
BUILD SUCCEEDED) and `swift test` passes 16/16 for real through Xcode. This is the
exact remaining checklist, in order.

## 1. Xcode build — done
License accepted, 6 real build errors found and fixed (Swift 6 concurrency, a
stale Vision type, a ShareLink/Transferable gap). App compiles clean.

## 2. RevenueCat dashboard (10 minutes, do this yourself — no API access from here)
1. Create a RevenueCat account/project if you don't have one.
2. Project → Apps & providers → add **Test Store**. Copy its API key (starts `test_`).
3. Paste it into `Config/Secrets.xcconfig` (copy from `Config/Secrets.template.xcconfig` if that file doesn't exist yet):
   ```
   REVENUECAT_API_KEY = test_...
   ```
4. Create an entitlement called **`plus`**.
5. Create an Offering with three packages attached to Test Store products:
   monthly, annual (with a 7-day free trial), and lifetime — all granting `plus`.
6. Create a default Paywall for that Offering (RevenueCat's paywall builder; the
   app just calls `PaywallView()`, which shows whatever's configured here).

## 3. Build and run on your iPhone
```
xcodegen generate
open Tapline.xcodeproj
```
- Plug in your iPhone, select it as the run destination, hit Run.
- First run: `Settings → Privacy & Security → Developer Mode → on`, then re-run.
- Free Apple ID provisioning profiles expire after 7 days — re-sign (just re-run
  from Xcode) right before recording the demo video.

## 4. Benchmark — done
The HUBU-FIS dataset (234 real videos) downloaded, extracted, and ran through
`tapbench`. Real numbers are in `bench/summary.md` and already filled into the
README, `COMPETITION.md`, and the Devpost draft: adaptive detector catches 8.10
late-trial taps/video vs 2.13 for a fixed-threshold baseline; adding
amplitude+decrement improves AUC (PD vs control) from 0.58 to 0.68 over rate alone.
Along the way this also found and fixed two real bugs (CSV parsing silently broke
on CRLF line endings; a case-mismatch flagged every video as Parkinson's) — see the
git log.

## 5. Record the demo video (this genuinely needs you — your hands, your phone)
Script (in `bench/DEVPOST_DRAFT.md` and the plan history): open on a real patient
clip from the dataset (credited, hands only), then a live trial on your iPhone
showing the shrinking-bars result, then the benchmark number (now real — see above),
then the paywall, then one refused trial as the honest limit. Hard cap 1:55.

## 6. Submit on Devpost
Draft text is in `bench/DEVPOST_DRAFT.md` (already has the real headline number) —
fill in the remaining links and screenshot, then submit by **12:00 PDT Sep 30**
(not 11:45pm — leave a buffer).
