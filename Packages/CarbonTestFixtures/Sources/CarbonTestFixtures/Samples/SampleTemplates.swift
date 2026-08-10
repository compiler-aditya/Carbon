import CarbonCore
import Foundation

/// The two starter templates offered in onboarding, as snapshots.
///
/// Deterministic identifiers so a preview, a test and a fixture all refer to the same
/// template across runs. Realistic content throughout — a screenshot or a video frame
/// containing "Test Item 1" costs more than a missing feature.
public enum SampleTemplates {
    public static let dailyRegisterID = UUID(uuidString: "1A15E9E0-0000-4000-A000-000000000001")!
    public static let intakeFormID = UUID(uuidString: "1A15E9E0-0000-4000-A000-000000000002")!

    /// Table mode: one photographed page becomes one record per ruled row.
    public static var dailyRegister: TemplateSnapshot {
        TemplateSnapshot(
            id: dailyRegisterID,
            name: "Daily Register",
            mode: .table,
            dateConvention: .dayMonthYear,
            preferredDateFormat: nil,
            fields: [
                field(key: "date", label: "Date", type: .date, order: 0, aliases: ["dt"]),
                field(key: "item", label: "Item", type: .text, order: 1, aliases: ["particulars", "description"]),
                field(key: "quantity", label: "Quantity", type: .integer, order: 2, aliases: ["qty", "nos"]),
                field(key: "rate", label: "Rate", type: .currency, order: 3, aliases: ["rate/unit", "price"], currency: "INR"),
                field(key: "amount", label: "Amount", type: .currency, order: 4, aliases: ["amt", "total"], currency: "INR"),
            ],
            learnedHeaderAliases: []
        )
    }

    /// Record mode: one photographed page becomes exactly one record.
    public static var intakeForm: TemplateSnapshot {
        TemplateSnapshot(
            id: intakeFormID,
            name: "Intake Form",
            mode: .record,
            dateConvention: .dayMonthYear,
            preferredDateFormat: nil,
            fields: [
                field(key: "name", label: "Name", type: .text, order: 0, aliases: ["full name"]),
                field(key: "date", label: "Date", type: .date, order: 1),
                field(key: "phone", label: "Phone", type: .phone, order: 2, aliases: ["mobile", "contact"]),
                field(
                    key: "visit_type",
                    label: "Visit type",
                    type: .choice,
                    order: 3,
                    choices: ["New", "Follow-up", "Emergency"]
                ),
                field(key: "notes", label: "Notes", type: .text, order: 4),
            ],
            learnedHeaderAliases: []
        )
    }

    public static var all: [TemplateSnapshot] { [dailyRegister, intakeForm] }

    private static func field(
        key: String,
        label: String,
        type: FieldType,
        order: Int,
        aliases: [String] = [],
        choices: [String] = [],
        currency: String? = nil
    ) -> FieldSnapshot {
        FieldSnapshot(
            // Derived from the key so the same field has the same id every run.
            id: UUID(uuidString: "F1E1D000-0000-4000-A000-\(String(format: "%012d", abs(key.hashValue % 1_000_000_000_000)))")
                ?? UUID(),
            key: key,
            label: label,
            type: type,
            isRequired: order == 0,
            aliases: ([label] + aliases).map { $0.lowercased() },
            choices: choices,
            defaultValue: nil,
            currencyCode: currency,
            validationPattern: nil,
            lastKnownFrame: nil
        )
    }
}
