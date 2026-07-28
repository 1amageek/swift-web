import SwiftWebUITheme
import SwiftHTML

public struct ControlSizeModifier: ComponentModifier {
    private let size: ControlSize

    init(_ size: ControlSize) {
        self.size = size
    }

    @ComponentBuilder
    public func content(_ content: ModifierContent) -> some Component {
        content.transformEnvironment({ $0.controlSize = size })
    }
}
