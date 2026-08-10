# Carbon — Data Model

SwiftData schema, storage strategy, and the `Sendable` snapshot layer. This is the file to get right on Day 1; every other file depends on these shapes.

**Store:** one local SwiftData `ModelContainer`, on-disk SQLite in the app container. No CloudKit in v1 — but the schema below is CloudKit-*compatible* (no unique constraints, all relationships optional, all non-optional attributes have defaults) so v1.1 can turn sync on without a migration. That is a five-minute decision now and a two-day rescue later.

---

## 1. Entity overview

```
FormTemplate 1 ──< FieldDefinition
      │
      └──< CaptureRecord 1 ──< FieldValue >── 1 FieldDefinition
                  │
                  └──< PageAsset

UsagePeriod   (standalone, one row per calendar month)
ExportLog     (standalone, audit trail)
```

Seven entities. Resist adding an eighth.

## 2. Enumerations

All `Codable`, `Sendable`, `CaseIterable`, with `String` raw values — **raw values are persisted, so never rename a case, only add.** Write that as a comment above each enum.

```swift
public enum TemplateMode: String, Codable, Sendable, CaseIterable {
    /// One page produces one record. An intake form, a job card.
    case record
    /// One page produces one record per detected table row. A register, a log sheet.
    case table
}

public enum FieldType: String, Codable, Sendable, CaseIterable {
    case text
    case integer
    case decimal
    case currency
    case date
    case time
    case boolean
    case choice
    case phone
    case identifier   // invoice no., roll no. — text, but never auto-corrected or spell-normalized
}

public enum ExtractionSource: String, Codable, Sendable {
    case deterministic   // Tier 1 — layout/header match
    case model           // Tier 2 — Foundation Models
    case userEntered     // typed or corrected by a human
    case unresolved      // Tier 3 — nothing found
    case defaultValue    // template default applied
}

public enum RecordStatus: String, Codable, Sendable {
    case draft         // mid-capture, not yet committed
    case needsReview   // at least one field below threshold or unresolved
    case confirmed     // user has reviewed, or all fields high-confidence
}

public enum DateConvention: String, Codable, Sendable, CaseIterable {
    case dayMonthYear
    case monthDayYear
    case yearMonthDay
}

public enum ExportFormat: String, Codable, Sendable {
    case csv           // v1
    case xlsx          // v1.1 — enum case reserved now, deliberately unimplemented
    case json          // v1.1
}
```

## 3. FormTemplate

The organising concept of the whole product. Everything hangs off a template.

```swift
@Model
public final class FormTemplate {
    // Identity — plain UUID, no .unique constraint (CloudKit compatibility)
    public var id: UUID = UUID()

    // Presentation
    public var name: String = ""
    public var subtitle: String = ""          // "Daily sales register", shown under the name
    public var symbolName: String = "doc.text" // SF Symbol chosen at creation
    public var accentHex: String = ""          // empty = use app accent

    // Behaviour
    public var modeRaw: String = TemplateMode.record.rawValue
    public var dateConventionRaw: String = DateConvention.dayMonthYear.rawValue
    public var preferredDateFormat: String = ""   // optional strftime-ish hint, tried first

    /// Header strings observed on real scans of this form, accumulated over time.
    /// Grows as users correct mismatches; improves Tier 1 matching for that template.
    public var learnedHeaderAliases: [String] = []

    // Lifecycle
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var lastUsedAt: Date?
    public var isArchived: Bool = false

    /// Reference scan used when creating the template. Shown in the editor as a guide.
    public var referencePageRef: String?

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \FieldDefinition.template)
    public var fields: [FieldDefinition]? = []

    @Relationship(deleteRule: .cascade, inverse: \CaptureRecord.template)
    public var records: [CaptureRecord]? = []

    public init() {}
}
```

