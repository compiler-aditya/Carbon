import Foundation

/// Model → snapshot conversion, in one file, in one direction only.
///
/// There is deliberately no generic mapper back the other way. Writing an `ExtractionResult`
/// into the store is done explicitly by the write actor, because that path has to decide
/// things a mapper cannot: which values are new, which are corrections, and what must not be
/// touched. Generic two-way mapping is where a codebase of this shape goes wrong.

extension NormalizedRect {
    /// Decodes a persisted frame. A frame that cannot be read is simply absent — a broken
    /// zoom target must never take a record down with it.
    static func decode(fromJSON json: String?) -> NormalizedRect? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(NormalizedRect.self, from: data)
    }

    public var jsonString: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension FieldDefinition {
    /// Needs the template's learned aliases, which live on the parent, so this is a function
    /// rather than a property.
    public func snapshot(learnedAliases: [String]) -> FieldSnapshot {
        FieldSnapshot(
            id: id,
            key: key,
            label: label,
            type: type,
            isRequired: isRequired,
            aliases: matchingAliases(learned: learnedAliases),
            choices: choices,
            defaultValue: defaultValue.nilWhenEmpty,
            currencyCode: currencyCode.nilWhenEmpty,
            validationPattern: validationPattern.nilWhenEmpty,
            lastKnownFrame: NormalizedRect.decode(fromJSON: lastKnownFrameJSON)
        )
    }
}

extension FormTemplate {
    public var snapshot: TemplateSnapshot {
        TemplateSnapshot(
            id: id,
            name: name,
            mode: mode,
            dateConvention: dateConvention,
            preferredDateFormat: preferredDateFormat.nilWhenEmpty,
            fields: orderedFields.map { $0.snapshot(learnedAliases: learnedHeaderAliases) },
            learnedHeaderAliases: learnedHeaderAliases,
            subtitle: subtitle,
            symbolName: symbolName,
            lastUsedAt: lastUsedAt,
            recordCount: recordCount
        )
    }
}

extension FieldValue {
    public var snapshot: FieldValueSnapshot {
        FieldValueSnapshot(
            id: id,
            fieldKey: fieldDefinition?.key ?? "",
            rawText: rawText,
            normalizedValue: normalizedValue,
            confidence: confidence,
            source: source,
            wasEditedByUser: wasEditedByUser,
            frame: NormalizedRect.decode(fromJSON: frameJSON)
        )
    }
}

extension CaptureRecord {
    public var snapshot: RecordSnapshot {
        RecordSnapshot(
            id: id,
            capturedAt: capturedAt,
            status: status,
            sourceRowIndex: sourceRowIndex,
            values: (values ?? []).map(\.snapshot),
            engineVersion: engineVersion,
            extractionDurationMs: extractionDurationMs,
            modelWasAvailable: modelWasAvailable
        )
    }
}

extension String {
    /// An empty stored attribute means "not set". The models default to "" for CloudKit
    /// compatibility, and the snapshots express absence honestly as nil.
    fileprivate var nilWhenEmpty: String? { isEmpty ? nil : self }
}
