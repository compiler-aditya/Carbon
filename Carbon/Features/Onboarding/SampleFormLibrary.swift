import CarbonCore
import CoreGraphics
import Foundation
import ImageIO

/// The two starter forms that ship with the app.
///
/// These exist so Carbon is fully explorable with no camera and no photo library — which is
/// very likely how it is first opened by someone who did not build it. One tap creates the
/// template, runs the real pipeline over a real bundled image, and lands on the review screen
/// with real extracted values. Nothing is faked along the way; the only thing supplied is the
/// photograph.
enum SampleFormLibrary {
    struct Sample: Identifiable, Sendable {
        let id: String
        let name: String
        let subtitle: String
        let symbolName: String
        let mode: TemplateMode
        let imageName: String
        let fields: [NewFieldSpec]
    }

    static let all: [Sample] = [dailyRegister, intakeForm]

    /// Table mode: one photograph becomes a row per ruled line.
    static let dailyRegister = Sample(
        id: "daily-register",
        name: "Daily Register",
        subtitle: "Shop sales, one row per line",
        symbolName: "tablecells",
        mode: .table,
        imageName: "daily-register",
        fields: [
            NewFieldSpec(label: "Date", type: .text),
            NewFieldSpec(label: "Item", type: .text, columnAliases: ["particulars", "description"]),
            NewFieldSpec(label: "Qty", type: .integer, columnAliases: ["quantity", "nos"]),
            NewFieldSpec(label: "Rate", type: .currency, columnAliases: ["price", "rate/unit"]),
            NewFieldSpec(label: "Amount", type: .currency, columnAliases: ["amt", "total"]),
        ]
    )

    /// Record mode: one photograph becomes one row.
    static let intakeForm = Sample(
        id: "intake-form",
        name: "Intake Form",
        subtitle: "One visitor per page",
        symbolName: "doc.text",
        mode: .record,
        imageName: "intake-form",
        fields: [
            NewFieldSpec(label: "Name", type: .text),
            NewFieldSpec(label: "Date", type: .text),
            NewFieldSpec(label: "Phone", type: .phone, columnAliases: ["mobile", "contact"]),
            NewFieldSpec(
                label: "Visit type",
                type: .choice,
                choices: ["New", "Follow-up", "Emergency"]
            ),
            NewFieldSpec(label: "Notes", type: .text),
        ]
    )

    /// Loads the bundled photograph.
    ///
    /// Returns nil rather than trapping if it is missing: a stripped build should offer a
    /// duller first run, not a crash on launch.
    static func image(for sample: Sample) -> CGImage? {
        guard
            let url = Bundle.main.url(forResource: sample.imageName, withExtension: "jpg"),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static var isAvailable: Bool {
        all.allSatisfy { Bundle.main.url(forResource: $0.imageName, withExtension: "jpg") != nil }
    }
}