**Notes for the implementer.**
- Enums are stored as `String` raw values with computed accessors (`var mode: TemplateMode { get set }`). SwiftData handles `RawRepresentable` in most cases, but storing the raw string and exposing a computed property is bulletproof across migrations and avoids a class of predicate problems. Do it this way.
- To-many relationships are `Optional` arrays with a `[]` default — required for CloudKit compatibility. Access through a non-optional computed helper (`var orderedFields: [FieldDefinition]`) so call sites stay clean and sorting is centralised.
- `learnedHeaderAliases` is the cheapest "intelligent feature" in the app: when a user corrects a mis-mapped column, append the observed header to the template. Tier 1 gets better with use, with no model involved. Mention this in the README — it is real product thinking that costs about twenty lines.

## 4. FieldDefinition

```swift
@Model
public final class FieldDefinition {
    public var id: UUID = UUID()

    /// Stable machine key, snake_case, used as the CSV column key and the App Intent parameter.
    /// Generated from `label` at creation, then frozen — renaming the label must not break exports.
    public var key: String = ""
    public var label: String = ""            // user-facing, editable
    public var order: Int = 0

    public var typeRaw: String = FieldType.text.rawValue
    public var isRequired: Bool = false

    /// Header synonyms to match against in table mode. Seeded from `label`, extended by
    /// `FormTemplate.learnedHeaderAliases` and by user corrections.
    public var columnAliases: [String] = []

    /// For .choice — the allowed values. Constrains the model via @Guide(.anyOf:).
    public var choices: [String] = []

    public var defaultValue: String = ""
    public var unitSuffix: String = ""       // "kg", "hrs" — display only, stripped on parse
    public var currencyCode: String = ""     // ISO 4217 for .currency

    /// Optional user-supplied regex the value must satisfy. Failure lowers confidence,
    /// it does not reject the value — never silently drop the user's data.
    public var validationPattern: String = ""

    /// Where on the page this field was found last time, normalised 0–1.
    /// A positional prior for label-anchored record-mode matching. Nil until first success.
    public var lastKnownFrameJSON: String?

    @Relationship public var template: FormTemplate?

    public init() {}
}
```

**Why `key` is frozen at creation:** exports go into the user's spreadsheets, and a renamed column silently breaks their downstream formulas. Label is presentation; key is contract. This is exactly the kind of distinction that reads as product maturity in a code review.

## 5. CaptureRecord

```swift
@Model
public final class CaptureRecord {
    public var id: UUID = UUID()

    public var capturedAt: Date = Date()
    public var statusRaw: String = RecordStatus.draft.rawValue

    /// Which table row on the source page this record came from. Nil in record mode.
    public var sourceRowIndex: Int?
    public var sourcePageIndex: Int = 0

    // Provenance — makes the corpus harness and the README accuracy numbers possible
    public var extractionDurationMs: Int = 0
    public var engineVersion: String = ""     // e.g. "vision-doc-1|fm-text-1|norm-3"
    public var modelWasAvailable: Bool = false

    /// Full reading-order OCR text of the source page. Kept for debugging and re-extraction.
    /// Purgeable — see §9.
    public var rawPageText: String = ""

    public var notes: String = ""

    @Relationship public var template: FormTemplate?

    @Relationship(deleteRule: .cascade, inverse: \FieldValue.record)
    public var values: [FieldValue]? = []

    @Relationship(deleteRule: .cascade, inverse: \PageAsset.record)
    public var pages: [PageAsset]? = []

    public init() {}
}
```

Add an index on the hot query path — dataset list is `records for template, newest first`:

```swift
#Index<CaptureRecord>([\.capturedAt], [\.statusRaw])
```

**Verified:** the macro exists in the installed SDK (Xcode 26.6 / iOS SDK 26.5) as `#Index<T>(_ indices: [PartialKeyPath<T>]...)`, so the form written above compiles as-is. The fallback reasoning still stands if it ever changes — an unindexed fetch is correct, just slower, and at our data volumes that is acceptable. Do not lose an hour here.

