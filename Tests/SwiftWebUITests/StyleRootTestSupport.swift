import SwiftHTML
import SwiftWebUI

extension Component {
    /// Wraps content in an explicitly scoped style root for isolated `render()`
    /// tests. Pages get the document root automatically at response encoding;
    /// bare renders have no document, so tests opt into a scoped root here.
    func styleRoot(_ colorScheme: ColorScheme? = nil) -> some Component {
        StyleRoot(colorScheme: colorScheme) {
            self
        }
    }
}
