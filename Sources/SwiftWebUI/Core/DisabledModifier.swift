import SwiftHTML

public struct DisabledModifier: ComponentModifier {
    private let isDisabled: Bool

    init(_ isDisabled: Bool) {
        self.isDisabled = isDisabled
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        content
            .environment(\.isEnabled, !isDisabled)
            .environment(\.controlState, isDisabled ? .disabled : .enabled)
    }
}
