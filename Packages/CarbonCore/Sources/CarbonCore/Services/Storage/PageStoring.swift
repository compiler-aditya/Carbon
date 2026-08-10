import CoreGraphics
import Foundation

/// Writes scanned pages to disk and reads them back.
///
/// Pages are persisted **before** any processing begins. A crash mid-extraction must never
/// lose the user's photograph — they cannot re-photograph a register page they have already
/// filed. This is a hard requirement, not a nicety.
public protocol PageStoring: Sendable {
    @discardableResult
    func persist(_ image: CGImage, captureID: UUID, pageIndex: Int) async throws -> PageRef

    func load(_ ref: PageRef) async throws -> CGImage

    func delete(_ ref: PageRef) async throws

    /// Removes every page of one capture. Called once nothing references it — in table mode
    /// several records share a single photograph, so the last one out deletes it.
    func deleteAll(captureID: UUID) async throws

    /// Total bytes on disk, for the Storage section in Settings. The user is shown the number
    /// and decides — v1 never auto-purges someone's source images.
    func totalBytes() async throws -> Int
}
