import SwiftHTML

public struct DisabledModifier: ComponentModifier {
    private let isDisabled: Bool

    init(_ isDisabled: Bool) {
        self.isDisabled = isDisabled
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        content
            .environment(IsEnabledEnvironmentKey.self, !isDisabled)
            .environment(ControlStateEnvironmentKey.self, isDisabled ? .disabled : .enabled)
    }
}
