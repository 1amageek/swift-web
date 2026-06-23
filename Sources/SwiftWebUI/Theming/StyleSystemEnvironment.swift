import SwiftHTML

struct StyleSystemEnvironmentKey: ClientEnvironmentKey {
    // Liquid Glass is SwiftWebUI's default surface treatment: materials render as
    // translucent glass with edge-lensing refraction unless a view opts into a
    // solid style (`.swiftWeb`).
    static let defaultValue = StyleSystem.liquidGlass
}

extension EnvironmentValues {
    public var styleSystem: StyleSystem {
        get { self[StyleSystemEnvironmentKey.self] }
        set { self[StyleSystemEnvironmentKey.self] = newValue }
    }
}
