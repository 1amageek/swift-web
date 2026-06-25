import SwiftHTML

public struct ControlSizeModifier: ComponentModifier {
    private let size: ControlSize

    init(_ size: ControlSize) {
        self.size = size
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        content.environment(ControlSizeEnvironmentKey.self, size)
    }
}
