/// Something Vision's data detectors recognised as structured — a date, a phone number,
/// an email address, a URL.
///
/// Used as a hint, never as an answer: a date detected anywhere on the page is weak evidence
/// for a date field, and it loses to a value found under the field's own label.
public struct DetectedDatum: Sendable, Codable, Hashable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case date
        case phoneNumber
        case emailAddress
        case url
        case postalAddress
    }

    public let kind: Kind
    public let text: String
    public let frame: NormalizedRect

    public init(kind: Kind, text: String, frame: NormalizedRect) {
        self.kind = kind
        self.text = text
        self.frame = frame
    }
}
