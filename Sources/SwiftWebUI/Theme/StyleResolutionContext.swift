import SwiftHTML

public struct StyleResolutionContext: Sendable {
    public let theme: Theme
    public let colorScheme: ColorScheme
    public let layoutDirection: LayoutDirection
    public let controlState: ControlState

    public init(
        theme: Theme,
        colorScheme: ColorScheme,
        layoutDirection: LayoutDirection,
        controlState: ControlState
    ) {
        self.theme = theme
        self.colorScheme = colorScheme
        self.layoutDirection = layoutDirection
        self.controlState = controlState
    }

    public static let `default` = StyleResolutionContext(
        theme: .default,
        colorScheme: .light,
        layoutDirection: .leftToRight,
        controlState: .enabled
    )
}
