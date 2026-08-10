# Carbon — System Design

Read `01-idea-brief.md` first. This document describes *what the system does and how the pieces relate*. `03-architecture.md` describes *how the code is organised*. Where they overlap, this file defines behaviour and that file defines structure.

---

## 1. Shape of the system

Carbon is a **fully local, single-device, offline-first application**. There is no server, no account, no network call in the critical path. The only network traffic in the entire app is RevenueCat's SDK talking to RevenueCat.

```
┌──────────────────────────────────────────────────────────────────┐
│  DEVICE (iPhone / iPad, iOS 26+)                                 │
│                                                                  │
│  ┌────────────┐   ┌──────────────┐   ┌────────────────────────┐  │
│  │  Capture   │──▶│  Recognition │──▶│  Structured Extraction │  │
│  │ VisionKit  │   │    Vision    │   │   FoundationModels     │  │
│  └────────────┘   └──────────────┘   └────────────────────────┘  │
│        │                 │                       │               │
│        │ page images     │ DocumentObservation   │ typed values  │
│        ▼                 ▼                       ▼               │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │              Extraction Coordinator (actor)                │  │
│  └────────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────┐   ┌────────────────┐   ┌──────────────────┐    │
│  │  SwiftData   │◀─▶│  Review / Edit │──▶│  CSV Export      │    │
│  │  + file blob │   │       UI       │   │  FileDocument    │    │
│  └──────────────┘   └────────────────┘   └──────────────────┘    │
│         ▲                                                        │
│         │  entitlement + meter checks                            │
│  ┌──────┴───────────────────┐         ┌───────────────────────┐  │
│  │  Entitlement Service     │────────▶│  RevenueCat SDK       │──┼──▶ RevenueCat
│  │  + Usage Meter           │         │  (Test Store in dev)  │  │
│  └──────────────────────────┘         └───────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

## 2. The extraction pipeline, stage by stage

This is the heart of the app. Each stage is a protocol with one production implementation and one fake for tests. Stages communicate with plain `Sendable` value types, never with framework objects, so every stage is independently testable and replaceable.

### Stage 0 — Capture
- **API:** `VNDocumentCameraViewController` (VisionKit), wrapped in a `UIViewControllerRepresentable`.
- **Why:** free edge detection, perspective correction, shadow handling, multi-page, and a UI users already recognise from Notes and Files. Building our own camera would consume a day and be worse.
- **Output:** `[CapturedPage]` — `{ id: UUID, image: CGImage, pixelSize: CGSize, capturedAt: Date }`.
- **Persist immediately.** Write each page to disk as JPEG (quality 0.8) before any processing begins. A crash mid-extraction must never lose the user's photo. This is a hard requirement.
- **Also accept** an existing photo from the library and a shared image (Share Sheet is v1.1 but the entry point should already be an internal function, not view code).

### Stage 1 — Recognition
- **API:** Vision `RecognizeDocumentsRequest`, Swift-native async API.
- **Output:** `DocumentObservation`, a hierarchical container holding text, **tables (with rows and columns)**, lists, and barcodes.
- **We normalise it immediately** into our own DTO so nothing downstream imports Vision:

```swift
struct RecognizedPage: Sendable {
    let pageID: UUID
    let blocks: [RecognizedBlock]      // paragraphs / lines, with frames
    let tables: [RecognizedTable]      // structured grid
    let detectedData: [DetectedDatum]  // dates, phone numbers, emails, URLs
    let fullText: String               // reading-order concatenation, for the LLM prompt
}

struct RecognizedTable: Sendable {
    let frame: NormalizedRect
    let rows: [[RecognizedCell]]       // row-major; ragged rows allowed
    let headerRowIndex: Int?           // best guess, may be nil
}

