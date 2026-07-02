import SwiftHTML
import SwiftWebUI

extension HTML {
    /// Wraps content in an explicitly scoped style root for isolated `render()`
    /// tests. Pages get the document root automatically at response encoding;
    /// bare renders have no document, so tests opt into a scoped root here.
    func styleRoot(_ colorScheme: ColorScheme? = nil) -> some HTML {
        StyleRoot(colorScheme: colorScheme) {
            self
        }
    }
}
