import Foundation
import FoundationModels

/// Tier 2 against Apple's on-device model, text only.
///
/// The schema is built at runtime with `DynamicGenerationSchema` rather than the `@Generable`
/// macro, because a macro needs the shape at compile time and Carbon's fields are declared by
/// the user in the app. See `docs/02-system-design.md` Stage 2.
public actor FoundationModelResolver: ModelFieldResolving {
    private let availability: ModelAvailability
    private let timeout: Duration
    private let maximumResponseTokens: Int

    /// Cached per template, because rebuilding a schema for every page of the same register
    /// is measurable waste.
    private var schemaCache: [UUID: GenerationSchema] = [:]

    public init(
        availability: ModelAvailability = ModelAvailability(),
        timeout: Duration = .seconds(8),
        maximumResponseTokens: Int = 512
    ) {
        self.availability = availability
        self.timeout = timeout
        self.maximumResponseTokens = maximumResponseTokens
    }

    public func resolve(
        fields: [FieldSnapshot],
        pageText: String,
        template: TemplateSnapshot
    ) async throws -> [String: String] {
        guard !fields.isEmpty, !pageText.isEmpty else { return [:] }

        let state = await availability.state()
        guard case .available = state else {
            throw CarbonError.modelUnavailable(reason: unavailableReason(state))
        }

        let schema = try cachedSchema(for: fields, template: template)
        let prompt = Self.prompt(pageText: pageText, fields: fields)

        // One session per page. The deadline is the tier's whole budget — past it the ladder
        // has a perfectly good answer without the model, and a user waiting on a scan is not
        // served by waiting longer.
        let session = LanguageModelSession(instructions: Self.instructions)
        let options = GenerationOptions(
            temperature: 0,  // A form has one right answer; creativity is not wanted here.
            maximumResponseTokens: maximumResponseTokens
        )

        let content: GeneratedContent
        do {
            content = try await withTimeout(timeout) {
                try await session.respond(to: prompt, schema: schema, options: options).content
            }
        } catch is TimedOutError {
            throw CarbonError.modelTimedOut
        }

        return Self.values(from: content, fields: fields)
    }

    // MARK: Schema

    private func cachedSchema(
        for fields: [FieldSnapshot],
        template: TemplateSnapshot
    ) throws -> GenerationSchema {
        if let cached = schemaCache[template.id] { return cached }
        let built = try Self.makeSchema(fields: fields)
        schemaCache[template.id] = built
        return built
    }

    static func makeSchema(fields: [FieldSnapshot]) throws -> GenerationSchema {
        let properties = fields.map { field -> DynamicGenerationSchema.Property in
            let valueSchema =
                field.choices.isEmpty
                ? DynamicGenerationSchema(type: String.self)
                : DynamicGenerationSchema(name: field.key, anyOf: field.choices)

            return DynamicGenerationSchema.Property(
                name: field.key,
                description: description(of: field),
                schema: valueSchema,
                // A field genuinely absent from the page is the common case. A schema that
                // demands a value is a schema that invites an invented one.
                isOptional: true
            )
        }

        return try GenerationSchema(
            root: DynamicGenerationSchema(name: "FormFields", properties: properties),
            dependencies: []
        )
    }

    /// What the model is told each field means. The user's own label plus its declared type,
    /// because "Amount, a currency amount" places a value that "amount" alone does not.
    static func description(of field: FieldSnapshot) -> String {
        let kind =
            switch field.type {
            case .date: "a date"
            case .time: "a time of day"
            case .integer: "a whole number"
            case .decimal: "a number"
            case .currency: "a money amount, digits only"
            case .phone: "a phone number"
            case .boolean: "yes or no"
            case .choice: "one of the listed options"
            case .identifier: "an identifier code, copied exactly"
            case .text: "text"
            }
        return "\(field.label) — \(kind)"
    }

    // MARK: Prompt

    static let instructions = """
        You read text transcribed from a photographed paper form and report the values of \
        named fields.

        Rules:
        - Copy values exactly as they appear. Do not reformat, correct spelling, or convert units.
        - If a field does not appear on the page, omit it. Never guess and never invent a value.
        - Report only the value, not the field's printed label.
        """

    static func prompt(pageText: String, fields: [FieldSnapshot]) -> String {
        """
        Form text:
        \(pageText)

        Report these fields: \(fields.map(\.label).joined(separator: ", ")).
        """
    }

    // MARK: Reading the answer

    static func values(from content: GeneratedContent, fields: [FieldSnapshot]) -> [String: String] {
        var resolved: [String: String] = [:]
        for field in fields {
            // `try?` flattens the optional the schema declares, so an absent property and a
            // null one both arrive as nil — which is the same thing to us: Tier 3.
            guard
                let value = try? content.value(String?.self, forProperty: field.key),
                !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }
            resolved[field.key] = value
        }
        return resolved
    }

    private func unavailableReason(_ state: ModelAvailability.State) -> ModelUnavailableReason {
        if case .unavailable(let reason) = state { return reason }
        return .deviceNotEligible
    }
}
