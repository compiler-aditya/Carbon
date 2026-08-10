# Carbon — RevenueCat & Monetization Spec

One of the four Next Gen judging criteria is whether the project *thoughtfully* uses RevenueCat. Most entries will wire a single paywall the night before. This document is how we don't.

**Do this on Day 1, not Day 6.** RevenueCat integration is the one non-negotiable requirement in the whole competition, and Test Store plus Paywalls V2 makes it a two-hour job. Kill it immediately and every remaining day is discretionary product work rather than a race against a mandatory dependency.

---

## 1. Monetization design, and the evidence behind it

RevenueCat's *State of Subscription Apps 2026* reports that hard paywalls convert at a median Day-35 trial-to-paid rate of about 10.7% versus roughly 2.1% for freemium — around 5× — while one-year subscriber retention is statistically indistinguishable (27% vs 28%), and revenue per install at day 60 is roughly 8× ($3.09 vs $0.38). The received wisdom that tight gating wrecks retention does not survive contact with the data.

It also shows higher-priced apps converting downloads about 2× better than low-priced ones (2.8% vs 1.4% median). The $0.99/week race-to-the-bottom that dominates the utility-scanner segment is the worst available choice.

**So: a genuinely tight free tier, and prosumer pricing.** Not a hard paywall — the user must be able to complete one full capture → extract → review cycle, because that experience *is* the pitch and gating it would be gating our own demo. But the free tier ends before the workflow becomes a habit.

### Free tier
- **1 template**
- **20 records per calendar month**
- **No export**
- Everything else: full capture, full extraction including on-device intelligence, full review and correction, full dataset view and search.

### Carbon Pro
- Unlimited templates
- Unlimited records
- CSV export
- (v1.1 slots, do not build: iCloud sync, XLSX, multi-page merge)

**Why these three meters and not others.** Each is tied to the unit of value, so willingness to pay rises exactly as the user moves real work into the app:

| Meter | Why |
|---|---|
| Template count | A template *is* a workflow the user has committed to Carbon. The second template is the moment it stops being a trial and becomes their system. Highest-intent signal in the product. |
| Records per month | Directly proportional to value received. Someone at 20 records/month is dabbling; someone at 200 has replaced a job. |
| Export | The classic prosumer gate, and the honest one: the app has already done the work and shown you it worked. You are paying to take the output with you, not to find out whether it works. |

**The anti-pattern we are avoiding:** gating extraction quality, or the number of fields, or watermarking output. Those degrade the product to manufacture demand. Gating *volume* and *egress* is the version that respects the user, and reviewers can tell the difference.

## 2. Pricing

| Package | Price (USD) | Product ID |
|---|---|---|
| Monthly | $4.99 | `carbon_pro_monthly` |
| Annual | $29.99 (≈50% off monthly) | `carbon_pro_annual` |
| Lifetime | $49.99 (non-consumable) | `carbon_pro_lifetime` |

- **7-day free trial on Annual only.** Trial on the annual package is the standard high-converting configuration and it makes the annual card the obvious choice.
- Lifetime exists for two reasons: prosumers with an aversion to subscriptions convert on it, and having a non-consumable alongside subscriptions demonstrates packaging thinking rather than a single-product wire-up. Mention it in the Devpost description.
- Prices are configured in the dashboard; **never hardcode a price string in the app.** Read from the `Package`'s localized price. A hardcoded price in a paywall is an instant tell.

## 3. RevenueCat dashboard configuration

Do this before writing app code.

1. **Project:** `Carbon`.
2. **Entitlement:** identifier `pro`. Exactly one. Multiple tiers would be over-engineering for a single Pro level.
3. **Test Store:** confirm one was auto-provisioned (Apps and providers → Test configuration). Create products there matching the three IDs above and attach all three to the `pro` entitlement.
4. **Offering:** identifier `default`. Packages: `$rc_monthly` → monthly, `$rc_annual` → annual, `$rc_lifetime` → lifetime.
5. **Paywall:** build with **Paywalls V2** in the dashboard, following the constraints in `05-uiux-spec.md` §4.9. Attach to the `default` offering.
6. Store the **Test Store API key** in `Config/Secrets.example.xcconfig` as a placeholder and document it in the README. See §4.

