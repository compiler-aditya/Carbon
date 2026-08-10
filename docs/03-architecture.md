# Carbon — Architecture

Companion to `02-system-design.md`. That file defines behaviour; this one defines code structure. Both are inputs to Claude Code.

**Stack:** Swift 6.x, SwiftUI, SwiftData, Observation, Vision, VisionKit, FoundationModels, RevenueCat + RevenueCatUI. iOS 26 minimum, iPhone + iPad (universal, portrait-first).

**Dependency policy:** RevenueCat is the *only* third-party dependency. Everything else is a system framework. Any proposed addition needs an explicit justification in the PR — no networking library, no snapshot-testing framework, no DI container, no CSV library. This is both a build-speed decision and a signal in a repo that gets read.

---

## 1. Target and package layout

One Xcode project, one app target, two local Swift packages. Two, not five — with four engineers merging for seven days, every extra package is a build-settings argument you do not have time for.

```
Carbon/
├── Carbon.xcodeproj
├── Carbon/                          # app target — UI only, no business logic
│   ├── CarbonApp.swift
│   ├── AppRoot.swift                # root navigation
│   ├── Features/
│   │   ├── TemplateList/
│   │   ├── TemplateEditor/
│   │   ├── Capture/
│   │   ├── Review/
│   │   ├── Dataset/
│   │   ├── Export/
│   │   ├── Paywall/
│   │   ├── Settings/
│   │   └── Onboarding/
│   ├── DesignSystem/                # tokens, primitives — see 05-uiux-spec.md
│   ├── Intents/                     # App Intents
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   └── SampleForms/             # bundled images so the app works on a simulator
│   └── Support/
│       └── Environment+Services.swift
├── Packages/
│   ├── CarbonCore/                  # domain + services. No SwiftUI, no UIKit.
│   │   ├── Sources/CarbonCore/
│   │   │   ├── Models/              # SwiftData @Model types
│   │   │   ├── DTOs/                # Sendable value types crossing boundaries
│   │   │   ├── Services/
│   │   │   │   ├── Recognition/
│   │   │   │   ├── Extraction/
│   │   │   │   ├── Normalization/
│   │   │   │   ├── Export/
│   │   │   │   ├── Entitlements/
│   │   │   │   └── Metering/
│   │   │   ├── Errors/
│   │   │   └── Support/
│   │   └── Tests/CarbonCoreTests/
│   └── CarbonTestFixtures/          # sample DocumentObservations, corpus loader, fakes
└── docs/                            # these spec files, committed
```

**Rule, enforced in review:** `CarbonCore` must not `import SwiftUI` or `import UIKit`. It is the reason the test suite can be fast and hermetic. `VNDocumentCameraViewController` lives in the app target because it is a view controller; `RecognitionService` lives in Core because it is not.

## 2. Service protocols

Every service is a protocol with exactly one production implementation and one fake. Define all protocols on Day 1, before any implementation, so four engineers can work behind them in parallel without blocking each other. This is the single highest-value hour of the week.

```swift
public protocol PageStoring: Sendable {
    func persist(_ image: CGImage, recordID: UUID, pageIndex: Int) async throws -> PageRef
    func load(_ ref: PageRef) async throws -> CGImage
    func delete(_ ref: PageRef) async throws
}

public protocol Recognizing: Sendable {
    func recognize(_ image: CGImage, pageID: UUID) async throws -> RecognizedPage
}

public protocol StructuredExtracting: Sendable {
    /// Tier 1 → 2 → 3 ladder lives behind this call.
    func extract(
        page: RecognizedPage,
        template: TemplateSnapshot
    ) async -> ExtractionResult
}

public protocol Normalizing: Sendable {
    func normalize(_ raw: String, as type: FieldType, using rules: NormalizationRules) -> NormalizedValue
}

public protocol Exporting: Sendable {
    func csv(records: [RecordSnapshot], template: TemplateSnapshot) throws -> Data
}

@MainActor public protocol EntitlementProviding: AnyObject, Observable {
    var isPro: Bool { get }
    var status: EntitlementStatus { get }
    func refresh() async
    func restore() async throws
}

public protocol UsageMetering: Sendable {
    /// Returns the snapshot, never the @Model. See the note below.
    func currentPeriod() async -> UsagePeriodSnapshot
    func canCreateTemplate(existingCount: Int, isPro: Bool) async -> MeterDecision
    func canCreateRecords(count: Int, isPro: Bool) async -> MeterDecision
    func recordCreated(count: Int) async
}
```

