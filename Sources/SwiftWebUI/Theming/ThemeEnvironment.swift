import SwiftHTML

public struct ThemeEnvironmentKey: ClientEnvironmentKey {
    public static let defaultValue = Theme.system

    public init() {}
}

extension EnvironmentValues {
    public var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}
