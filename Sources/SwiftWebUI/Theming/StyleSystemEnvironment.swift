import SwiftHTML

private struct StyleSystemEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = StyleSystem.default
}

extension EnvironmentValues {
    public var styleSystem: StyleSystem {
        get { self[StyleSystemEnvironmentKey.self] }
        set { self[StyleSystemEnvironmentKey.self] = newValue }
    }
}
