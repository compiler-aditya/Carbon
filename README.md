# Carbon

**Your form, remembered.** Map a paper form once. Every photo after that becomes a row.

![Platform](https://img.shields.io/badge/platform-iOS%2026%2B-lightgrey)
![Swift](https://img.shields.io/badge/swift-6.x-orange)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

Built for **RevenueCat Shipaton 2026 — Next Gen Award**.

> **Status: in development.** The specification is complete and committed under
> [`docs/`](docs/); the app target does not exist yet. This file is a stub and will be
> replaced with the full README — run instructions, architecture note, and measured
> accuracy numbers — before submission. Nothing below is a claim about working software.

---

## The problem

Some paper cannot be removed from a workflow. A statutory register has to be on paper. A
delivery challan needs a physical signature. A site has no connectivity. A form was printed
by someone else.

In all of those cases the paper is mandatory and the digital copy is a second job — someone
retypes the same fields, from the same form, in the same order, every day.

Digital form builders assume you can replace the paper. Generic scanners give you an image.
Photo-to-spreadsheet converters are stateless: every scan starts from zero.

**Carbon remembers the form.** The first scan costs you a minute of mapping. Every scan
after that is instant and lands in the same shaped dataset.

## How it will work

1. **Scan the form once** and declare its fields — label, type, required.
2. **Scan filled copies.** Vision reads the page structure on-device; fields are matched and typed.
3. **Check what needs checking.** Every value shows its confidence. Corrections take one tap.
4. **Export** to CSV.

Two template modes: **record** (one page → one record) and **table** (one page → one record
per table row).

Everything runs on the device. There is no server, no account, and no network call in the
capture, extraction, storage or export path. The only outbound traffic in the app is the
RevenueCat SDK.

## Specification

The full spec pack is committed and is the source of truth for the build:

| Document | Contents |
|---|---|
| [`docs/01-idea-brief.md`](docs/01-idea-brief.md) | Product scope. Source of truth. |
| [`docs/02-system-design.md`](docs/02-system-design.md) | Extraction pipeline, degradation ladder, performance budgets |
| [`docs/03-architecture.md`](docs/03-architecture.md) | Package layout, service protocols, concurrency, testing |
| [`docs/04-data-model.md`](docs/04-data-model.md) | SwiftData schema and the `Sendable` snapshot layer |
| [`docs/05-uiux-spec.md`](docs/05-uiux-spec.md) | Design tokens, components, screen specs |
| [`docs/06-revenuecat-spec.md`](docs/06-revenuecat-spec.md) | Entitlements, offering, gating matrix |
| [`docs/07-build-plan.md`](docs/07-build-plan.md) | Day-by-day plan and cut order |

## Building

Requires **Xcode 26** or later (iOS 26 SDK). Verified against Xcode 26.6 / Swift 6.3.3 /
iOS SDK 26.5.

Once the app target lands, Carbon will build and run from a clone with no key, no account
and no configuration file. Purchasing is the only thing that needs a key:

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
# then set REVENUECAT_API_KEY to your own RevenueCat Test Store key
```

Without a key the app treats you as a free-tier user and everything except purchasing works.

## License

MIT — see [LICENSE](LICENSE).
