import SwiftHTML

private struct DesignStyleEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = DesignStyle.default
}

extension EnvironmentValues {
    public var designStyle: DesignStyle {
        get { self[DesignStyleEnvironmentKey.self] }
        set { self[DesignStyleEnvironmentKey.self] = newValue }
    }
}
