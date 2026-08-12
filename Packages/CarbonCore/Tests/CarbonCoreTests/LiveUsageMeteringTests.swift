import Foundation
import SwiftData
import Testing

@testable import CarbonCore

/// The persisted free-tier meter.
///
/// The behaviour that matters here is the one the in-memory fake could never have: a count
/// that is still there next launch. The app shipped for a week with the fake wired in, which
/// meant the record limit reset every time the app was opened.
@Suite("Metering: the persisted meter")
struct LiveUsageMeteringTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema.carbon,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func thisMonth() -> String {
        UsagePeriodSnapshot.periodKey(for: .now)
    }

    private func insertPeriod(
        key: String, records: Int, templates: Int = 0, into container: ModelContainer
    ) {
        let context = ModelContext(container)
        let period = UsagePeriod()
        period.periodKey = key
        period.recordsCreated = records
        period.templatesCreated = templates
        context.insert(period)
        try? context.save()
    }

    @Test("A count survives the meter that made it")
    func countsPersist() async throws {
        let container = try makeContainer()

        await LiveUsageMetering(modelContainer: container).recordCreated(count: 7)

        // A different instance over the same store: the next launch, in miniature.
        let reopened = LiveUsageMetering(modelContainer: container)
        #expect(await reopened.currentPeriod().recordsCreated == 7)
    }

    @Test("Counts accumulate across separate scans")
    func countsAccumulate() async throws {
        let container = try makeContainer()
        let meter = LiveUsageMetering(modelContainer: container)

        await meter.recordCreated(count: 7)
        await meter.recordCreated(count: 5)

        #expect(await meter.currentPeriod().recordsCreated == 12)
    }

    /// Rollover with no scheduled job: last month's row is simply a different key, so this
    /// month starts empty without anything having to run at midnight on the 1st.
    @Test("Last month's usage does not count against this month")
    func rollover() async throws {
        let container = try makeContainer()
        insertPeriod(key: "2020-01", records: FreeTierLimit.recordsPerPeriod, into: container)

        let meter = LiveUsageMetering(modelContainer: container)

        #expect(await meter.currentPeriod().recordsCreated == 0)
        #expect(await meter.canCreateRecords(count: 5, isPro: false) == .allowed)
    }

    @Test("A month with nothing in it reports zero rather than nothing")
    func emptyMonthReportsZero() async throws {
        let snapshot = await LiveUsageMetering(modelContainer: try makeContainer()).currentPeriod()

        #expect(snapshot.recordsCreated == 0)
        #expect(snapshot.periodKey == thisMonth())
    }

    @Test("The limit is enforced from what was actually persisted")
    func limitUsesPersistedCount() async throws {
        let container = try makeContainer()
        insertPeriod(key: thisMonth(), records: FreeTierLimit.recordsPerPeriod, into: container)

        let meter = LiveUsageMetering(modelContainer: container)
        #expect(await meter.canCreateRecords(count: 1, isPro: false) == .paywall(reason: .recordLimit))
    }

    /// The table-mode case the whole `.partial` decision exists for: a page of rows that
    /// crosses the limit part-way saves what fits instead of refusing the scan.
    @Test("A page that crosses the limit part-way is allowed the rows that fit")
    func partialSave() async throws {
        let container = try makeContainer()
        insertPeriod(key: thisMonth(), records: FreeTierLimit.recordsPerPeriod - 3, into: container)

        let meter = LiveUsageMetering(modelContainer: container)
        #expect(await meter.canCreateRecords(count: 14, isPro: false) == .partial(allowed: 3))
    }

    @Test("Pro is never metered, however full the month is")
    func proIsUnmetered() async throws {
        let container = try makeContainer()
        insertPeriod(key: thisMonth(), records: 500, into: container)

        let meter = LiveUsageMetering(modelContainer: container)
        #expect(await meter.canCreateRecords(count: 100, isPro: true) == .allowed)
        #expect(await meter.canCreateTemplate(existingCount: 99, isPro: true) == .allowed)
    }

    /// Templates are counted from the templates that exist, not from the period, so deleting
    /// one gives the slot back.
    @Test("The template limit follows what exists, not what was ever created")
    func templateLimitFollowsExistence() async throws {
        let meter = LiveUsageMetering(modelContainer: try makeContainer())

        await meter.templateCreated()
        await meter.templateCreated()

        #expect(await meter.currentPeriod().templatesCreated == 2)
        // Two were created this month, but none exist now — so one may be created.
        #expect(await meter.canCreateTemplate(existingCount: 0, isPro: false) == .allowed)
        #expect(
            await meter.canCreateTemplate(existingCount: 1, isPro: false)
                == .paywall(reason: .templateLimit)
        )
    }

    @Test("Recording nothing writes nothing")
    func zeroIsANoOp() async throws {
        let container = try makeContainer()
        let meter = LiveUsageMetering(modelContainer: container)

        await meter.recordCreated(count: 0)

        #expect(await meter.currentPeriod().recordsCreated == 0)
    }

    @Test("Only one row is ever kept for a month, however many scans it takes")
    func oneRowPerMonth() async throws {
        let container = try makeContainer()
        let meter = LiveUsageMetering(modelContainer: container)

        for _ in 0..<5 { await meter.recordCreated(count: 1) }

        let context = ModelContext(container)
        let periods = try context.fetch(FetchDescriptor<UsagePeriod>())
        #expect(periods.count == 1)
        #expect(periods.first?.recordsCreated == 5)
    }
}

/// The rules themselves, independent of where the count is kept. Both meters route through
/// these, which is what stops a preview disagreeing with the running app.
@Suite("Metering: the rules")
struct MeterDecisionTests {
    @Test("Under the limit is allowed")
    func underTheLimit() {
        #expect(MeterDecision.forRecords(count: 5, alreadyUsed: 0, isPro: false) == .allowed)
    }

    @Test("Exactly filling the limit is still allowed")
    func exactlyAtTheLimit() {
        let decision = MeterDecision.forRecords(
            count: 3, alreadyUsed: FreeTierLimit.recordsPerPeriod - 3, isPro: false
        )
        #expect(decision == .allowed)
    }

    @Test("One past the limit is the paywall, not a partial of zero")
    func oneTooMany() {
        let decision = MeterDecision.forRecords(
            count: 1, alreadyUsed: FreeTierLimit.recordsPerPeriod, isPro: false
        )
        #expect(decision == .paywall(reason: .recordLimit))
    }

    @Test("A meter somehow over its limit still refuses rather than offering a negative partial")
    func overCounted() {
        let decision = MeterDecision.forRecords(
            count: 1, alreadyUsed: FreeTierLimit.recordsPerPeriod + 10, isPro: false
        )
        #expect(decision == .paywall(reason: .recordLimit))
    }
}
