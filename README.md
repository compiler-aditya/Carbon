# Carbon

**Your form, remembered.** Map a paper form once. Every photo after that becomes a row.

[![build-and-test](https://github.com/compiler-aditya/Carbon/actions/workflows/ci.yml/badge.svg)](https://github.com/compiler-aditya/Carbon/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2026%2B-lightgrey)
![Swift](https://img.shields.io/badge/swift-6.x-orange)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

Built for **RevenueCat Shipaton 2026 — Next Gen Award**.

> **Status: in active development**, in the open, ahead of the September deadline. The capture →
> extract → review → export loop works today. What has and has not been run on real hardware is
> in [Honest status](#honest-status) — including the accuracy table, which stays empty until
> there are real photographs behind it.

---

## The problem

Some paper cannot be removed from a workflow. A statutory register has to be on paper. A
delivery challan needs a signature. A site has no connectivity. A form was printed by someone
else.

The paper is mandatory, so the digital copy becomes a second job — someone retypes the same
fields, in the same order, every day. Form builders assume you can replace the paper. Scanners
give you an image. Photo-to-spreadsheet converters are stateless: every scan starts from zero.

**Carbon remembers the form.** The first scan costs a minute of mapping. Every scan after that
lands in the same shaped dataset.

## How it works

1. **Map the form once** — name it, declare its fields.
2. **Photograph filled copies.** Vision reads the page on-device; columns are matched to your
   fields and values typed and normalized.
3. **Check what needs checking.** Every value sits on a rule whose style *is* its confidence —
   solid, dashed, or dotted red. Corrections take one tap.
4. **Export** to CSV.

**record** mode turns one page into one row; **table** mode turns one page into a row per ruled
line.

## Running it

No key, no account, no backend, no configuration.

```bash
git clone https://github.com/compiler-aditya/Carbon.git
cd Carbon && open Carbon.xcodeproj
```

**Requires Xcode 26.** Developed against Xcode 26.6 / Swift 6.3.3 / iOS SDK 26.5.

Run the `Carbon` scheme. **On a simulator, tap "Start with a sample form"** — two forms ship in
`Carbon/Resources/SampleForms/`, and that path runs the real pipeline over a real image. The
values you see are extracted, not canned.

CI builds the app with no `Secrets.xcconfig` present on every push, so the zero-config path
cannot quietly stop working.

**Purchases (optional).** `cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig` and set a
free RevenueCat **Test Store** key, with products `carbon_pro_monthly`, `carbon_pro_annual`,
`carbon_pro_lifetime` on an entitlement named `pro`. Without a key the SDK is never configured
at all — not handed a placeholder to choke on — and you are treated as free tier.

## Architecture

Fully on-device. No server, no account, no network call in the critical path. The only outbound
traffic is the RevenueCat SDK.

```
VisionKit          →  Vision                     →  FoundationModels     →  SwiftData
document camera       RecognizeDocumentsRequest      text-only mapping       local store
                      (native table detection)      (runtime schema)        + JPEG on disk
```

**A three-tier ladder.** Tier 1 is deterministic Swift — fuzzy column-header matching in table
mode, label-anchored proximity in record mode — and resolves most of a printed page in under
100 ms with no model. Tier 2 sends only the *unresolved* fields to Apple's on-device model, text
only, with a hard timeout. Tier 3 leaves the field empty and marks it for review. Every value
carries its tier and a confidence, and the interface shows both.

**Why the model gets text, not images.** Foundation Models gained image input in iOS 27, in beta
during this build. Depending on it would mean anyone running this repo needs a beta OS. So
Vision — stable since iOS 26, with native table detection — does the layout, and the model does
text-to-schema mapping only. Choosing the stable API and being able to say why felt more useful
than shipping against a beta.

**The output schema is built at runtime.** `@Generable` is the obvious API and the wrong one: a
macro needs the shape at compile time, and Carbon's fields are declared by the user in the app.
Tier 2 assembles a `DynamicGenerationSchema` per template instead.

**Degradation is the point, not a fallback.** Where Apple Intelligence is unavailable — ineligible
hardware, switched off, downloading, or an unsupported language — Tier 2 is skipped and the app
stays fully usable on Tier 1. Availability and language are checked separately, because the model
can be available and still not cover your language.

**Carbon learns the forms it reads.** A column matched fuzzily — the page says `Arnount`, the
template knows `Amount` — has that spelling stored as an alias, so next week it matches exactly.
No model, about twenty lines.

**Structure.** `CarbonCore` (models and services, no SwiftUI), the app target, and a corpus
harness that measures Carbon without being part of it. Every service is a protocol with one live
implementation and one fake, so every screen previews and the suite stays hermetic. Swift 6
strict concurrency; SwiftData models never cross an isolation boundary — and the compiler has
already caught one attempt to break that rule.

Full specs in [`docs/`](docs/).

## Accuracy

**Not yet measured on real photographs.** No corpus has been collected, so every cell below is
empty. Publishing a number with no photographs behind it is the thing this project argues
against, and a table filled from pages this repository drew itself would be the clearest
possible way to do exactly that.

| Metric | Printed forms | Handwritten |
|---|---|---|
| Records needing no correction | — | — |
| Field-level precision | — | — |
| Resolved by Tier 1 alone | — | — |
| Rows found correctly | — | — |
| Median latency per page | — | — |
| p95 latency per page | — | — |

The rows are the commitment: these are the six numbers that will appear here, split printed
against handwritten, whatever they turn out to be.

**What the harness does.** It runs the real pipeline over photographed forms with hand-typed
ground truth and prints the table above, filled in. It scores exact matches only, counts a row
Carbon never found as wrong rather than skipping it, separates row-count errors from field
precision, and truncates percentages rather than rounding up —
[`docs/10-corpus-format.md`](docs/10-corpus-format.md).

**What has been measured.** One page, drawn by this repository, checking that the pipeline and
the harness run end to end. It resolves all five fields through Tier 1 with no model, in 0.38 s
against a 2 s budget. That is a plumbing check and a latency reading; it is not accuracy, and
the harness now says so in its own output rather than trusting whoever pastes it:

```bash
cd Packages/CarbonCore && swift run CorpusHarness ../../corpus-smoke --markdown
```

Point it at a real corpus — a directory of photographs, one JSON of typed truth beside each, and
a `manifest.json` — and the same command fills the table:

```bash
cd Packages/CarbonCore && swift run CorpusHarness ../../corpus --markdown
```

`corpus/` is gitignored and always will be. Photographs of someone's register are their
records, not this repository's.

## Monetization

One `pro` entitlement, three packages (monthly; annual with a 7-day trial; a lifetime
non-consumable), Paywalls V2 from the dashboard.

Free is one template, twenty records a month, no export. Gating is on **volume and egress, never
on quality** — extraction is identical on both tiers. Limits are not errors: hitting one opens
the paywall, never an alert. A table page crossing the limit mid-way saves the rows that fit and
reports what needs Pro. And when entitlement flips to Pro, **the export you asked for opens by
itself** — nobody should tap Export twice after paying for it. State comes from
`customerInfoStream`, so purchases, restores and expiries propagate with no manual refresh.

**Known limitation:** the meter is local, so a reinstall resets it. Entitlement is authoritative
via RevenueCat; the free limit is a courtesy, not DRM.

## Tests

```bash
cd Packages/CarbonCore && swift test
```

**201 tests across 26 suites**, concentrated where extraction bugs live: normalization, Tier 1
extraction, the ladder's merging rules, the rule that decides whether a page produced anything
at all, CSV RFC-4180 edge cases, the SwiftData schema against a real container, storage file
cleanup, and the corpus maths. Eight drive Vision and
FoundationModels directly; those run locally and are skipped in CI, where the frameworks exist
but their assets do not. `CARBON_FRAMEWORK_TESTS=1` forces them on.

## What's deliberately not here

iCloud sync · macOS app · XLSX and JSON export · multi-page merge · team sharing · signature
capture · barcode lookups · a server of any kind · localization beyond English.

## Honest status

| | |
|---|---|
| Zero-config clone → build → run | ✅ verified, enforced by CI |
| Vision → Tier 1 → normalize → store → review → dataset | ✅ verified end to end on a simulator |
| CSV export bytes (RFC 4180, BOM, quoting) | ✅ covered by tests |
| Camera capture on a real device | ⬜ not yet run — a simulator has no camera |
| Tier 2 against the real on-device model | ⬜ unit-tested against a stub; never executed |
| Purchase flow end to end | ⬜ needs a RevenueCat Test Store key |
| Corpus harness runs end to end | ✅ verified — `corpus-smoke/` ships with the repo |
| Accuracy on real photographs | ⬜ harness ready, corpus not collected |
| Demo video | ⬜ not shot |

## License

MIT — see [LICENSE](LICENSE).
