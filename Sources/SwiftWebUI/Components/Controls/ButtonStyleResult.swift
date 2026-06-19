import SwiftHTML

struct ButtonStyleResult: Sendable {
    var classNames: [String]
    var style: Style

    init(
        classNames: [String] = [],
        style: Style = Style()
    ) {
        self.classNames = classNames
        self.style = style
    }
}
