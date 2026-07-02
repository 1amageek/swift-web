import SwiftWebUITheme
import SwiftHTML

public struct DisabledModifier: ComponentModifier {
    private let isDisabled: Bool

    @Environment(\.isEnabled) private var isEnabled: Bool
    @Environment(\.controlState) private var controlState: ControlState

    init(_ isDisabled: Bool) {
        self.isDisabled = isDisabled
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        // SwiftUI composes `disabled(_:)` with AND semantics: a descendant
        // `.disabled(false)` cannot re-enable a subtree an ancestor disabled.
        let resolvedIsEnabled = isEnabled && !isDisabled
        content
            .environment(\.isEnabled, resolvedIsEnabled)
            .environment(\.controlState, ControlState(
                isEnabled: resolvedIsEnabled,
                isPressed: controlState.isPressed,
                isFocused: controlState.isFocused,
                isSelected: controlState.isSelected
            ))
    }
}
