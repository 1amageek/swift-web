#if !hasFeature(Embedded)
// Server actions are a Codable JSON API boundary; the embedded SSR
// profile does not serve them.
public extension HTMLAttribute {
    static func action<Input: Codable & Sendable, Output: Sendable>(
        _ reference: ActionReference<Input, Output>
    ) -> HTMLAttribute {
        .action(reference.path)
    }
}
#endif
