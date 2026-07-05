import SwiftHTML

public struct ThemeEnvironmentKey: ClientEnvironmentKey {
    // Liquid Glass is SwiftWebUI's default surface treatment: materials render as
    // translucent glass with edge-lensing refraction unless a view opts into a
    // solid style (`.swiftWeb`).
    public static let defaultValue = Theme.liquidGlass

    public init() {}
}

extension EnvironmentValues {
    public var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}
