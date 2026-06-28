import SwiftHTML

public struct StyleResolutionContext: Sendable {
    public let styleSystem: StyleSystem
    public let colorScheme: ColorScheme
    public let layoutDirection: LayoutDirection
    public let controlState: ControlState

    public init(
        styleSystem: StyleSystem,
        colorScheme: ColorScheme,
        layoutDirection: LayoutDirection,
        controlState: ControlState
    ) {
        self.styleSystem = styleSystem
        self.colorScheme = colorScheme
        self.layoutDirection = layoutDirection
        self.controlState = controlState
    }

    public static let `default` = StyleResolutionContext(
        styleSystem: .default,
        colorScheme: .light,
        layoutDirection: .leftToRight,
        controlState: .enabled
    )
}
