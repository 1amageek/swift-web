import SwiftWebUITheme
import SwiftHTML

struct PreferredColorSchemeEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue: ColorScheme? = nil
}

extension EnvironmentValues {
    var preferredColorScheme: ColorScheme? {
        get { self[PreferredColorSchemeEnvironmentKey.self] }
        set { self[PreferredColorSchemeEnvironmentKey.self] = newValue }
    }
}

public extension HTML {
    /// Sets the color scheme for this view and its children, establishing a
    /// styled SwiftWebUI root that switches the rendered palette in step. `nil`
    /// clears the explicit preference and lets the stylesheet follow the user
    /// agent's color-scheme preference.
    ///
    /// An explicit scheme drives both Swift-side color resolution (`\.colorScheme`,
    /// read by style modifiers) and rendered appearance (`data-color-scheme` on the
    /// root). Passing `nil` clears the explicit root palette; server-side style
    /// resolution then falls back to `EnvironmentValues.colorScheme`'s default.
    @HTMLBuilder
    func preferredColorScheme(_ colorScheme: ColorScheme?) -> some HTML {
        if let colorScheme {
            StyleRoot {
                self
            }
            .environment(\.preferredColorScheme, colorScheme)
            .environment(\.colorScheme, colorScheme)
        } else {
            StyleRoot {
                self
            }
            .environment(\.preferredColorScheme, nil)
        }
    }
}
