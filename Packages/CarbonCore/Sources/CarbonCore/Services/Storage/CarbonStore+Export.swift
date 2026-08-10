import Foundation
import SwiftData

extension CarbonStore {
    /// Records a completed export.
    ///
    /// Called only after the file has actually been produced. Logging the intent rather than
    /// the outcome would make the Settings history a record of attempts, which is not what
    /// anybody means by "12 exports".
    public func logExport(
        templateID: UUID,
        format: ExportFormat = .csv,
        recordCount: Int,
        fileName: String,
        at date: Date = .now
    ) throws {
        let log = ExportLog()
        log.templateID = templateID
        log.format = format
        log.recordCount = recordCount
        log.fileName = fileName
        log.createdAt = date
        modelContext.insert(log)
        try modelContext.save()
    }

    public func exportSummary() throws -> ExportSummary {
        let logs = try modelContext.fetch(
            FetchDescriptor<ExportLog>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
        guard !logs.isEmpty else { return .empty }

        return ExportSummary(
            exportCount: logs.count,
            recordCount: logs.reduce(0) { $0 + $1.recordCount },
            lastExportedAt: logs.first?.createdAt
        )
    }
}
