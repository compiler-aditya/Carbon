import CarbonCore
import Foundation

/// One field's worth of "did Carbon get it right?".
public struct FieldOutcome: Sendable, Hashable {
    public let fieldKey: String
    public let type: FieldType
    public let expected: String
    public let actual: String
    public let source: ExtractionSource

    public init(
        fieldKey: String, type: FieldType, expected: String, actual: String,
        source: ExtractionSource
    ) {
        self.fieldKey = fieldKey
        self.type = type
        self.expected = expected
        self.actual = actual
        self.source = source
    }

    /// Exact match on the normalized value.
    ///
    /// Deliberately strict. A near-match is still a value the user has to fix, and a metric
    /// that forgives near-misses would report an accuracy the correction editor contradicts.
    public var isCorrect: Bool { expected == actual }
}

/// One photograph's result.
public struct PageResult: Sendable {
    public let imageName: String
    public let isHandwritten: Bool

    /// Drawn by this repository rather than photographed. See `GroundTruth.isRendered`.
    public let isRendered: Bool
    public let expectedRecordCount: Int
    public let actualRecordCount: Int
    public let outcomes: [FieldOutcome]
    public let latency: Duration

    /// Grouped per record so "records needing a correction" can be counted honestly.
    public let outcomesByRecord: [[FieldOutcome]]

    public init(
        imageName: String,
        isHandwritten: Bool,
        isRendered: Bool = false,
        expectedRecordCount: Int,
        actualRecordCount: Int,
        outcomesByRecord: [[FieldOutcome]],
        latency: Duration
    ) {
        self.imageName = imageName
        self.isHandwritten = isHandwritten
        self.isRendered = isRendered
        self.expectedRecordCount = expectedRecordCount
        self.actualRecordCount = actualRecordCount
        self.outcomesByRecord = outcomesByRecord
        self.outcomes = outcomesByRecord.flatMap { $0 }
        self.latency = latency
    }

    /// A page where Carbon found a different number of rows than the collector typed.
    ///
    /// Counted and reported separately rather than folded into field precision, because a
    /// missed row is a different failure from a misread cell and the fixes are different.
    public var rowCountMatches: Bool { expectedRecordCount == actualRecordCount }
}

/// Everything the harness prints, and everything the README's accuracy table needs.
public struct CorpusReport: Sendable {
    public let pages: [PageResult]

    public init(pages: [PageResult]) {
        self.pages = pages
    }

    // MARK: The headline

    /// The share of records where **every** field was right.
    ///
    /// This is the number the README leads with, and it is the honest one: it is what a user
    /// experiences as "I didn't have to touch that row".
    public func recordsNeedingNoCorrection(handwritten: Bool? = nil) -> Double {
        let records = filtered(handwritten).flatMap(\.outcomesByRecord)
        guard !records.isEmpty else { return 0 }
        let clean = records.count { record in record.allSatisfy(\.isCorrect) }
        return Double(clean) / Double(records.count)
    }

    /// Share of individual values that were right.
    public func fieldPrecision(handwritten: Bool? = nil) -> Double {
        let outcomes = filtered(handwritten).flatMap(\.outcomes)
        guard !outcomes.isEmpty else { return 0 }
        return Double(outcomes.count(where: \.isCorrect)) / Double(outcomes.count)
    }

    /// Precision per field type — where the weak spots actually are. Dates and handwritten
    /// numbers behave very differently, and one blended number hides that.
    public func precisionByType(handwritten: Bool? = nil) -> [FieldType: Double] {
        let outcomes = filtered(handwritten).flatMap(\.outcomes)
        return Dictionary(grouping: outcomes, by: \.type).compactMapValues { group in
            group.isEmpty ? nil : Double(group.count(where: \.isCorrect)) / Double(group.count)
        }
    }

    /// What share of correct values Tier 1 produced on its own.
    ///
    /// The claim the architecture rests on: the deterministic path carries the load and the
    /// model handles the remainder. If this number is low, the ladder is not doing what the
    /// README says it does.
    public func tier1Share(handwritten: Bool? = nil) -> Double {
        let outcomes = filtered(handwritten).flatMap(\.outcomes)
        guard !outcomes.isEmpty else { return 0 }
        return Double(outcomes.count { $0.source == .deterministic }) / Double(outcomes.count)
    }

    public func unresolvedShare(handwritten: Bool? = nil) -> Double {
        let outcomes = filtered(handwritten).flatMap(\.outcomes)
        guard !outcomes.isEmpty else { return 0 }
        return Double(outcomes.count { $0.source == .unresolved }) / Double(outcomes.count)
    }

    public func rowCountAccuracy(handwritten: Bool? = nil) -> Double {
        let pages = filtered(handwritten)
        guard !pages.isEmpty else { return 0 }
        return Double(pages.count(where: \.rowCountMatches)) / Double(pages.count)
    }

    // MARK: Latency

    public func medianLatency(handwritten: Bool? = nil) -> Duration {
        percentileLatency(0.5, handwritten: handwritten)
    }

    public func p95Latency(handwritten: Bool? = nil) -> Duration {
        percentileLatency(0.95, handwritten: handwritten)
    }

    private func percentileLatency(_ percentile: Double, handwritten: Bool?) -> Duration {
        let sorted = filtered(handwritten).map(\.latency).sorted()
        guard !sorted.isEmpty else { return .zero }
        let index = min(sorted.count - 1, Int((Double(sorted.count - 1) * percentile).rounded()))
        return sorted[index]
    }

    // MARK: Worst cases

    /// The fields that went wrong most often, so "where it fails" in the README is specific
    /// rather than a shrug.
    public func mostMissedFields(limit: Int = 5) -> [(fieldKey: String, missRate: Double, count: Int)] {
        let outcomes = pages.flatMap(\.outcomes)
        return Dictionary(grouping: outcomes, by: \.fieldKey)
            .map { key, group in
                let misses = group.count { !$0.isCorrect }
                return (key, Double(misses) / Double(group.count), misses)
            }
            .filter { $0.2 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0 }
    }

    private func filtered(_ handwritten: Bool?) -> [PageResult] {
        guard let handwritten else { return pages }
        return pages.filter { $0.isHandwritten == handwritten }
    }
}