## 6. FieldValue

The most important entity in the model, because it is where honesty lives.

```swift
@Model
public final class FieldValue {
    public var id: UUID = UUID()

    /// Exactly what recognition produced, before normalization. NEVER overwritten,
    /// not even when the user corrects the value. This is what makes accuracy measurable.
    public var rawText: String = ""

    /// Canonical string form after normalization. All reads and exports use this.
    /// Stored as String rather than a typed union so the schema stays flat and CSV export
    /// is lossless; typed access is via `typedValue` computed from the FieldDefinition.
    public var normalizedValue: String = ""

    /// 0.0–1.0. Drives the confidence rule in the UI. 1.0 after a user edit.
    public var confidence: Double = 0
    public var sourceRaw: String = ExtractionSource.unresolved.rawValue

    public var wasEditedByUser: Bool = false
    public var editedAt: Date?

    /// Where on the page this value was read from, normalised 0–1. Enables tap-to-zoom
    /// on the source image from the review screen — a small feature that does a lot
    /// of work on camera, because it proves the app is reading the actual page.
    public var frameJSON: String?

    @Relationship public var record: CaptureRecord?
    @Relationship public var fieldDefinition: FieldDefinition?

    public init() {}
}
```

**The `rawText` rule is not optional.** Corrections are the accuracy dataset: `count(wasEditedByUser) / count(all)` is the correction rate, and `rawText != normalizedValue` on edited values tells you exactly what recognition got wrong. Fifty testers using the app for two days produces a real evaluation set for free. Overwrite `rawText` and that is gone.

## 7. PageAsset

```swift
@Model
public final class PageAsset {
    public var id: UUID = UUID()
    public var pageIndex: Int = 0

    /// Filename relative to Application Support/Scans/. NOT the image bytes.
    public var fileName: String = ""

    public var pixelWidth: Int = 0
    public var pixelHeight: Int = 0
    public var byteCount: Int = 0
    public var createdAt: Date = Date()

    @Relationship public var record: CaptureRecord?

    public init() {}
}
```

**Store images as files, not as SwiftData blobs.** `@Attribute(.externalStorage)` works, but files are easier to inspect while debugging, trivial to purge, trivial to export as an attachment bundle, and keep the store small enough that the dataset list stays at 60fps without care. The store holds a filename; the bytes live on disk.

Layout: `Application Support/Scans/<recordUUID>/<pageIndex>.jpg`, JPEG quality 0.8. Set `isExcludedFromBackupKey = true` on the `Scans` directory by default, with a Settings toggle. Deleting a `CaptureRecord` must delete its directory — cascade delete removes the `PageAsset` rows, but **SwiftData will not delete your files**. Wire a cleanup step into the delete path and unit-test it. This is the single most common source of orphaned data in apps of this shape.

## 8. UsagePeriod and ExportLog

```swift
@Model
public final class UsagePeriod {
    /// "2026-09". One row per calendar month, in the user's current calendar.
    public var periodKey: String = ""
    public var recordsCreated: Int = 0
    public var templatesCreated: Int = 0
    public var firstSeenAt: Date = Date()
    public init() {}
}

@Model
public final class ExportLog {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var templateID: UUID?
    public var formatRaw: String = ExportFormat.csv.rawValue
    public var recordCount: Int = 0
    public var fileName: String = ""
    public init() {}
}
```

**Be honest about the meter in the README:** it is local, so a determined user can reset it by reinstalling. That is an accepted v1 tradeoff — entitlement state is authoritative via RevenueCat, and the free meter is a courtesy limit, not DRM. Server-side metering (or RevenueCat Virtual Currencies) is the v1.1 answer. Stating this plainly is better engineering communication than pretending the limit is enforced.

`ExportLog` exists so Settings can show "12 exports, 486 records" — cheap, and it makes the app feel like it has a history.

