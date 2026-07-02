public extension HTMLAttribute {
    static func action<Input: Codable & Sendable, Output: Sendable>(
        _ reference: ActionReference<Input, Output>
    ) -> HTMLAttribute {
        .action(reference.path)
    }
}
