import SwiftHTML

public struct ActionMetadataFields<Input: Codable & Sendable, Output: Sendable>: Component, Sendable {
    private let reference: ActionReference<Input, Output>

    public init(_ reference: ActionReference<Input, Output>) {
        self.reference = reference
    }

    @HTMLBuilder
    public var body: some HTML {
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
