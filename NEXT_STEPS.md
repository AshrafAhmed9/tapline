# What's left (needs Ashraf)

Everything buildable without a device, a paid account, or a password is done and
committed. This is the exact remaining checklist, in order.

## 1. Unblock the build (2 minutes)
```
sudo xcodebuild -license accept
```
Once done, tell Claude — it can then run the real iOS build and `swift test` for
real (both have only been verified via a macOS-only Command Line Tools workaround
so far, since this machine's Xcode license was never accepted).

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

## 4. Once the HUBU-FIS dataset finishes downloading (background, in progress)
Tell Claude — it can unzip it, inspect the label CSV, and run `tapbench` itself
to fill in `bench/summary.md` with real numbers.

## 5. Record the demo video (this genuinely needs you — your hands, your phone)
Script is in the git history / can be regenerated: open on a real patient clip
from the dataset (credited, hands only), then a live trial on your iPhone showing
the shrinking-bars result, then the benchmark number, then the paywall, then one
refused trial as the honest limit. Hard cap 1:55.

## 6. Submit on Devpost
Draft text is in `bench/DEVPOST_DRAFT.md` — fill in the real benchmark number and
links, then submit by **12:00 PDT Sep 30** (not 11:45pm — leave a buffer).