struct RecognizedCell: Sendable {
    let text: String
    let frame: NormalizedRect
    let recognitionConfidence: Float   // from Vision
}
```

- **Availability caveat to verify on Day 1:** confirm the exact `@available` annotation on `RecognizeDocumentsRequest` in the installed SDK before building on it. Sources disagree on whether it is iOS 18+ or iOS 26+. Whatever it says, put the answer in the README. If it turns out to be unavailable on our floor, the Tier-2 fallback below becomes the primary path and the deadline is unaffected — this is why the ladder exists.

### Stage 2 — Structured extraction
Turn a `RecognizedPage` plus a `FormTemplate` into `[ExtractedRecord]`.

Three tiers, tried in order. **All three must exist.** The ladder is not defensive engineering, it is the feature that makes the app work on bad photos, and it is a talking point in the README.

**Tier 1 — Deterministic (always runs first).**
Pure Swift, no model. Fast, free, fully testable, and correct for the common case of a clean printed table.
- If the template is **table mode** and the page has a table: match the table's header row against each `FieldDefinition`'s `label` + `columnAliases` using normalised string distance. Every matched column maps to a field; each subsequent row becomes one `ExtractedRecord`.
- If the template is **record mode**: for each field, look for its label in `blocks`, then take the nearest text to the right of, or directly below, the label's frame. Classic label-anchored form reading, and it is reliable on printed forms.
- Each produced value carries `source: .deterministic` and a confidence derived from match quality.

**Tier 2 — Model-assisted (runs only for fields Tier 1 left empty or low-confidence).**
- **API:** FoundationModels, `SystemLanguageModel` + `LanguageModelSession`, **text only**.
- The prompt receives: the template schema (field labels and types), the page's `fullText`, and the specific fields still needing values. Never the image — see `01-idea-brief.md` §7.
- Output is constrained with `@Generable` / `@Guide` so the model returns typed Swift structs, not prose to parse. Constrain enumerated fields with `@Guide(.anyOf(choices))`.
- **Bounded:** one session per page, a hard timeout (default 8s), and a token budget. On timeout or refusal, fall through to Tier 3 for the remaining fields. The model is never allowed to block the UI or the pipeline.
- Values carry `source: .model` and confidence from the model's own reporting, clamped to a maximum below the deterministic ceiling — we trust a matched column header more than a model inference, and the UI should reflect that.

**Tier 3 — Unresolved.**
The field is returned empty with `source: .unresolved`, confidence 0. It renders in the review UI as an empty field on a dotted red rule, focused first. This is a normal outcome, not an error, and the copy must not treat it as a failure.

**Availability gate.** `SystemLanguageModel.default.availability` must be checked before Tier 2 and the result cached. On unsupported hardware, in an unsupported region, or with Apple Intelligence disabled, the app runs Tier 1 → Tier 3 and shows a one-line, non-blocking note in Settings explaining that on-device intelligence is unavailable and extraction is using layout matching only. **The app must be fully usable in this state.** Test this path explicitly — a judge on a simulator or an older device will hit it.

### Stage 3 — Normalization
Runs on every value regardless of tier, so behaviour is identical across tiers:
- **Number/currency:** strip currency symbols, thousands separators, and stray spaces; handle both `,` and `.` decimal conventions; reject if more than one plausible parse and drop confidence rather than guessing.
- **Date:** try the template's `preferredDateFormat` first, then a fixed ordered list of formats, then `Date.ParseStrategy`. Ambiguous `03/04/2026` resolves using the template's declared convention — never a locale guess, because the whole dataset must be internally consistent.
- **Choice:** fuzzy-match to the nearest declared choice; if the distance exceeds a threshold, keep the raw text and mark for review rather than snapping to a wrong option.
- **Text:** trim, collapse internal whitespace, strip OCR artefacts (isolated `|`, `~`).
- Normalization is **pure functions over strings** — the single easiest thing in this codebase to unit-test, and where the majority of the test suite should live.

### Stage 4 — Persistence
The coordinator writes a `CaptureRecord` per extracted record with status `.needsReview` if any field is below the review threshold or unresolved, otherwise `.confirmed`. Writes happen on a background `ModelActor`; the UI observes.

### Stage 5 — Review
The user corrects cells. Any edit sets `wasEditedByUser = true` and confidence to 1.0, and **keeps the original `rawText`**. Keeping the raw text is what lets us compute real accuracy numbers from the corpus — the correction rate *is* our accuracy metric, harvested for free from normal use.

### Stage 6 — Export
- CSV, RFC-4180 quoting, UTF-8 with BOM (so Excel on Windows opens it correctly — a small detail that signals someone has actually shipped a CSV before).
- Column order follows `FieldDefinition.order`. Header row uses field labels.
- Delivered as a `FileDocument` via `ShareLink`, so the user gets the whole system share sheet: Files, Mail, Drive, AirDrop, anything.
- **Export is the paywall gate.** See `06-revenuecat-spec.md`.

## 3. Concurrency model

Swift 6 language mode, strict concurrency checking on. No exceptions, no `@unchecked Sendable`.

| Component | Isolation |
|---|---|
| Views, view models | `@MainActor`, `@Observable` |
| `ExtractionCoordinator` | `actor` |
| `RecognitionService` | `actor` (Vision requests are expensive; serialise per page, cap parallelism at 2) |
| `StructuredExtractor` | `actor`, owns the `LanguageModelSession` |
| Normalization | free functions, pure, no isolation |
| SwiftData writes | `@ModelActor` background context |
| `EntitlementService` | `@MainActor` (`@Observable`, drives UI directly) |

Rule: **nothing framework-typed crosses an isolation boundary.** `CGImage` goes in, our own `Sendable` DTOs come out.

## 4. Performance budgets

Treat these as acceptance criteria, not aspirations. Measure on the oldest device in the team's pool and record the numbers in the README.

| Operation | Budget | Notes |
|---|---|---|
| Camera dismiss → page persisted | < 300 ms | Must feel instant; do not process before persisting |
| Recognition, one page | < 1.5 s | Vision, on-device |
| Tier 1 extraction | < 100 ms | Pure Swift |
| Tier 2 extraction, one page | < 8 s hard timeout | Show a determinate-feeling progress state, not a spinner |
| Capture → reviewable result, printed form | < 3 s | The number the demo video lives or dies on |
| Dataset list, 1,000 records | 60 fps scroll | Fetch with `FetchDescriptor` limits; never load blobs in the list |
| CSV export, 1,000 records | < 1 s | Stream, do not build one giant `String` |
| Cold launch to usable | < 1.2 s | Configure RevenueCat asynchronously; never block first paint on it |

If Tier 2 pushes past 8 seconds on the target device, cut the model pass out of the *demo path* (run Tier 1 only for printed forms) rather than cutting the feature. A fast, honest demo beats a slow, clever one.

## 5. Error taxonomy

One error type, exhaustive, each case owning its user-facing copy. No `NSError` leaking to the UI, no error string built at the call site.

```swift
enum CarbonError: Error, Equatable {
    case cameraUnavailable
    case cameraPermissionDenied
    case pageWriteFailed(underlying: String)
    case recognitionFailed(pageIndex: Int)
    case noTableFound                    // table-mode template, no table on page
    case noFieldsMatched                 // nothing recognisable — likely wrong template
    case modelUnavailable(reason: ModelUnavailableReason)
    case modelTimedOut
    case exportFailed(underlying: String)
    case templateLimitReached            // meter, not an error — routes to paywall
    case recordLimitReached              // meter, not an error — routes to paywall
}
```

Copy rules, per the design skill: state what happened and what to do, in the interface's voice, no apology, never vague.

- `noTableFound` → **"No table found on this page."** / "This template expects a table. Try a straighter photo, or switch the template to single-record mode."
- `noFieldsMatched` → **"Nothing matched this template."** / "This may be a different form. Choose another template, or scan again."
- `modelUnavailable` → not an error dialog at all. A single line in Settings. Extraction continues.
- `templateLimitReached` / `recordLimitReached` → never an alert. These present the paywall.

## 6. Privacy posture

This is a genuine differentiator, so it must be true and it must be stated precisely.

- Photographs, extracted text, and records **never leave the device**. There is no upload endpoint in the codebase.
- Recognition and extraction are on-device Apple frameworks.
- The only outbound traffic is the RevenueCat SDK. Say so, by name, in Settings and in the README.
- No analytics SDK in v1. If one is added later, it must not carry field content — declare that rule now, in `CLAUDE.md`.
- Scan images live in the app container's Application Support directory, excluded from iCloud backup by default (`isExcludedFromBackupKey`), with a Settings toggle to include them.
- Fill in Privacy Manifest / nutrition-label answers honestly: no data collected, no tracking.

## 7. Degradation matrix

| Condition | Behaviour |
|---|---|
| No camera (simulator) | Photo-library import path, plus a bundled sample form so the app is explorable on a simulator. **A judge may well run this on a simulator — this row is load-bearing.** |
| Camera permission denied | Empty state with a Settings deep link |
| Apple Intelligence unavailable / unsupported region / disabled | Tier 1 → Tier 3 only; note in Settings; app fully usable |
| `RecognizeDocumentsRequest` unavailable | Fall back to `RecognizeTextRequest` + our own row grouping by y-frame clustering. Lower quality, still functional. Keep this code even if unused — it is the honest fallback and it is cheap. |
| No network | Everything works. RevenueCat serves cached `CustomerInfo`; entitlement state persists. |
| RevenueCat unreachable on first launch | Treat as free tier, do not block the app, retry in background. **Never** hard-gate app entry on a network call. |
| Zero templates | Onboarding empty state that creates the first template |

## 8. What is deliberately not in the design

No sync engine, no conflict resolution, no server, no auth, no push, no background processing, no widget, no macOS target. Each of these is a day or more and none appears in a 2-minute video. They are listed as future work in the README, which is the correct place for them.
