extension ExtractionResult {
    /// The error to raise when a page produced nothing worth keeping, or nil when it did.
    ///
    /// A field left unresolved is a normal outcome and renders as a field waiting to be filled
    /// in — that rule is not touched here. This is the harder case: *nothing* on the page was
    /// read, which almost always means the wrong template rather than a bad photograph, and
    /// which the app previously handled by returning the user to the screen they started on
    /// with no records and no explanation.
    ///
    /// Table mode gets the more specific sentence when there was no table at all, because
    /// "no table found" tells someone to straighten the photo and "nothing matched" tells them
    /// to change template — different actions, and guessing wrong wastes their time.
    ///
    /// A blank form photographed in record mode also lands on `noFieldsMatched`. The sentence
    /// is a little off for that case, but the advice — scan again or pick another template —
    /// is not, and an empty record saved silently would be worse.
    public func emptyOutcome(for template: TemplateSnapshot) -> CarbonError? {
        guard !records.isEmpty else {
            return template.mode == .table ? .noTableFound : .noFieldsMatched
        }

        // A default the template declared is not something the page said. Neither is a field
        // Tier 3 gave up on. If that is all there is, no reading happened.
        let readSomethingOffThePage = records.contains { record in
            record.values.contains { value in
                value.source != .unresolved && value.source != .defaultValue
            }
        }
        return readSomethingOffThePage ? nil : .noFieldsMatched
    }
}
