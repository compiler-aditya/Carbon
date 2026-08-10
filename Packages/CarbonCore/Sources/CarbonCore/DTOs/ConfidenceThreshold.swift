/// The confidence cutoffs, in one place, so the pipeline and the UI cannot disagree about
/// what "needs review" means. Nothing anywhere else should compare a confidence to a literal.
public enum ConfidenceThreshold {
    /// At or above this, the value read cleanly and needs no attention.
    public static let high = 0.85

    /// At or above this but below `high`, the value is worth a glance.
    public static let medium = 0.60

    /// Below this, the value needs the user. Same number as `medium`, named for intent:
    /// call sites that ask "must this be reviewed?" should not read `medium`.
    public static let reviewRequired = 0.60
}
