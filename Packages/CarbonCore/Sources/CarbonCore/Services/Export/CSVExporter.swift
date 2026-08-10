import Foundation

/// RFC 4180 CSV.
///
/// Column order follows the template's field order and the header uses field **labels**,
/// while the underlying keys stay frozen — the person opening this in a spreadsheet wants to
/// read "Amount", not "amount".
public struct CSVExporter: Exporting {
    public init() {}

    /// A byte-order mark, so Excel on Windows opens a UTF-8 file as UTF-8.
    ///
    /// Without it, Excel guesses the system codepage and a rupee sign or an accented name
    /// arrives as mojibake. Numbers and Sheets do not need it and are unharmed by it.
    private static let byteOrderMark = Data([0xEF, 0xBB, 0xBF])

    /// RFC 4180 says CRLF between records. Real parsers accept LF, but the spec says CRLF and
    /// nothing is gained by being clever here.
    private static let recordSeparator = Data([0x0D, 0x0A])

    public func csv(records: [RecordSnapshot], template: TemplateSnapshot) throws -> Data {
        var output = Data()
        // One allocation up front rather than a thousand small ones. Building a giant String
        // and converting at the end is what makes an export of a real dataset feel slow.
        output.reserveCapacity((records.count + 1) * template.fields.count * 16)

        output.append(Self.byteOrderMark)

        append(row: template.fields.map(\.label), to: &output)
        for record in records {
            append(row: template.fields.map { record.exportValue(forKey: $0.key) }, to: &output)
        }

        return output
    }

    private func append(row: [String], to output: inout Data) {
        for (index, field) in row.enumerated() {
            if index > 0 { output.append(0x2C) }  // comma
            output.append(Data(Self.escape(field).utf8))
        }
        output.append(Self.recordSeparator)
    }

    /// Quotes a field when it must be quoted, and doubles any quotes inside it.
    ///
    /// Leading and trailing spaces are quoted too. RFC 4180 treats them as part of the field,
    /// but plenty of readers trim unquoted whitespace, and a value the user deliberately
    /// wrote with a leading space should survive the trip.
    static func escape(_ field: String) -> String {
        let mustQuote = field.contains { character in
            character == "," || character == "\"" || character == "\n" || character == "\r"
        } || field.hasPrefix(" ") || field.hasSuffix(" ")

        guard mustQuote else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    /// A filename a person can recognise in their Files app a month later.
    public static func fileName(for template: TemplateSnapshot, date: Date = .now) -> String {
        let stamp = date.formatted(
            .iso8601.year().month().day().dateSeparator(.dash)
        )
        let safeName = template.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(safeName.isEmpty ? "Carbon" : safeName) \(stamp).csv"
    }
}
