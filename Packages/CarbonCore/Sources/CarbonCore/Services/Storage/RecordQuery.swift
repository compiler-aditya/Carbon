import Foundation

/// Which records the dataset screen is asking for.
public enum RecordFilter: String, Sendable, Hashable, CaseIterable {
    case all
    case needsReview
    case confirmed
}

/// How to order them.
public enum RecordSort: Sendable, Hashable {
    case newest
    case oldest

    /// By one field's value. Applied after fetching, because a sort key that lives on a
    /// to-many relationship is not something a fetch descriptor can order by.
    case field(key: String)
}

/// One dataset query. Grouped into a value so the screen passes a single thing and the store
/// has one method rather than an argument list that grows every time the UI gains a control.
public struct RecordQuery: Sendable, Hashable {
    public var templateID: UUID
    public var filter: RecordFilter
    public var searchText: String
    public var sort: RecordSort
    public var limit: Int?
    public var offset: Int

    public init(
        templateID: UUID,
        filter: RecordFilter = .all,
        searchText: String = "",
        sort: RecordSort = .newest,
        limit: Int? = nil,
        offset: Int = 0
    ) {
        self.templateID = templateID
        self.filter = filter
        self.searchText = searchText
        self.sort = sort
        self.limit = limit
        self.offset = offset
    }
}
