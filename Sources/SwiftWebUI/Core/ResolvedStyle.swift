import SwiftHTML

public struct ResolvedStyle: Sendable {
    public var cssValue: String
    public var style: Style
    public var classNames: [String]

    public init(
        cssValue: String,
        style: Style = Style(),
        classNames: [String] = []
    ) {
        self.cssValue = cssValue
        self.style = style
        self.classNames = classNames
    }
}
