import SwiftHTML

public struct ButtonStyleResult: Sendable {
    public var classNames: [String]
    public var style: Style

    public init(
        classNames: [String] = [],
        style: Style = Style()
    ) {
        self.classNames = classNames
        self.style = style
    }
}
