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

/// Why the paywall is being shown. Drives the paywall's context line, so the user sees a
/// reason rather than an unexplained wall.
public enum PaywallReason: String, Sendable, Hashable, CaseIterable {
    case templateLimit
    case recordLimit
    case export
}