**`currentPeriod()` returns a snapshot, not the SwiftData model.** `UsagePeriod` in `04-data-model.md` §8 is a `@Model`, and a `@Model` is not `Sendable` — returning one from a `Sendable` protocol across an `async` boundary violates our own non-negotiable and will not compile under Swift 6 strict concurrency. The snapshot is four fields:

```swift
public struct UsagePeriodSnapshot: Sendable, Hashable {
    public let periodKey: String      // "2026-09"
    public let recordsCreated: Int
    public let templatesCreated: Int
    public let firstSeenAt: Date
}
```

This is the same rule as `TemplateSnapshot` and `RecordSnapshot` below, and it is worth stating twice because `UsagePeriod` is small enough that the temptation to pass it directly is real.

Note `TemplateSnapshot` / `RecordSnapshot`: **immutable `Sendable` structs projected from the SwiftData models.** SwiftData `@Model` classes are not `Sendable` and must never be passed into an actor or a service. Every service boundary takes snapshots. This one convention prevents the majority of Swift 6 concurrency pain in a SwiftData app, and getting it wrong on Day 1 costs a day on Day 4.

## 3. Dependency injection

No container. A plain struct in the environment.

```swift
@MainActor
struct Services {
    var pageStore: any PageStoring
    var recognizer: any Recognizing
    var extractor: any StructuredExtracting
    var exporter: any Exporting
    var entitlements: any EntitlementProviding
    var meter: any UsageMetering

    static func live() -> Services { ... }
    static func preview() -> Services { ... }   // fakes, deterministic, used by every #Preview
}

extension EnvironmentValues {
    @Entry var services: Services = .preview()
}
```

Every SwiftUI `#Preview` uses `.preview()`. Consequence: **every screen has a working preview with realistic data**, on the first day, with no camera and no model. That is what lets the UI engineer move at full speed while the pipeline is still being built, and it is why previews are a schedule decision rather than a nicety.

## 4. State and view models

- `@Observable` classes, `@MainActor`, one per non-trivial screen. Named `…Model`, not `…ViewModel`.
- Views own no business logic. A view reads model state and calls model methods.
- Lists read SwiftData directly with `@Query` where the screen is a straightforward fetch (template list, dataset list). Do not wrap a simple `@Query` in a model for architectural symmetry — that is ceremony, and reviewers of this repo will read it as such.
- Anything with multi-step async work (capture → extract → review) gets a model with an explicit state enum:

```swift
enum CaptureFlowState {
    case idle
    case capturing
    case processing(pageIndex: Int, total: Int)
    case review(draftID: UUID)
    case failed(CarbonError)
}
```

Explicit state enums, not scattered booleans. `isLoading` + `hasError` + `showSheet` is how a codebase becomes unreadable by Day 5, and this one is going to be read by a judge.

## 5. Navigation

`NavigationStack` with a typed path enum, one per tab. Two tabs: **Templates** and **Settings**. Datasets are reached through a template, because the template is the organising concept of the product and the navigation should teach that.

```swift
enum Route: Hashable {
    case template(UUID)
    case dataset(templateID: UUID)
    case record(UUID)
    case templateEditor(TemplateEditorMode)
}
```

Sheets: capture, paywall, export share, onboarding. Full-screen cover: capture only.

## 6. Concurrency conventions

Repeat of `02-system-design.md` §3, as enforceable rules:

1. Swift 6 language mode, strict concurrency. No `@unchecked Sendable`, no `@preconcurrency import` without a comment explaining why.
2. Never pass a `@Model` object across an isolation boundary. Snapshot it.
3. SwiftData writes go through a `@ModelActor` background actor. Reads for UI go through `@Query` on the main context.
4. Every `async` service function that can hang (model, Vision) takes an implicit deadline and is wrapped in `withTimeout`. Write that helper once, in Core, on Day 1.
5. No `Task { }` inside view bodies. Use `.task` / `.task(id:)`.

## 7. Testing strategy

Not comprehensive — targeted. Roughly 60–80 tests total is the right size for a week and is far more than a typical hackathon repo. Put them where they buy the most, and where a judge will look.

