import SwiftHTML

public struct StyleResolutionContext: Sendable {
    public let theme: Theme
    public let designStyle: DesignStyle
    public let colorScheme: ColorScheme
    public let layoutDirection: LayoutDirection
    public let controlState: ControlState

    public init(
        theme: Theme,
        designStyle: DesignStyle,
        colorScheme: ColorScheme,
        layoutDirection: LayoutDirection,
        controlState: ControlState
    ) {
        self.theme = theme
        self.designStyle = designStyle
        self.colorScheme = colorScheme
        self.layoutDirection = layoutDirection
        self.controlState = controlState
    }
}
