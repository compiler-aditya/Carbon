import CarbonCore
import Foundation

/// Joins values with commas without any RFC-4180 quoting.
///
/// Correct CSV is the real exporter's job and has its own tests. This one exists so an export
/// sheet can render a row count and a file size in a preview without pulling in the real
/// implementation.
public struct FakeExporter: Exporting {
    private let failureToThrow: (any Error)?

    public init(failureToThrow: (any Error)? = nil) {
        self.failureToThrow = failureToThrow
    }

    public func csv(records: [RecordSnapshot], template: TemplateSnapshot) throws -> Data {
        if let failureToThrow { throw failureToThrow }
        let header = template.fields.map(\.label).joined(separator: ",")
        let rows = records.map { record in
            template.fields.map { record.exportValue(forKey: $0.key) }.joined(separator: ",")
        }
        return Data(([header] + rows).joined(separator: "\r\n").utf8)
    }
}
