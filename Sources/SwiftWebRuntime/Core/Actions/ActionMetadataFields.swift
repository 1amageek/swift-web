#if !hasFeature(Embedded)
// Server actions are a Codable JSON API boundary; the embedded SSR
// profile does not serve them.
import SwiftHTML

public struct ActionMetadataFields<Input: Codable & Sendable, Output: Sendable>: Component {
    private let reference: ActionReference<Input, Output>

    public init(_ reference: ActionReference<Input, Output>) {
        self.reference = reference
    }

    @ComponentBuilder
    public var content: some Component {
        for field in reference.fields {
            input(
                .type(InputType.hidden),
                .name(field.name),
                .value(field.value)
            )
        }
        for field in EnvironmentValues.swiftWebCurrent.actionHiddenFields {
            input(
                .type(InputType.hidden),
                .name(field.name),
                .value(field.value)
            )
        }
    }
}
#endif