**`UsagePeriod` never leaves the model layer.** It is a `@Model` and therefore not `Sendable`, so `UsageMetering` returns a `UsagePeriodSnapshot` instead — defined in `03-architecture.md` §2 alongside the protocol. Same rule as every other entity here; noted explicitly because this one is small enough that passing it directly looks harmless.

## 9. Retention

`rawPageText` and page images grow without bound. In Settings, offer **Storage**: total size, and "Delete scan images for confirmed records" (keeps the data, drops the pictures). Do not auto-purge in v1 — silently deleting a user's source images is the wrong default. Show the number and let them choose.

## 10. Snapshots — the Sendable layer

`@Model` classes are main-actor-bound reference types and are **not** `Sendable`. They must never cross into an actor or a service. Every service boundary takes a snapshot.

```swift
public struct TemplateSnapshot: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let mode: TemplateMode
    public let dateConvention: DateConvention
    public let preferredDateFormat: String?
    public let fields: [FieldSnapshot]        // pre-sorted by order
    public let learnedHeaderAliases: [String]
}

public struct FieldSnapshot: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let key: String
    public let label: String
    public let type: FieldType
    public let isRequired: Bool
    public let aliases: [String]              // label + columnAliases + learned, deduped, lowercased
    public let choices: [String]
    public let defaultValue: String?
    public let currencyCode: String?
    public let validationPattern: String?
    public let lastKnownFrame: NormalizedRect?
}

public struct ExtractionResult: Sendable {
    public let records: [ExtractedRecord]
    public let pageID: UUID
    public let durationMs: Int
    public let engineVersion: String
    public let diagnostics: [String]          // surfaced in a debug pane, not to users
}

public struct ExtractedRecord: Sendable {
    public let sourceRowIndex: Int?
    public let values: [ExtractedValue]
}

public struct ExtractedValue: Sendable {
    public let fieldKey: String
    public let rawText: String
    public let normalized: String
    public let confidence: Double
    public let source: ExtractionSource
    public let frame: NormalizedRect?
}

public struct NormalizedRect: Sendable, Codable, Hashable {
    public let x, y, width, height: Double    // 0–1, origin top-left
}
```

Conversion lives in one file, `Snapshots.swift`, as `extension FormTemplate { var snapshot: TemplateSnapshot }`. One direction only: models → snapshots. Writing back is done by the `@ModelActor` from `ExtractionResult`, explicitly, never by a generic mapper. Generic two-way mapping is where this kind of codebase goes wrong.

## 11. Confidence thresholds

Single source of truth, one file, so the UI and the pipeline cannot disagree:

```swift
public enum ConfidenceThreshold {
    public static let high = 0.85      // solid rule, no attention
    public static let medium = 0.60    // dashed rule, glance at it
    // below medium → dotted red rule, "needs review", focused first
    public static let reviewRequired = 0.60
}
```

A record is `.needsReview` if **any** value is below `reviewRequired` or has source `.unresolved`.

## 12. Migration

v1 ships schema version 1 and does not need a migration plan. Create the `SchemaMigrationPlan` scaffold anyway, empty, with `VersionedSchema` V1 registered:

```swift
enum CarbonSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        FormTemplate.self, FieldDefinition.self, CaptureRecord.self,
        FieldValue.self, PageAsset.self, UsagePeriod.self, ExportLog.self
    ]
}
```

Cost: fifteen minutes. Benefit: a reviewer sees the app was built expecting to survive its own next version, and the team can ship v1.1 without a data-loss incident.

## 13. Seed data

On first launch, create nothing silently. Instead, offer two starter templates in onboarding that the user can accept or skip — **Daily Register** (table mode: Date, Item, Quantity, Amount) and **Intake Form** (record mode: Name, Date, Phone, Notes). Ship a matching sample scan for each in `Resources/SampleForms/`.

This is what makes the app explorable on a simulator with no camera, which is very likely how a judge first opens it. Treat the sample forms as a submission requirement, not a nice-to-have.
