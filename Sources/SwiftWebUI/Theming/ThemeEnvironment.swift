import SwiftHTML

private struct ThemeEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = Theme.system
}

extension EnvironmentValues {
    public var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}
