import CarbonCore
import Foundation

/// The corpus's own description of the forms in it.
///
/// A corpus directory holds `<formtype>_<collector>_<nn>.jpg` alongside a matching `.json` of
/// hand-typed ground truth, plus one `manifest.json` declaring a template per form type. The
/// harness needs the template because extraction is meaningless without one — measuring
/// Carbon means measuring it doing the thing it actually does.
public struct CorpusManifest: Codable, Sendable {
    public let templates: [CorpusTemplate]

    public func template(forType formType: String) -> CorpusTemplate? {
        templates.first { $0.formType == formType }
    }
}

public struct CorpusTemplate: Codable, Sendable {
    public let formType: String
    public let name: String
    public let mode: TemplateMode
    public var dateConvention: DateConvention?
    public let fields: [CorpusField]

    public func snapshot() -> TemplateSnapshot {
        TemplateSnapshot(
            id: UUID(),
            name: name,
            mode: mode,
            dateConvention: dateConvention ?? .dayMonthYear,
            preferredDateFormat: nil,
            fields: fields.map { $0.snapshot() },
            learnedHeaderAliases: []
        )
    }
}

public struct CorpusField: Codable, Sendable {
    public let key: String
    public let label: String
    public let type: FieldType
    public var aliases: [String]?
    public var choices: [String]?

    public func snapshot() -> FieldSnapshot {
        FieldSnapshot(
            id: UUID(),
            key: key,
            label: label,
            type: type,
            isRequired: false,
            aliases: ([label] + (aliases ?? [])).map { $0.lowercased() },
            choices: choices ?? [],
            defaultValue: nil,
            currencyCode: nil,
            validationPattern: nil,
            lastKnownFrame: nil
        )
    }
}

/// What a collector typed in by hand after photographing a page.
///
/// In table mode there is one entry per ruled row, in page order. In record mode there is
/// exactly one.
public struct GroundTruth: Codable, Sendable {
    public let formType: String
    public let records: [[String: String]]

    /// Set by the collector when the page is deliberately hard — shadow, glare, skew, crease,
    /// low light. Lets the report separate "handwriting is hard" from "we broke something".
    public var conditions: [String]?

    /// Whether the values were handwritten. The headline number is far more interesting split
    /// this way, and the README reports the two separately.
    public var isHandwritten: Bool?

    /// Set when the page was drawn by this repository rather than photographed.
    ///
    /// A rendered page has no camera in it — no skew, no shadow, no paper texture, no lens —
    /// so scoring against one measures the harness and the pipeline, never accuracy. Defaults
    /// to false, because a page someone actually collected is the normal case and should not
    /// have to declare itself.
    public var isRendered: Bool?
}
