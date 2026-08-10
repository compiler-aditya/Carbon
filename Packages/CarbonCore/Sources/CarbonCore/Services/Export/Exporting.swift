import Foundation

/// Renders records as a file the user can take somewhere else.
///
/// Column order follows the template's field order and the header row uses field labels,
/// while the underlying keys stay frozen — a renamed label must not break someone's
/// downstream spreadsheet formulas.
public protocol Exporting: Sendable {
    func csv(records: [RecordSnapshot], template: TemplateSnapshot) throws -> Data
}