## 4. Keys, and how a judge runs this repo

This is the detail that decides whether a judge can verify our work, so it gets its own section.

**Never commit a real key.** But an unbuildable repo fails the "core functionality clear from the code" criterion. Resolve it like this:

```
Config/
  Secrets.example.xcconfig     # committed, placeholder value
  Secrets.xcconfig             # gitignored, real key
```

```
// Secrets.example.xcconfig
REVENUECAT_API_KEY = test_REPLACE_ME
```

- Read via `Info.plist` → `$(REVENUECAT_API_KEY)` → a typed `AppConfig` accessor.
- **The app must launch and be fully usable with the placeholder key.** If configuration fails, log it, set entitlement state to `.unknown`, treat the user as free tier, and continue. Nothing about capture, extraction, review, or the dataset depends on RevenueCat succeeding.
- The README gives a judge two paths: (a) run as-is — everything works except purchase; (b) drop their own free RevenueCat Test Store key into `Secrets.xcconfig` in about two minutes and the purchase flow works end to end. Spell out both, with the exact steps.
- **Test Store keys must never ship in a release build** — RevenueCat's SDK deliberately alerts and crashes if a release build initialises with one. Since Next Gen requires no store release this is not a live risk for us, but state it in the README and add a `#if DEBUG` guard with a comment, because it demonstrates we know.

## 5. SDK integration

```swift
// CarbonApp.swift
@main
struct CarbonApp: App {
    init() {
        Purchases.logLevel = .info    // .debug locally, never .verbose in a committed default
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: AppConfig.revenueCatAPIKey)
                .with(storeKitVersion: .storeKit2)
                .build()
        )
    }
    // ...
}
```

Rules:
- Configure in `init()`, but **never `await` anything from RevenueCat before first paint.** Entitlement state resolves asynchronously and the UI renders from cached state meanwhile.
- No `appUserID`. Anonymous IDs only — there is no account system and inventing one would be scope creep.
- Do not call `Purchases.shared` from anywhere except `LiveEntitlementService`. Everything else talks to the `EntitlementProviding` protocol from `03-architecture.md` §2. That boundary is what makes §8's tests possible.

### Entitlement service

```swift
@MainActor @Observable
final class LiveEntitlementService: EntitlementProviding {
    private(set) var status: EntitlementStatus = .unknown
    var isPro: Bool { status == .pro }

    func start() {
        Task { await refresh() }
        Task {
            for await info in Purchases.shared.customerInfoStream {
                apply(info)
            }
        }
    }

    func refresh() async {
        do { apply(try await Purchases.shared.customerInfo()) }
        catch { status = .free }   // fail open to free, never block the app
    }

    func restore() async throws {
        apply(try await Purchases.shared.restorePurchases())
    }

    private func apply(_ info: CustomerInfo) {
        status = info.entitlements["pro"]?.isActive == true ? .pro : .free
    }
}
```

`customerInfoStream` matters: entitlement changes arriving from anywhere — a purchase in another session, a restore, an expiry — propagate to the UI with no manual refresh. It is one line and it is the difference between a wire-up and an integration.

### Presenting the paywall

Use RevenueCatUI. Do not hand-build the paywall.

```swift
import RevenueCatUI

// Gate a specific action rather than the app.
.sheet(isPresented: $showPaywall) {
    PaywallView(displayCloseButton: true)
}
```

Prefer explicit presentation over the blanket `presentPaywallIfNeeded(requiredEntitlementIdentifier:)` modifier at the app root. That modifier is the right tool for a hard paywall; we are gating three specific actions, and presenting from the action keeps the paywall's context obvious to the user — they see it because they tried to export, not because they opened the app.

