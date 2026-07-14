import SwiftWebUITheme
import SwiftHTML

public extension HTML {
    /// Presents a destination view for the enclosing URL-backed
    /// `NavigationStack`, mirroring SwiftUI's `navigationDestination(for:destination:)`.
    ///
    /// When the stack's path is non-empty and its top segment losslessly
    /// converts to `valueType`, the destination renders and this content hides
    /// (it stays in the document, preserving its state, like SwiftUI's covered
    /// root). Value types convert through `LosslessStringConvertible` because
    /// path components are URL path segments.
    func navigationDestination<V: LosslessStringConvertible & Sendable, D: HTML>(
        for valueType: V.Type,
        @HTMLBuilder destination: @Sendable @escaping (V) -> D
    ) -> some HTML {
        NavigationDestinationSwitch(content: self, destination: destination)
    }
}

struct NavigationDestinationSwitch<Content: HTML, V: LosslessStringConvertible & Sendable, D: HTML>: Component {
    @Environment({ $0.navigationPathSegments }) private var segments: [String]?

    private let content: Content
    private let destination: @Sendable (V) -> D

    init(content: Content, destination: @Sendable @escaping (V) -> D) {
        self.content = content
        self.destination = destination
    }

    @HTMLBuilder
    var body: some HTML {
        if let top = segments?.last, let value = V(top) {
            Element("div", attributes: [HTMLAttribute("data-navigation-origin", "true")]) {
                content
            }
            Element("div", attributes: [HTMLAttribute("data-navigation-destination", "true")]) {
                destination(value)
            }
        } else {
            content
        }
    }
}
