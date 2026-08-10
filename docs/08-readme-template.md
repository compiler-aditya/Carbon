# Carbon — README Template

This is a **judged artifact**, not documentation. In every other Shipaton category the code is invisible; in Next Gen a judge opens the repository and the official criteria include whether core functionality is clear from the code. Assume four minutes of attention and a decision formed in the first forty seconds.

Fill in every `<>`. Delete every instruction line. Replace the accuracy table with real numbers from the corpus harness.

---

```markdown
<!-- Above-the-fold GIF. 8–12 seconds, ≤5 MB, hosted in the repo at docs/media/demo.gif.
     Capture → rows appear → export. No title card. This is the single highest-value
     element in the file; a judge decides whether to keep reading here. -->

![Carbon](docs/media/demo.gif)

# Carbon

**Your form, remembered.** Map a paper form once. Every photo after that becomes a row.

[![build-and-test](https://github.com/<org>/<repo>/actions/workflows/ci.yml/badge.svg)](https://github.com/<org>/<repo>/actions)
![Platform](https://img.shields.io/badge/platform-iOS%2026%2B-lightgrey)
![Swift](https://img.shields.io/badge/swift-6.x-orange)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

Built for **RevenueCat Shipaton 2026 — Next Gen Award**.
📺 **[2-minute demo](https://youtube.com/watch?v=<id>)**

---

## The problem

Some paper cannot be removed from a workflow. A statutory register has to be on paper. A delivery challan needs a physical signature. A site has no connectivity. A form was printed by someone else.

In all of those cases the paper is mandatory and the digital copy is a second job — someone retypes the same fields, from the same form, in the same order, every day.

Digital form builders assume you can replace the paper. Generic scanners give you an image. Photo-to-spreadsheet converters are stateless: every scan starts from zero.

**Carbon remembers the form.** The first scan costs you a minute of mapping. Every scan after that is instant and lands in the same shaped dataset.

## How it works

1. **Scan the form once** and declare its fields — label, type, required.
2. **Scan filled copies.** Vision reads the page structure on-device; the fields are matched and typed automatically.
3. **Check what needs checking.** Every value shows its confidence. Corrections take one tap.
4. **Export** to CSV.

Two template modes: **record** (one page → one record) and **table** (one page → one record per table row).

## Running it

No API key, no account, no backend, no configuration. It runs from a clone.

```bash
git clone https://github.com/<org>/<repo>.git
cd <repo>
open Carbon.xcodeproj
```

**Requirements:** Xcode `<version>`, iOS 26+ target, macOS `<version>`.

Select the `Carbon` scheme and run. **On a simulator with no camera, tap *Use a sample form* on the first screen** — three real scanned forms ship in `Carbon/Resources/SampleForms/` so the whole pipeline is explorable without hardware.

### Optional: the purchase flow

The app runs fully without this. To exercise purchases, drop a free RevenueCat **Test Store** key into a local config — about two minutes:

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
# set REVENUECAT_API_KEY to your Test Store key
```

Create a free RevenueCat project, then Apps and providers → Test configuration → new Test Store, and add products `carbon_pro_monthly`, `carbon_pro_annual`, `carbon_pro_lifetime` attached to an entitlement named `pro`.

Without a key the app treats you as a free-tier user and everything except purchasing works.

## Architecture

<!-- The section that answers "thoughtful technical choices". Keep it under 400 words.
     A judge should be able to hold the whole system in their head after reading it. -->

Fully on-device. No server, no account, no network call in the critical path. The only outbound traffic in the app is the RevenueCat SDK.

```
VisionKit          →  Vision                     →  FoundationModels    →  SwiftData
document camera       RecognizeDocumentsRequest      text-only mapping      local store
(edge detect,         (native table/row/column       of unresolved fields   + JPEG on disk
 dewarp, multipage)    detection, on-device)         (@Generable output)
```

**Extraction runs a three-tier ladder.** Tier 1 is deterministic Swift — table header matching in table mode, label-anchored proximity in record mode. It resolves most values on printed forms in under 100 ms with no model at all. Tier 2 sends only the *unresolved* fields to Apple's on-device model with `@Generable` structured output, a hard timeout, and a token budget. Tier 3 returns the field empty and marks it for review. Every value carries its tier and a confidence score, and the UI shows both.

**Why the model gets text and not images.** Foundation Models gained image input in iOS 27, which was still in beta while this was built. Depending on it would have meant anyone running this repo needed a beta OS. So Vision — stable since iOS 26, with native table detection — does the layout work, and the model does text-to-schema mapping only. The image-input path exists behind an availability check as an enhancement, not a dependency. Choosing the stable API and being able to say why felt more useful than shipping against a beta.