**Tier A — normalization (largest, cheapest, highest value).** Pure functions over strings. Table-driven tests: currency with symbols and separators, both decimal conventions, every date format in the list, ambiguous dates against a declared convention, fuzzy choice matching at and beyond threshold, OCR artefact stripping. Target 30+ cases. This is where extraction bugs actually live.

**Tier B — Tier 1 deterministic extraction.** Feed recorded `RecognizedPage` fixtures from `CarbonTestFixtures` (captured from the real corpus, serialised to JSON) through the extractor and assert field mapping. Covers header aliasing, ragged rows, missing header row, label-anchored record mode.

**Tier C — CSV export.** RFC-4180 edge cases: embedded commas, embedded quotes, newlines inside a cell, empty values, unicode, BOM present.

**Tier D — purchase flow.** RevenueCat Test Store makes this genuinely testable: the test store lets you choose the outcome of each purchase, so the happy path, user cancellation, failure, and already-subscribed are all deterministic. Assert entitlement state transitions and that the export gate opens and closes correctly. **This is a disproportionately impressive test suite to find in a hackathon repo** and it maps straight onto the "thoughtful use of RevenueCat" criterion.

**Tier E — metering.** Period rollover, boundary at exactly the limit, Pro bypass.

**Not tested:** SwiftUI views, Vision itself, the language model's output quality (that is what the corpus harness measures, not unit tests).

### Corpus harness
A command-line test target that runs the whole pipeline over the corpus directory and prints a table: per-field precision, % of records needing ≥1 correction, mean latency. Run it nightly during the build and paste the final output into the README. This turns 50 people's photographs into the single most credible artefact in the submission.

## 8. CI

One GitHub Actions workflow. Keep it to one job.

```yaml
name: build-and-test
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      # Pin the toolchain. The runner's default Xcode is not guaranteed to carry the
      # iOS 26 SDK, and a green badge that built against the wrong SDK is worse than
      # no badge. Fail loudly here rather than mysteriously in the build step.
      - name: Select Xcode 26
        run: sudo xcode-select -s /Applications/Xcode_26.app

      # Resolve the destination at runtime instead of hardcoding a device name.
      # A renamed simulator is a silent CI failure that costs an hour to diagnose.
      - name: Resolve simulator
        run: echo "DESTINATION=platform=iOS Simulator,OS=latest,name=iPhone 17" >> "$GITHUB_ENV"

      - name: Build and test CarbonCore
        run: xcodebuild test -scheme CarbonCore -destination "$DESTINATION"

      - name: Build app
        run: |
          cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
          xcodebuild build -scheme Carbon -destination "$DESTINATION"

      - name: SwiftLint
        run: swiftlint --reporter github-actions-logging
        continue-on-error: true    # warning, not a gate — see §10
```

Two details that are load-bearing rather than decorative. **Copying the example secrets file in CI is the zero-config path under test** — if the app stops building with the placeholder key, CI catches it, which is precisely the failure that would otherwise be discovered by a judge. And SwiftLint runs `continue-on-error` because §10 says it is a warning; wiring it as a gate on Day 1 is how a team spends an afternoon on line length.

Add the badge to the README. A green badge tells a judge the repo compiles before they open Xcode, which is worth more than it sounds when someone is grading dozens of submissions.

## 9. Git conventions

- `main` is always green. No direct pushes; PRs only, one approval.
- Branches: `feat/<area>-<short>`, `fix/<area>-<short>`.
- Conventional commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`).
- **Commit daily, per engineer, throughout the week.** Next Gen judges look at project state over time; a repo whose entire history is one commit reads badly regardless of quality.
- One PR per feature area, small enough to review in ten minutes.
- Never commit: API keys, `.xcuserdata`, build products, the corpus images (they may contain real personal data — see `07-build-plan.md` §5).

## 10. Code style

- SwiftLint with a short, opinionated config, run in CI as a warning not a failure. Do not spend Day 1 arguing about line length.
- No abbreviations in type or property names. `FieldDefinition`, not `FieldDef`.
- Files under 300 lines. If a view exceeds it, extract a subview.
- No `// MARK: - Properties` boilerplate. Comments explain *why*, never *what*.
- One type per file, filename matches the type.
- `guard` for early exit; avoid nesting past two levels.
- Strings the user sees go in a `String Catalog` from Day 1, even though v1 is English-only. Retrofitting is worse than doing it once.
