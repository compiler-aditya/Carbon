/// The answer to "may this happen?".
///
/// **Never an error.** Hitting a free-tier limit is a normal outcome of using the app, and
/// the only correct response is to present the paywall in the context of the action the user
/// was taking. A decision that throws is a decision that ends up in an alert.
public enum MeterDecision: Sendable, Hashable {
    case allowed

    /// Present the paywall, in the context of what was attempted.
    case paywall(reason: PaywallReason)

    /// Some of the requested work fits under the limit and the rest does not. Table mode
    /// meeting the record limit mid-page lands here: save what fits, then show the paywall
    /// reporting exactly what happened. Honest partial success beats all-or-nothing refusal.
    case partial(allowed: Int)

    public var isAllowed: Bool { self == .allowed }
}

extension MeterDecision {
    /// The record rule, in one place.
    ///
    /// Both meters call this — the persisted one the app runs on and the in-memory one the
    /// previews and tests run on. They differ only in where the count is kept, and the moment
    /// they differ in what the count *means* is the moment a preview stops telling the truth
    /// about the paywall.
    public static func forRecords(count: Int, alreadyUsed: Int, isPro: Bool) -> MeterDecision {
        guard !isPro else { return .allowed }

        let remaining = FreeTierLimit.recordsPerPeriod - alreadyUsed
        if remaining <= 0 { return .paywall(reason: .recordLimit) }
        if count <= remaining { return .allowed }

        // Some of the page fits. Save those rows rather than refusing the whole scan.
        return .partial(allowed: remaining)
    }

    /// The template rule.
    ///
    /// Counted from the templates that actually exist rather than from the period, because a
    /// template deleted in March should not still be spending its slot in April.
    public static func forTemplate(existingCount: Int, isPro: Bool) -> MeterDecision {
        guard !isPro else { return .allowed }
        return existingCount < FreeTierLimit.templates ? .allowed : .paywall(reason: .templateLimit)
    }
}

/// Why the paywall is being shown. Drives the paywall's context line, so the user sees a
/// reason rather than an unexplained wall.
public enum PaywallReason: String, Sendable, Hashable, CaseIterable {
    case templateLimit
    case recordLimit
    case export
}
