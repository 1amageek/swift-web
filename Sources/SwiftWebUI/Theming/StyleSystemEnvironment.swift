import SwiftHTML

public struct StyleSystemEnvironmentKey: ClientEnvironmentKey {
    // Liquid Glass is SwiftWebUI's default surface treatment: materials render as
    // translucent glass with edge-lensing refraction unless a view opts into a
    // solid style (`.swiftWeb`).
    public static let defaultValue = StyleSystem.liquidGlass

    public init() {}
}

extension EnvironmentValues {
    public var styleSystem: StyleSystem {
        get { self[StyleSystemEnvironmentKey.self] }
        set { self[StyleSystemEnvironmentKey.self] = newValue }
    }
}