## 6. Gating rules — exhaustive

| Trigger | Free behaviour |
|---|---|
| Create template, 0 existing | Allowed |
| Create template, ≥1 existing | Paywall. The New-template card stays visible with a lock and the meter. |
| Scan, records this period < 20 | Allowed |
| Scan, records this period ≥ 20 | Paywall **before** the camera opens — never after extraction. Making someone watch the work happen and then refusing to save it is hostile. |
| Table-mode scan that would cross the limit mid-page | Save up to the limit, then present the paywall showing `14 rows found · 6 saved · 8 need Pro`. Honest partial success beats an all-or-nothing rejection. |
| Export, any size | Paywall. Export button always visible with a lock. |
| Review, correct, search, delete, dataset view | Always free, always unlimited |
| On-device extraction quality | **Identical on both tiers.** Never degrade the core function to sell. |

Meter checks route through `UsageMetering`, and **`MeterDecision` is never an error** — it returns `.allowed`, `.paywall(reason:)`, or `.partial(allowed: Int)`. Treating a gate as an error is how paywalls end up presented as alerts, which is the worst possible paywall UX.

## 7. Purchase edge cases

All of these must be handled and all are testable in Test Store, which lets you choose the outcome of each purchase.

| Case | Behaviour |
|---|---|
| Purchase succeeds | Sheet dismisses, entitlement flips via stream, the originally-attempted action **retries automatically**. Do not make them tap Export again. |
| User cancels | Sheet dismisses silently. No error, no toast, no "are you sure". |
| Purchase fails (network, payment) | Inline message inside the paywall, sheet stays open, retry available. |
| Already subscribed, fresh install | Restore link is prominent in the paywall and in Settings. On launch, cached `CustomerInfo` resolves and no paywall appears. |
| Restore finds nothing | "No previous purchase found on this Apple ID." Not an error state. |
| Offline at purchase attempt | Paywall shows a clear offline message rather than an opaque failure. |
| Offline with active Pro | Cached entitlement honoured. Pro must work on a plane. |
| RevenueCat unreachable at launch | Free tier, no block, background retry. |
| Subscription expires mid-session | Stream fires, `isPro` flips, gates re-engage. Never mid-action — check the gate at action start only. |

## 8. Tests

This is the suite that maps directly onto the judging criterion, and it is the one most likely to be *read*.

```
CarbonCoreTests/Entitlements/
  EntitlementServiceTests.swift    fake CustomerInfo → status transitions,
                                   stream updates, restore, failure falls open to free
CarbonCoreTests/Metering/
  UsageMeterTests.swift            below/at/above limit, exact boundary, month rollover,
                                   Pro bypass, partial decision for table mode
CarbonCoreTests/Gating/
  GateDecisionTests.swift          the full matrix in §6, as a table-driven test
```

Plus a manual Test Store checklist in the README covering each row of §7, with a tick per verified case. A checklist a reviewer can see was actually run is worth more than a claim of coverage.

## 9. What goes in the Devpost description

Two short paragraphs, no more, and lead with the design rather than the wire-up:

> Carbon gates on volume and export, not on quality — extraction is identical for free and Pro users. The three meters (templates, records per month, export) each track the unit of value the user actually receives, so the paywall arrives when Carbon has stopped being a trial and started being their system.
>
> The paywall is Paywalls V2 with a three-package offering (monthly, annual with a 7-day trial, and a lifetime non-consumable), and entitlement state is driven by `customerInfoStream` so a purchase, a restore, or an expiry propagates without a manual refresh. Purchase-flow behaviour — cancellation, failure, restore, offline, expiry mid-session — is unit-tested against Test Store; see `CarbonCoreTests/Entitlements`. Inference is on-device via Apple's frameworks, so there is no per-scan cost and gross margin is 100%.
