import SwiftWebUITheme
import SwiftWebStyle
import SwiftHTML

public extension HTML {
    /// Sets the color scheme for the rendered document.
    ///
    /// This matches SwiftUI's presentation semantics: the preference applies to
    /// the whole document no matter where in the tree it is declared, and the
    /// last writer during a render wins. The page response encoder applies the
    /// recorded scheme to the document root, so the palette switches for the
    /// entire page. Passing `nil` explicitly follows the user agent preference.
    ///
    /// To scope Swift-side color resolution to a subtree, use
    /// `.environment(\.colorScheme, ...)` instead; this modifier also applies
    /// that environment to its own subtree so reads below it stay consistent
    /// with the document.
    @HTMLBuilder
    func preferredColorScheme(_ colorScheme: ColorScheme?) -> some HTML {
        let _ = DocumentStyle.current?.recordPreferredColorScheme(colorScheme?.rawValue)
        if let colorScheme {
            environment(\.colorScheme, colorScheme)
        } else {
            self
        }
    }
}