**Graceful degradation is the point, not a fallback.** On hardware or in regions where Apple Intelligence is unavailable, Tier 2 is skipped and the app remains fully functional on Tier 1. `RecognizeDocumentsRequest` has its own fallback to `RecognizeTextRequest` with y-frame row clustering. There is no configuration in which the app is unusable.

**Structure.** `CarbonCore` (a local Swift package: models, services, no SwiftUI) plus the app target (UI only). Every service is a protocol with one live implementation and one fake, so every screen has a working `#Preview` with realistic data and the test suite is hermetic. Swift 6 strict concurrency; SwiftData models never cross an isolation boundary — services take immutable `Sendable` snapshots.

Full specs in [`docs/`](docs/).

## Accuracy

<!-- Real numbers from the corpus harness. Do not round up. Do not omit the failure modes. -->

Measured on **`<N>` photographs** of **`<M>` form types** contributed by `<K>` people, with hand-typed ground truth. Deliberately includes shadow, glare, skew, crease and low light.

| Metric | Printed forms | Handwritten |
|---|---|---|
| Records needing no correction | `<x>%` | `<y>%` |
| Field-level precision | `<x>%` | `<y>%` |
| Resolved by Tier 1 alone | `<x>%` | `<y>%` |
| Median latency per page | `<x>` s | `<y>` s |

**Where it fails:** `<be specific — e.g. dense handwriting under 8pt effective size; merged cells; forms where the header row is repeated mid-page; ambiguous dates on forms with no printed convention>`.

This is why the correction editor is a first-class screen rather than an afterthought. Carbon shows you what it is unsure about instead of hiding it. `<one line on what you'd do next to improve the weakest number>`

## Monetization

RevenueCat with a single `pro` entitlement and a three-package offering (monthly; annual with a 7-day trial; a lifetime non-consumable). The paywall is Paywalls V2, configured in the dashboard.

The free tier is one template, twenty records per month, and no export. Gating is on **volume and export, never on quality** — extraction is identical for free and paid users. Each meter tracks the unit of value received, so the paywall arrives when Carbon has stopped being a trial and become someone's system.

Entitlement state is driven by `customerInfoStream`, so purchases, restores and expiries propagate without a manual refresh. Purchase behaviour — cancellation, failure, restore, offline, expiry mid-session — is unit-tested against Test Store in `CarbonCoreTests/Entitlements`.

Because inference is on-device, there is no per-scan cost.

**Known limitation:** the free-tier meter is stored locally, so a reinstall resets it. Entitlement state is authoritative via RevenueCat; the free limit is a courtesy, not DRM. Server-side metering is the next step.

## Tests

```bash
xcodebuild test -scheme CarbonCore -destination 'platform=iOS Simulator,name=iPhone 17'
```

`<N>` tests, concentrated where extraction bugs actually live: normalization (currency separators, both decimal conventions, every supported date format, ambiguous dates against a declared convention, fuzzy choice matching), Tier 1 extraction against recorded `RecognizedPage` fixtures, CSV RFC-4180 edge cases, and the entitlement and metering state machines.

The corpus harness (`swift run CorpusHarness <path>`) runs the full pipeline over a form set and prints the table above.

## What's deliberately not here

Listed because scope discipline was a decision, not an accident:

iCloud sync · macOS app · XLSX and JSON export · multi-page merge · team sharing · signature capture · localization beyond English.

Open issues carry the full roadmap, including what we considered and rejected.

## Built by

`<N>` students at `<institution>`. Four on the codebase; `<N>` collecting and labelling the form corpus; `<N>` on QA across `<N>` devices; the rest on design, video and documentation. See [CONTRIBUTORS.md](CONTRIBUTORS.md).

## License

MIT — see [LICENSE](LICENSE).
```

---

## Notes on filling this in

**The first forty seconds.** GIF, one-line pitch, badges, run instructions. If a judge reads nothing else, they should know what it does and that it builds.

**Length.** Four minutes of reading. If a section grows past its usefulness, move it to `docs/` and link. A 3,000-word README is skimmed, which means the good parts get skipped.

**The accuracy table is the credibility anchor.** Nearly every submission will claim its extraction works. Almost none will have measured it on 250 real photographs and published the failure modes. Understate rather than overstate — the correction rate being honest is *why* the correction editor exists, so the number and the product argument reinforce each other.

**LICENSE must be detectable.** A plain `LICENSE` file with unmodified MIT text so GitHub shows "MIT license" in the About panel. The Next Gen rules require the licence to be visible there specifically. Verify it renders before submitting — a licence GitHub cannot parse is a technically incomplete submission.

**Repo hygiene the README implies and a judge will check:** no TODOs in `main`, no commented-out code, `.gitignore` covering `xcuserdata` and `Secrets.xcconfig`, no committed keys, `docs/` present, a public issues board, and daily commits across the whole build window rather than one giant initial commit.
